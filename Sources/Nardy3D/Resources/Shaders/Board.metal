// The board: its two fields with the points inlaid, the rims and the middle bar of polished wood, the felt of the
// tray, and the table under it; and the marks of the game drawn on the points: where a checker may go, which may
// move, the last move and the hint. The meshes are already in place. Compiled after Common.metal and Lighting.metal.

#include <metal_stdlib>
using namespace metal;

struct BoardVertexIn {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 uv [[attribute(2)]];
};

struct BoardVaryings {
    float4 position [[position]];
    float3 world;
    float3 normal;
    float2 uv;
};

vertex BoardVaryings boardVertex(BoardVertexIn in [[stage_in]], constant FrameUniforms& frame [[buffer(1)]])
{
    BoardVaryings out;
    out.world = in.position;
    out.normal = in.normal;
    out.uv = in.uv;
    out.position = frame.viewProjection * float4(in.position, 1.0);
    return out;
}

// Wood with its grain along x: growth lines of uneven spacing and strength, fine fibres and a soft figure. Detail
// finer than the footprint, the size of a pixel in p, fades to its average instead of flickering.
float3 Wood(float2 p, float3 color, float seed, float footprint)
{
    p += float2(seed * 31.7, seed * 17.3);
    float t = p.y * 7.0 + 2.5 * Fbm(float2(p.y * 0.8, seed * 5.0)) + 0.8 * Fbm(float2(p.x * 0.3, p.y * 1.2)) + 0.2 * sin(p.x * 1.1 + seed * 6.0);
    float ring = floor(t);
    float phase = t - ring;
    float width = 0.2 + 0.3 * Hash12(float2(ring, seed));
    float late = smoothstep(0.0, 0.08, phase) * (1.0 - smoothstep(width, width + 0.25, phase));
    late *= 0.35 + 0.9 * Hash12(float2(ring, seed + 7.0));
    late = mix(late, 0.3, smoothstep(0.04, 0.12, footprint));
    float fibers = 0.5 * Noise(float2(p.x * 3.0, p.y * 260.0)) + 0.5 * Noise(float2(p.x * 7.0, p.y * 600.0));
    fibers = mix(fibers, 0.5, smoothstep(0.001, 0.004, footprint));
    float figure = Noise(p * float2(0.8, 2.2) + seed * 9.0);
    return color * (1.0 - 0.2 * late) * (0.9 + 0.16 * fibers) * (0.9 + 0.2 * figure);
}

// Polished stone: a soft mottle and a fine speckle of grains, the speckle fading where it is finer than a pixel.
float3 Granite(float2 p, float3 color, float seed, float footprint)
{
    p += seed * 10.0;
    float mottle = Fbm(p * 1.6);
    float speckle = mix(Noise(p * 300.0), 0.5, smoothstep(0.001, 0.004, footprint));
    float flecks = smoothstep(0.66, 0.72, Noise(p * 140.0 + 3.0)) * (1.0 - smoothstep(0.002, 0.006, footprint));
    float3 c = color * (0.9 + 0.18 * mottle) * (0.93 + 0.14 * speckle);
    return mix(c, color * 1.9, flecks * 0.18);
}

// Felt: fine fibres and a soft mottle, fading to their average where they are finer than a pixel.
float3 Felt(float3 color, float2 p, float footprint)
{
    float fibres = 0.5 * Noise(p * float2(900.0, 300.0)) + 0.5 * Noise(p * float2(300.0, 900.0));
    fibres = mix(fibres, 0.5, smoothstep(0.0005, 0.002, footprint));
    return color * (0.9 + 0.16 * fibres + 0.1 * (Fbm(p * 8.0) - 0.5));
}

// Leather: a pebbled grain and darker creases, the creases fading where they are finer than a pixel.
float3 Leather(float3 color, float2 p, float footprint)
{
    float grain = mix(Noise(p * 420.0), 0.5, smoothstep(0.0008, 0.003, footprint));
    float crease = pow(1.0 - abs(Noise(p * 60.0 + Fbm(p * 9.0) * 1.5) * 2.0 - 1.0), 14.0);
    crease *= (1.0 - smoothstep(0.0015, 0.004, footprint)) * (0.4 + 0.6 * Noise(p * 6.0));
    return color * (0.9 + 0.18 * grain) * (1.0 - 0.07 * crease);
}

float3 Surface(int pattern, float3 color, float2 p, float seed, float footprint)
{
    if (pattern == 1)
        return Felt(color, p, footprint);
    if (pattern == 2)
        return Leather(color, p, footprint);
    return Wood(p.yx * float2(2.5, 12.0), color, seed, footprint);
}

fragment float4 boardFragment(BoardVaryings in [[stage_in]],
                              bool frontFacing [[front_facing]],
                              constant FrameUniforms& frame [[buffer(1)]],
                              constant PassUniforms& pass [[buffer(2)]],
                              constant BoardUniforms& look [[buffer(3)]],
                              constant MeshUniforms& mesh [[buffer(4)]],
                              depth2d<float> shadowMap [[texture(0)]],
                              texturecube<float> irradiance [[texture(1)]],
                              texturecube<float> prefiltered [[texture(2)]],
                              texture2d<float> brdf [[texture(3)]])
{
    int kind = int(mesh.kind.x + 0.5);
    float3 N = normalize(in.normal);
    if (!frontFacing)
        N = -N;
    // Measured here, where all the pixels of a quad still run together.
    float spread = NormalSpread(N);
    float3 V = normalize(pass.eye.xyz - in.world);
    float2 p = in.world.xz;
    float footprint = length(fwidth(p));
    float pixel = max(footprint * 0.7, 1e-5);
    Material m = DefaultMaterial(float3(0.5), 0.5);
    float3 glow = float3(0.0);
    float pulse = 0.75 + 0.25 * sin(frame.cameraPosition.w * 4.0);

    if (kind == 0) {
        int pattern = int(look.fieldStyle.y + 0.5);
        m.albedo = Surface(pattern, look.fieldColor.rgb, p, look.fieldStyle.z, footprint);
        m.roughness = look.fieldStyle.x;
        m.clearcoat = look.fieldStyle.w;
        m.clearcoatRoughness = 0.1;

        // The point this part of the field belongs to, and where in it.
        float pointWidth = look.layout.x;
        float pointLength = look.layout.y;
        float across = (abs(p.x) - look.layout.w) / pointWidth;
        float columnInHalf = clamp(floor(across), 0.0, 5.0);
        float offset = (across - columnInHalf - 0.5) * pointWidth;
        float along = look.layout.z - abs(p.y);
        int column = p.x > 0.0 ? 5 - int(columnInHalf) : 6 + int(columnInHalf);
        int w = p.y > 0.0 ? column : 23 - column;
        // A long narrow triangle from the edge toward the middle; its distance from the slanted sides.
        float halfWidth = max(0.0, 1.0 - along / pointLength) * pointWidth * 0.46;
        float slope = pointWidth * 0.46 / pointLength;
        float edge = (abs(offset) - halfWidth) / sqrt(1.0 + slope * slope);
        edge = max(edge, along - pointLength);
        float inside = 1.0 - smoothstep(-pixel, pixel, edge);
        float3 inlay = Surface(pattern, look.pointColor[w % 2].rgb, p + float2(0.37, 0.71) * float(w), look.fieldStyle.z + 0.5, footprint);
        m.albedo = mix(m.albedo, inlay, inside);
        m.roughness = mix(m.roughness, look.pointStyle.x, inside);
        // The thin line round each point.
        float line = LineCoverage(abs(edge), look.pointStyle.y, pixel) * step(along, pointLength + look.pointStyle.y);
        m.albedo = mix(m.albedo, look.lineColor.rgb, line);
        m.metallic = look.pointStyle.z * line;
        m.roughness = mix(m.roughness, 0.3, line);

        float4 marks = look.points[w];
        float near = 1.0 - smoothstep(0.0, pointLength * 0.3, along);
        glow += frame.accent.rgb * inside * (marks.x * (0.5 * pulse + 0.2) + marks.y * 0.18 * near);
        glow += frame.accent.rgb * LineCoverage(abs(edge), 0.0014, pixel) * marks.x * 1.4;
        glow += look.hintColor.rgb * inside * marks.w * (0.5 * pulse + 0.2);
        m.albedo = mix(m.albedo, mix(m.albedo, float3(0.9, 0.8, 0.55), 0.35), marks.z * inside);
    }
    else if (kind == 1) {
        // Polished wood or lacquer, its grain along the rims.
        float2 grain = in.uv * float2(2.5, 2.5);
        m.albedo = look.woodStyle.z > 0.5 ? look.woodColor.rgb * (0.96 + 0.06 * Noise(p * 40.0))
                                          : Wood(grain.yx * float2(1.0, 4.5), look.woodColor.rgb, look.woodStyle.w, footprint);
        m.roughness = look.woodStyle.x;
        m.clearcoat = look.woodStyle.y;
        m.clearcoatRoughness = 0.07;
        m.occlusion = mix(0.6, 1.0, smoothstep(-0.03, 0.01, in.world.y));
    }
    else if (kind == 2) {
        m.albedo = Felt(look.feltColor.rgb, p, footprint);
        m.roughness = 0.95;
        m.occlusion = 0.7;
        // The tray glows where a checker may be borne off into it.
        float mine = p.y > 0.0 ? look.trays.x : look.trays.y;
        glow += frame.accent.rgb * mine * (0.3 * pulse + 0.1);
        glow += look.hintColor.rgb * (p.y > 0.0 ? max(look.trays.z, 0.0) : max(-look.trays.z, 0.0)) * (0.4 * pulse + 0.15);
    }
    else {
        int pattern = int(look.tableStyle.y + 0.5);
        if (pattern == 1)
            m.albedo = Felt(look.tableColor.rgb, p * 0.6, footprint);
        else if (pattern == 2)
            m.albedo = Granite(p, look.tableColor.rgb, look.tableStyle.z, footprint);
        else
            m.albedo = Wood(p.yx * float2(1.2, 6.0), look.tableColor.rgb, look.tableStyle.z, footprint);
        m.roughness = look.tableStyle.x;
        // The table darkens away from the lamp over the board.
        float r = length(max(abs(p) - float2(0.35, 0.28), float2(0.0)));
        m.albedo *= mix(1.0, 0.18, smoothstep(0.0, 1.6, r));
        m.occlusion = mix(0.55, 1.0, smoothstep(0.0, 0.06, r));
    }

    m.roughness = WidenRoughness(m.roughness, spread);
    m.clearcoatRoughness = WidenRoughness(m.clearcoatRoughness, spread);
    float shadow = pass.eye.w > 0.5 ? 1.0 : Shadow(in.world, N, in.position.xy, frame, shadowMap);
    float3 color = Shade(m, in.world, N, V, shadow, frame, irradiance, prefiltered, brdf) + glow;
    return float4(ApplyFog(color, in.world, frame), 1.0);
}
