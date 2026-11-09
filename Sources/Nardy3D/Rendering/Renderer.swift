import Foundation
import Metal
import QuartzCore
import simd

/// Draws the scene into the window: shadows, the lit scene in high dynamic range with multisampling, then bloom and
/// tone mapping. The interface is drawn on top, in the last pass, by the caller.
@MainActor
final class Renderer {
    private static let shadowSize = 2048
    private static let maxPieces = 32
    private static let maxFrostedPanels = 4
    static let framesInFlight = 3

    let device: MTLDevice
    let queue: MTLCommandQueue
    private let samples: Int

    private let shadowPipeline: MTLRenderPipelineState
    private let piecePipeline: MTLRenderPipelineState
    private let boardPipeline: MTLRenderPipelineState
    private let backgroundPipeline: MTLRenderPipelineState
    private let resolvePipeline: MTLRenderPipelineState
    private let bloomDownPipeline: MTLRenderPipelineState
    private let bloomUpPipeline: MTLRenderPipelineState
    private let compositePipeline: MTLRenderPipelineState
    private let interfacePipeline: MTLRenderPipelineState
    private let depthWrite: MTLDepthStencilState
    private let depthTest: MTLDepthStencilState

    private let field: GPUMesh
    private let wood: GPUMesh
    private let felt: GPUMesh
    private let table: GPUMesh
    private let checker: GPUMesh
    private let die: GPUMesh

    private let shadowMap: MTLTexture
    private let probes: LightProbes
    private var targets: RenderTargets?

    private var theme = Themes.all[0]
    private var lightViewProjection = Matrix.identity
    private let shadowRadius: Float = 0.62
    private let shadowRange: Float = 4
    private let inFlight: DispatchSemaphore
    private var frameIndex = 0

    init(device: MTLDevice, drawableFormat: MTLPixelFormat) throws {
        self.device = device
        inFlight = DispatchSemaphore(value: Self.framesInFlight)
        guard let queue = device.makeCommandQueue() else { throw RendererError.creationFailed("command queue") }
        queue.label = "3D Nardy"
        self.queue = queue
        samples = device.supportsTextureSampleCount(4) ? 4 : 1

        let library = try ShaderLibrary(device: device)
        let hdr = RenderTargets.hdrFormat
        let depth = RenderTargets.depthFormat
        let stride = MemoryLayout<SurfaceVertex>.stride
        let surfaceLayout = Self.vertexLayout([(.float3, 0), (.float3, 12), (.float2, 24)], stride: stride)
        let positionLayout = Self.vertexLayout([(.float3, 0)], stride: stride)
        let interfaceLayout = Self.vertexLayout([(.float2, 0), (.float2, 8), (.uchar4Normalized, 16), (.float4, 20)],
                                                stride: MemoryLayout<InterfaceVertex>.stride)

        func pipeline(_ label: String, _ vertex: String, _ fragment: String, layout: MTLVertexDescriptor? = nil, color: MTLPixelFormat?,
                      depth: MTLPixelFormat = .invalid, samples: Int = 1, blend: Blend = .none) throws -> MTLRenderPipelineState {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = label
            descriptor.vertexFunction = try library.function(vertex)
            descriptor.fragmentFunction = try library.function(fragment)
            descriptor.vertexDescriptor = layout
            descriptor.rasterSampleCount = samples
            descriptor.depthAttachmentPixelFormat = depth
            if let color {
                let attachment: MTLRenderPipelineColorAttachmentDescriptor = descriptor.colorAttachments[0]
                attachment.pixelFormat = color
                blend.apply(to: attachment)
            }
            return try device.makeRenderPipelineState(descriptor: descriptor)
        }

        shadowPipeline = try pipeline("shadow", "shadowVertex", "shadowFragment", layout: positionLayout, color: nil, depth: depth)
        piecePipeline = try pipeline("pieces", "pieceVertex", "pieceFragment", layout: surfaceLayout, color: hdr, depth: depth, samples: samples)
        boardPipeline = try pipeline("board", "boardVertex", "boardFragment", layout: surfaceLayout, color: hdr, depth: depth, samples: samples)
        backgroundPipeline = try pipeline("background", "fullscreenVertex", "backgroundFragment", color: hdr, depth: depth, samples: samples)
        resolvePipeline = try pipeline("resolve", "fullscreenVertex", "resolveFragment", color: hdr)
        bloomDownPipeline = try pipeline("bloom down", "fullscreenVertex", "bloomDownFragment", color: RenderTargets.bloomFormat)
        bloomUpPipeline = try pipeline("bloom up", "fullscreenVertex", "bloomUpFragment", color: RenderTargets.bloomFormat, blend: .additive)
        compositePipeline = try pipeline("composite", "fullscreenVertex", "compositeFragment", color: drawableFormat)
        interfacePipeline = try pipeline("interface", "interfaceVertex", "interfaceFragment", layout: interfaceLayout, color: drawableFormat,
                                         blend: .alpha)
        depthWrite = try Self.depthState(device, .less, write: true)
        depthTest = try Self.depthState(device, .lessEqual, write: false)

        let meshes = BoardModel.board()
        field = try GPUMesh(device: device, mesh: meshes.field, label: "fields")
        wood = try GPUMesh(device: device, mesh: meshes.wood, label: "wood")
        felt = try GPUMesh(device: device, mesh: meshes.felt, label: "felt")
        table = try GPUMesh(device: device, mesh: meshes.table, label: "table")
        checker = try GPUMesh(device: device, mesh: BoardModel.checker(), label: "checker")
        die = try GPUMesh(device: device, mesh: BoardModel.die(), label: "die")

        // The shadow map, read both with comparison (for filtering) and without (to find the casters).
        let shadowDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: depth, width: Self.shadowSize, height: Self.shadowSize,
                                                                        mipmapped: false)
        shadowDescriptor.usage = [.renderTarget, .shaderRead]
        shadowDescriptor.storageMode = .private
        guard let shadowMap = device.makeTexture(descriptor: shadowDescriptor) else { throw RendererError.creationFailed("shadow map") }
        shadowMap.label = "shadow map"
        self.shadowMap = shadowMap

        probes = try LightProbes(device: device, library: library, queue: queue)
    }

    func setTheme(_ theme: Theme) throws {
        self.theme = theme
        updateLightView()
        try probes.bake(theme, queue: queue)
    }

    /// Draws a frame into the drawable and presents it. `overlay` draws the interface over the finished image, in the
    /// last pass; it is given the index of the frame among those the GPU may still be drawing.
    func render(_ scene: RenderScene, to drawable: CAMetalDrawable, overlay: (MTLRenderCommandEncoder, Int) -> Void) {
        let width = drawable.texture.width
        let height = drawable.texture.height
        if targets?.width != width || targets?.height != height {
            targets = try? RenderTargets(device: device, width: width, height: height, samples: samples)
        }
        guard let targets else { return }

        inFlight.wait()
        frameIndex = (frameIndex + 1) % Self.framesInFlight
        guard let commandBuffer = queue.makeCommandBuffer() else {
            inFlight.signal()
            return
        }
        commandBuffer.label = "frame"
        Self.signal(inFlight, when: commandBuffer)

        let uniforms = frameUniforms(scene, width: width, height: height)
        let pieces = pieceInstances(scene)
        drawShadowMap(uniforms: uniforms, pieces: pieces, commandBuffer: commandBuffer)
        drawMainPass(scene, uniforms: uniforms, pieces: pieces, targets: targets, commandBuffer: commandBuffer)
        drawBloom(targets: targets, commandBuffer: commandBuffer)
        drawFinalImage(scene, targets: targets, drawable: drawable, commandBuffer: commandBuffer, overlay: overlay)

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Passes

    private func frameUniforms(_ scene: RenderScene, width: Int, height: Int) -> Uniforms.Frame {
        let viewProjection = scene.projection * scene.view
        // The depth bias, in world units the same whatever the shadow's range; the fog begins well beyond the board.
        let fogStart = length(scene.eye) + 1.2
        return Uniforms.Frame(
            viewProjection: viewProjection,
            inverseViewProjection: viewProjection.inverse,
            lightViewProjection: lightViewProjection,
            cameraPosition: SIMD4(scene.eye, scene.time),
            lightDirection: SIMD4(normalize(theme.keyDirection), 2 * shadowRadius / Float(Self.shadowSize)),
            lightColor: SIMD4(theme.keyRadiance, theme.keySoftness),
            shadowParams: SIMD4(shadowRange, 0.0015 / shadowRange, fogStart, 0),
            viewport: SIMD4(Float(width), Float(height), 1 / Float(width), 1 / Float(height)),
            environment: SIMD4(theme.diffuseLight, theme.reflectedLight, Float(LightProbes.prefilteredLevels - 1), theme.background),
            accent: SIMD4(theme.accent, 1),
            fog: SIMD4(theme.fog, 0.15))
    }

    /// The pieces as instances: the checkers first, then the dice.
    private func pieceInstances(_ scene: RenderScene) -> (instances: [Uniforms.PieceInstance], checkers: Int) {
        var instances: [Uniforms.PieceInstance] = []
        for kind in [PieceDraw.Kind.checker, .die] {
            for piece in scene.pieces where piece.kind == kind && instances.count < Self.maxPieces {
                let params = SIMD4(kind == .checker ? 0 : 1, Float(piece.side), Float(piece.value), piece.highlight)
                instances.append(Uniforms.PieceInstance(model: piece.model, params: params, extra: SIMD4(piece.dim, 0, 0, 0)))
            }
        }
        let checkers = instances.filter { $0.params.x < 0.5 }.count
        return (instances, checkers)
    }

    private func drawShadowMap(uniforms: Uniforms.Frame, pieces: (instances: [Uniforms.PieceInstance], checkers: Int),
                               commandBuffer: MTLCommandBuffer) {
        let pass = MTLRenderPassDescriptor()
        pass.depthAttachment.texture = shadowMap
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.clearDepth = 1
        pass.depthAttachment.storeAction = .store
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        encoder.label = "shadow map"
        encoder.setRenderPipelineState(shadowPipeline)
        encoder.setDepthStencilState(depthWrite)
        encoder.setCullMode(.none)
        encoder.setDepthBias(3, slopeScale: 1.5, clamp: 0)
        encoder.setVertexValue(uniforms, index: 1)
        setPieceInstances(pieces.instances, encoder)

        // The rims, the bar and the tray; the flat parts under them only receive shadows.
        encoder.setVertexValue(Uniforms.Shadow(model: Matrix.identity, draw: .zero), index: 3)
        wood.draw(encoder)
        encoder.setVertexValue(Uniforms.Shadow(model: Matrix.identity, draw: SIMD4(1, 0, 0, 0)), index: 3)
        checker.draw(encoder, instances: pieces.checkers)
        encoder.setVertexValue(Uniforms.Shadow(model: Matrix.identity, draw: SIMD4(1, Float(pieces.checkers), 0, 0)), index: 3)
        die.draw(encoder, instances: pieces.instances.count - pieces.checkers)
        encoder.endEncoding()
    }

    /// The table, the board, the checkers and the dice, lit by the key light and the baked room; the background is the
    /// room itself.
    private func drawMainPass(_ scene: RenderScene, uniforms: Uniforms.Frame, pieces: (instances: [Uniforms.PieceInstance], checkers: Int),
                              targets: RenderTargets, commandBuffer: MTLCommandBuffer) {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = targets.sceneColor
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: Double(theme.fog.x), green: Double(theme.fog.y), blue: Double(theme.fog.z), alpha: 1)
        pass.colorAttachments[0].storeAction = .store
        pass.depthAttachment.texture = targets.sceneDepth
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.clearDepth = 1
        pass.depthAttachment.storeAction = .dontCare
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        encoder.label = "scene"
        encoder.setDepthStencilState(depthWrite)
        encoder.setFrontFacing(.counterClockwise)
        encoder.setCullMode(.back)
        encoder.setVertexValue(uniforms, index: 1)
        encoder.setFragmentValue(uniforms, index: 1)
        encoder.setFragmentValue(Uniforms.Pass(eye: SIMD4(scene.eye, 0)), index: 2)
        encoder.setFragmentTexture(shadowMap, index: 0)
        encoder.setFragmentTexture(probes.irradiance, index: 1)
        encoder.setFragmentTexture(probes.prefiltered, index: 2)
        encoder.setFragmentTexture(probes.brdf, index: 3)

        encoder.setRenderPipelineState(boardPipeline)
        BoardLook(theme: theme, scene: scene).packed.withUnsafeBytes { encoder.setFragmentBytes($0.baseAddress!, length: $0.count, index: 3) }
        for (mesh, kind) in [(table, 3), (wood, 1), (felt, 2), (field, 0)] {
            encoder.setFragmentValue(Uniforms.Mesh(kind: SIMD4(Float(kind), 0, 0, 0)), index: 4)
            mesh.draw(encoder)
        }

        encoder.setRenderPipelineState(piecePipeline)
        setPieceInstances(pieces.instances, encoder)
        let dice = pieces.instances.count - pieces.checkers
        for (mesh, first, count) in [(checker, 0, pieces.checkers), (die, pieces.checkers, dice)] where count > 0 {
            let look = pieceLook(first: first)
            encoder.setVertexValue(look, index: 3)
            encoder.setFragmentValue(look, index: 3)
            mesh.draw(encoder, instances: count)
        }

        // Behind everything drawn, at the far plane; clamped there rather than clipped.
        encoder.setDepthStencilState(depthTest)
        encoder.setDepthClipMode(.clamp)
        encoder.setRenderPipelineState(backgroundPipeline)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.setDepthClipMode(.clip)
        encoder.endEncoding()
    }

    /// The samples resolved, and the bright parts spread: halved six times, then added back up.
    private func drawBloom(targets: RenderTargets, commandBuffer: MTLCommandBuffer) {
        fullscreenPass(commandBuffer, into: targets.resolved, label: "resolve") { encoder in
            encoder.setRenderPipelineState(resolvePipeline)
            encoder.setFragmentTexture(targets.sceneColor, index: 0)
        }?.endEncoding()
        for level in 0..<RenderTargets.bloomLevels {
            let source = level == 0 ? targets.resolved : targets.bloom[level - 1]
            fullscreenPass(commandBuffer, into: targets.bloom[level], label: "bloom down") { encoder in
                encoder.setRenderPipelineState(bloomDownPipeline)
                encoder.setFragmentTexture(source, index: 0)
                encoder.setFragmentValue(Uniforms.Bloom(source: Self.texelSize(source, first: level == 0)), index: 0)
            }?.endEncoding()
        }
        for level in stride(from: RenderTargets.bloomLevels - 2, through: 0, by: -1) {
            let source = targets.bloom[level + 1]
            fullscreenPass(commandBuffer, into: targets.bloom[level], load: true, label: "bloom up") { encoder in
                encoder.setRenderPipelineState(bloomUpPipeline)
                encoder.setFragmentTexture(source, index: 0)
                encoder.setFragmentValue(Uniforms.Bloom(source: Self.texelSize(source, first: false)), index: 0)
            }?.endEncoding()
        }
    }

    /// Tone mapping, vignetting and the frosted glass behind the interface's panels, then the interface itself.
    private func drawFinalImage(_ scene: RenderScene, targets: RenderTargets, drawable: CAMetalDrawable, commandBuffer: MTLCommandBuffer,
                                overlay: (MTLRenderCommandEncoder, Int) -> Void) {
        let panels = scene.panels.prefix(Self.maxFrostedPanels).map { panel in
            Uniforms.FrostedPanel(bounds: SIMD4(panel.rect.x + panel.rect.width / 2, panel.rect.y + panel.rect.height / 2,
                                                panel.rect.width / 2, panel.rect.height / 2),
                                  style: SIMD4(panel.radius, panel.opacity, 0, 0))
        }
        let width = Float(targets.width)
        let height = Float(targets.height)
        let composite = Uniforms.Composite(settings: SIMD4(theme.exposure, theme.bloom, theme.vignette, Float(panels.count)),
                                           viewport: SIMD4(width, height, 1 / width, 1 / height))
        let encoder = fullscreenPass(commandBuffer, into: drawable.texture, label: "final image") { encoder in
            encoder.setRenderPipelineState(compositePipeline)
            encoder.setFragmentValue(composite, index: 0)
            encoder.setFragmentArray(panels, placeholder: Uniforms.FrostedPanel(bounds: .zero, style: .zero), index: 1)
            encoder.setFragmentTexture(targets.resolved, index: 0)
            encoder.setFragmentTexture(targets.bloom[0], index: 1)
            encoder.setFragmentTexture(targets.bloom[2], index: 2)
        }
        guard let encoder else { return }
        encoder.setRenderPipelineState(interfacePipeline)
        overlay(encoder, frameIndex)
        encoder.endEncoding()
    }

    // MARK: - The looks

    /// The key light's view: a box round the board.
    private func updateLightView() {
        let toLight = normalize(theme.keyDirection)
        let up: SIMD3<Float> = abs(toLight.y) > 0.99 ? SIMD3(0, 0, 1) : SIMD3(0, 1, 0)
        let center = SIMD3<Float>(0.03, 0, 0)
        let view = Matrix.lookAt(eye: center + toLight * 2, target: center, up: up)
        let projection = Matrix.orthographic(left: -shadowRadius, right: shadowRadius, bottom: -shadowRadius, top: shadowRadius, near: 0.5,
                                             far: 0.5 + shadowRange)
        lightViewProjection = projection * view
    }

    /// The looks of the checkers and the dice, for a draw from the instance `first`.
    private func pieceLook(first: Int) -> Uniforms.Pieces {
        let white = theme.checkers[0]
        let black = theme.checkers[1]
        return Uniforms.Pieces(checkerColor: (SIMD4(white.color, white.roughness), SIMD4(black.color, black.roughness)),
                               checkerStyle: (SIMD4(white.clearcoat, white.pattern, 0.3, white.ornament),
                                              SIMD4(black.clearcoat, black.pattern, 0.7, black.ornament)),
                               dieColor: SIMD4(theme.die, theme.dieRoughness),
                               pipColor: SIMD4(theme.pip, 0),
                               shape: SIMD4(Board.checkerHeight / Board.checkerRadius, 0, 0, 0),
                               draw: SIMD4(Float(first), 0, 0, 0))
    }

    // MARK: - Helpers

    /// The pieces for the vertex functions that read them; an empty list is bound as one, which no draw reads.
    private func setPieceInstances(_ instances: [Uniforms.PieceInstance], _ encoder: MTLRenderCommandEncoder) {
        let bound = instances.isEmpty ? [Uniforms.PieceInstance(model: Matrix.identity, params: .zero, extra: .zero)] : instances
        bound.withUnsafeBytes { encoder.setVertexBytes($0.baseAddress!, length: $0.count, index: 5) }
    }

    /// A pass that covers its target with one triangle, after `setUp` has set the pipeline and its inputs. The
    /// encoder is returned open, for more to be drawn over the triangle; the caller ends it.
    private func fullscreenPass(_ commandBuffer: MTLCommandBuffer, into target: MTLTexture, load: Bool = false, label: String,
                                _ setUp: (MTLRenderCommandEncoder) -> Void) -> MTLRenderCommandEncoder? {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = load ? .load : .dontCare
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return nil }
        encoder.label = label
        setUp(encoder)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        return encoder
    }

    private static func texelSize(_ texture: MTLTexture, first: Bool) -> SIMD4<Float> {
        SIMD4(1 / Float(texture.width), 1 / Float(texture.height), first ? 1 : 0, 0)
    }

    private static func vertexLayout(_ attributes: [(MTLVertexFormat, Int)], stride: Int) -> MTLVertexDescriptor {
        let descriptor = MTLVertexDescriptor()
        for (index, (format, offset)) in attributes.enumerated() {
            descriptor.attributes[index].format = format
            descriptor.attributes[index].offset = offset
            descriptor.attributes[index].bufferIndex = 0
        }
        descriptor.layouts[0].stride = stride
        return descriptor
    }

    private static func depthState(_ device: MTLDevice, _ compare: MTLCompareFunction, write: Bool) throws -> MTLDepthStencilState {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = compare
        descriptor.isDepthWriteEnabled = write
        guard let state = device.makeDepthStencilState(descriptor: descriptor) else { throw RendererError.creationFailed("depth state") }
        return state
    }

    /// Frees a frame's slot when the GPU has drawn it. Outside the main actor, so that the handler, which runs on a
    /// thread of Metal's, does not belong to it.
    private nonisolated static func signal(_ semaphore: DispatchSemaphore, when commandBuffer: MTLCommandBuffer) {
        commandBuffer.addCompletedHandler { _ in semaphore.signal() }
    }
}
