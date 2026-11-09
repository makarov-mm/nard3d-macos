// The checkers, turned of wood, stone or bone with a raised rim, a carved groove and a rosette in the middle; and the
// dice, ivory or plastic with rounded edges and sunken pips. The pieces of a kind are drawn together: each instance
// its place, its turn and what it is. Compiled after Common.metal and Lighting.metal.

#include <metal_stdlib>
using namespace metal;

struct PieceVertexIn {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 uv [[attribute(2)]];
};

struct PieceVaryings {
    float4 position [[position]];
    float3 world;
    float3 normal;
    float3 local;
    float4 params [[flat]];
    float4 extra [[flat]];
};

vertex PieceVaryings pieceVertex(PieceVertexIn in [[stage_in]],
                                 uint instance [[instance_id]],
                                 constant FrameUniforms& frame [[buffer(1)]],
                                 constant PieceUniforms& look [[buffer(3)]],
                                 constant PieceInstance* pieces [[buffer(5)]])
{
    PieceInstance piece = pieces[uint(look.draw.x + 0.5) + instance];
    float4 world = piece.model * float4(in.position, 1.0);
    PieceVaryings out;
    out.world = world.xyz;
    out.normal = (piece.model * float4(in.normal, 0.0)).xyz;
    out.local = in.position;
    out.params = piece.params;
    out.extra = piece.extra;
    out.position = frame.viewProjection * world;
    return out;
}

// Rings round the middle of a turned piece, and fibres along them. `around` is the direction from the middle, so that
// the pattern closes round the circle without a seam.
float3 TurnedWood(float3 color, float r, float2 around, float seed, float footprint)
{
    float t = r * 9.0 + 0.6 * Noise(float3(around * 3.0, seed * 7.0)) + 0.4 * Fbm(float3(around * 0.8, r * 4.0 + seed));
    float ring = abs(fract(t) - 0.5) * 2.0;
    float late = mix(smoothstep(0.55, 0.95, ring), 0.25, smoothstep(0.02, 0.08, footprint));
    float fibres = mix(Noise(float3(around * 40.0, r * 300.0)), 0.5, smoothstep(0.002, 0.008, footprint));
    return color * (0.86 + 0.22 * late) * (0.92 + 0.14 * fibres);
}

float3 Stone(float3 color, float3 p, float seed)
{
    float warp = Fbm(p.xz * 2.2 + seed * 13.0) * 3.0;
    float vein = pow(1.0 - abs(sin((p.x * 2.0 + p.z * 1.3 + p.y * 3.0 + warp) * 3.0)), 18.0);
    float3 c = color * (0.88 + 0.24 * Fbm(p.xz * 3.5 + seed * 3.0));
    float light = dot(color, float3(0.333));
    return mix(c, light > 0.3 ? color * 0.55 : color + float3(0.18), vein * 0.6);
}

float3 Bone(float3 color, float3 p, float seed)
{
    float grain = Noise(float2(p.x * 3.0 + seed, p.z * 40.0)) * 0.5 + 0.5 * Fbm(p.xz * 6.0 + seed);
    return color * (0.94 + 0.1 * grain);
}

// The face of a die a point of it lies on, and where on the face, from -1 to 1. The numbers are as on a die: 1 on
// +y, 2 on +z, 3 on +x, and the opposite faces adding up to seven.
struct DieFace {
    int value;
    float2 uv;
};

DieFace DieFaceAt(float3 p)
{
    float3 a = abs(p);
    DieFace face;
    if (a.y >= a.x && a.y >= a.z) {
        face.value = p.y > 0.0 ? 1 : 6;
        face.uv = p.xz;
    }
    else if (a.x >= a.z) {
        face.value = p.x > 0.0 ? 3 : 4;
        face.uv = p.zy;
    }
    else {
        face.value = p.z > 0.0 ? 2 : 5;
        face.uv = p.xy;
    }
    return face;
}

// The pips of a face, as ink from 0 to 1.
float Pips(int value, float2 uv, float pixel)
{
    const float r = 0.19;
    float2 spots[6];
    int count = 0;
    if (value == 1) {
        spots[0] = float2(0.0);
        count = 1;
    }
    else if (value == 2) {
        spots[0] = float2(-0.48, -0.48);
        spots[1] = float2(0.48, 0.48);
        count = 2;
    }
    else if (value == 3) {
        spots[0] = float2(-0.5, -0.5);
        spots[1] = float2(0.0);
        spots[2] = float2(0.5, 0.5);
        count = 3;
    }
    else if (value == 4) {
        spots[0] = float2(-0.48, -0.48);
        spots[1] = float2(0.48, -0.48);
        spots[2] = float2(-0.48, 0.48);
        spots[3] = float2(0.48, 0.48);
        count = 4;
    }
    else if (value == 5) {
        spots[0] = float2(-0.5, -0.5);
        spots[1] = float2(0.5, -0.5);
        spots[2] = float2(-0.5, 0.5);
        spots[3] = float2(0.5, 0.5);
        spots[4] = float2(0.0);
        count = 5;
    }
    else {
        spots[0] = float2(-0.48, -0.55);
        spots[1] = float2(-0.48, 0.0);
        spots[2] = float2(-0.48, 0.55);
        spots[3] = float2(0.48, -0.55);
        spots[4] = float2(0.48, 0.0);
        spots[5] = float2(0.48, 0.55);
        count = 6;
    }
    float ink = 0.0;
    for (int i = 0; i < count; ++i)
        ink = max(ink, 1.0 - smoothstep(r - pixel, r + pixel, length(uv - spots[i])));
    return ink;
}

fragment float4 pieceFragment(PieceVaryings in [[stage_in]],
                              bool frontFacing [[front_facing]],
                              constant FrameUniforms& frame [[buffer(1)]],
                              constant PassUniforms& pass [[buffer(2)]],
                              constant PieceUniforms& look [[buffer(3)]],
                              depth2d<float> shadowMap [[texture(0)]],
                              texturecube<float> irradiance [[texture(1)]],
                              texturecube<float> prefiltered [[texture(2)]],
                              texture2d<float> brdf [[texture(3)]])
{
    float3 N = normalize(in.normal);
    if (!frontFacing)
        N = -N;
    float3 V = normalize(pass.eye.xyz - in.world);
    float3 p = in.local;
    // Measured here, where all the pixels of a quad still run together: how much the normal turns within the pixel,
    // and the size of the pixel on a checker's face and on a die's.
    float spread = NormalSpread(N);
    float checkerFootprint = length(fwidth(p.xz));
    DieFace face = DieFaceAt(p);
    float diePixel = max(length(fwidth(face.uv)), 1e-4) * 0.8;
    int kind = int(in.params.x + 0.5);
    int side = int(in.params.y + 0.5);
    Material m = DefaultMaterial(float3(0.5), 0.4);

    if (kind == 0) {
        float4 color = look.checkerColor[side];
        float4 style = look.checkerStyle[side];
        float r = length(p.xz);
        float2 around = p.xz / max(r, 1e-6);
        float angle = atan2(p.z, p.x);
        int pattern = int(style.y + 0.5);
        float3 albedo = color.rgb;
        if (pattern == 1)
            albedo = TurnedWood(color.rgb, r, around, style.z, checkerFootprint);
        else if (pattern == 2)
            albedo = Stone(color.rgb, p * 1.6, style.z);
        else if (pattern == 3)
            albedo = Bone(color.rgb, p, style.z);
        else
            albedo *= 0.96 + 0.08 * Noise(p.xz * 30.0 + style.z);

        // The top face: the carved groove and a rosette of eight petals in the middle, darker in their hollows.
        float top = smoothstep(look.shape.x - 0.14, look.shape.x - 0.07, p.y) * step(0.0, N.y);
        float pixel = max(checkerFootprint, 1e-4);
        float groove = 1.0 - smoothstep(0.03, 0.05 + pixel, abs(r - 0.46));
        float petals = 0.5 + 0.5 * cos(angle * 8.0);
        float rosette = (1.0 - smoothstep(0.24 - pixel, 0.26 + pixel, r * (1.0 + 0.45 * (1.0 - petals)))) * smoothstep(0.03, 0.05, r);
        float hub = 1.0 - smoothstep(0.05 - pixel, 0.05 + pixel, r);
        float carving = top * max(groove * 0.8, (rosette * 0.75 + hub) * style.w);
        albedo *= 1.0 - 0.45 * carving;
        m.albedo = albedo;
        m.roughness = mix(color.a, min(1.0, color.a + 0.25), carving);
        m.clearcoat = style.x * (1.0 - carving * 0.6);
        m.clearcoatRoughness = 0.08;
        m.occlusion = mix(1.0, 0.55, carving) * mix(0.75, 1.0, smoothstep(0.0, 0.08, p.y));
    }
    else {
        // A pip is a hollow: dark ink and a little shade round it.
        float ink = Pips(face.value, face.uv, diePixel);
        float3 albedo = look.dieColor.rgb * (0.95 + 0.06 * Noise(p.xy * 20.0 + p.z * 7.0));
        albedo = mix(albedo, look.pipColor.rgb, ink);
        // A die already played is darkened.
        float dim = in.extra.x;
        albedo = mix(albedo, float3(dot(albedo, float3(0.3, 0.5, 0.2))) * 0.45, dim * 0.7);
        m.albedo = albedo;
        m.roughness = mix(look.dieColor.a, 0.6, ink);
        m.clearcoat = 0.6 * (1.0 - ink);
        m.clearcoatRoughness = 0.06;
        m.subsurface = 0.25 * (1.0 - ink);
        m.occlusion = mix(1.0, 0.6, ink);
    }

    m.roughness = WidenRoughness(m.roughness, spread);
    m.clearcoatRoughness = WidenRoughness(m.clearcoatRoughness, spread);
    float shadow = pass.eye.w > 0.5 ? 1.0 : Shadow(in.world, N, in.position.xy, frame, shadowMap);
    float3 color = Shade(m, in.world, N, V, shadow, frame, irradiance, prefiltered, brdf);
    // A glow at the rim of what may be moved or is chosen.
    float highlight = in.params.w;
    if (highlight > 0.0) {
        float rim = pow(1.0 - saturate(dot(N, V)), 2.0);
        color += frame.accent.rgb * highlight * (0.12 + 1.2 * rim);
    }
    return float4(ApplyFog(color, in.world, frame), 1.0);
}
