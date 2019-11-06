//
//  Renderer.swift
//  metalfromscratch
//
//  Created by Oskar on 2019-10-25.
//  Copyright © 2019 Shortcut Labs AB. All rights reserved.
//

import Metal
import MetalKit

struct Uniforms
{
	var projectionMatrix: matrix_float4x4
    var modelViewMatrix: matrix_float4x4
	var mode: UInt8
};

class Renderer: NSObject, MTKViewDelegate {
	
	let postProcessingEnabled = true
	let mtkView: MTKView
	let device: MTLDevice
	let commandQueue:MTLCommandQueue
	var mainPipelineState: MTLRenderPipelineState!
	var postPipelineState: MTLRenderPipelineState!
	var samplerState: MTLSamplerState!
	var renderTargetA: MTLTexture!
	var renderTargetB: MTLTexture!
	var mainRenderPassDescriptor: MTLRenderPassDescriptor!
	var postRenderPassDescriptor: MTLRenderPassDescriptor!
	var depthStencilState: MTLDepthStencilState!
	var projectionMatrix: matrix_float4x4 = matrix_float4x4()
	var t: Float = 0.0
	
	init(mtkView: MTKView) {
		self.mtkView = mtkView
		self.device = mtkView.device!
		self.commandQueue = self.device.makeCommandQueue()!
		self.mtkView.framebufferOnly = false
		self.mtkView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        self.mtkView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        self.mtkView.sampleCount = 1
		
		let defaultLibrary = device.makeDefaultLibrary()!
		let mainVertexProgram = defaultLibrary.makeFunction(name: "main_vertex")
		let mainFragmentProgram = defaultLibrary.makeFunction(name: "main_fragment")
		let postVertexProgram = defaultLibrary.makeFunction(name: "post_vertex")
		let postFragmentProgram = defaultLibrary.makeFunction(name: "post_fragment")
		
		let mainPipelineDescriptor = MTLRenderPipelineDescriptor()
			mainPipelineDescriptor.vertexFunction 					= mainVertexProgram
			mainPipelineDescriptor.fragmentFunction 				= mainFragmentProgram
			mainPipelineDescriptor.sampleCount 						= self.mtkView.sampleCount
			mainPipelineDescriptor.colorAttachments[0].pixelFormat 	= self.mtkView.colorPixelFormat
			mainPipelineDescriptor.depthAttachmentPixelFormat 		= self.mtkView.depthStencilPixelFormat
			mainPipelineDescriptor.stencilAttachmentPixelFormat 	= self.mtkView.depthStencilPixelFormat
			
		let postPipelineDescriptor = MTLRenderPipelineDescriptor()
			postPipelineDescriptor.vertexFunction 					= postVertexProgram
			postPipelineDescriptor.fragmentFunction 				= postFragmentProgram
			postPipelineDescriptor.sampleCount 						= self.mtkView.sampleCount
			postPipelineDescriptor.colorAttachments[0].pixelFormat 	= self.mtkView.colorPixelFormat
		
		let sampler = MTLSamplerDescriptor()
			sampler.minFilter             = MTLSamplerMinMagFilter.linear
			sampler.magFilter             = MTLSamplerMinMagFilter.linear
			sampler.mipFilter             = MTLSamplerMipFilter.linear
			sampler.maxAnisotropy         = 1
			sampler.sAddressMode          = MTLSamplerAddressMode.clampToEdge
			sampler.tAddressMode          = MTLSamplerAddressMode.clampToEdge
			sampler.rAddressMode          = MTLSamplerAddressMode.clampToEdge
			sampler.normalizedCoordinates = true
			sampler.lodMinClamp           = 0
			sampler.lodMaxClamp           = .greatestFiniteMagnitude
		
		samplerState =  device.makeSamplerState(descriptor: sampler)!
		
		let drawable = mtkView.currentDrawable!
		
		mainRenderPassDescriptor = mtkView.currentRenderPassDescriptor
		mainRenderPassDescriptor.colorAttachments[0].clearColor 	= MTLClearColorMake(0, 0, 0, 1)
		mainRenderPassDescriptor.colorAttachments[0].loadAction 	= .clear
		mainRenderPassDescriptor.colorAttachments[0].storeAction 	= .store
		
		postRenderPassDescriptor = MTLRenderPassDescriptor()
		postRenderPassDescriptor.colorAttachments[0].clearColor 	= MTLClearColorMake(0, 1, 0, 1)
		postRenderPassDescriptor.colorAttachments[0].texture 		= drawable.texture
		postRenderPassDescriptor.colorAttachments[0].loadAction 	= .clear
		postRenderPassDescriptor.colorAttachments[0].storeAction 	= .store
			
		mainPipelineState = try! device.makeRenderPipelineState(descriptor: mainPipelineDescriptor)
		postPipelineState = try! device.makeRenderPipelineState(descriptor: postPipelineDescriptor)
		
		let depthStateDescriptor = MTLDepthStencilDescriptor()
			depthStateDescriptor.depthCompareFunction = .less
			depthStateDescriptor.isDepthWriteEnabled = true
		
		depthStencilState = device.makeDepthStencilState(descriptor: depthStateDescriptor)
		
		super.init()
	}
	
	func makeBuffer<T>(_ data: [T]) -> MTLBuffer! {
		return device.makeBuffer(bytes: data, length: data.count * MemoryLayout.size(ofValue: data[0]), options: [])!
	}
	
	func makeBuffer<T>(_ data: inout T) -> MTLBuffer! {
		return device.makeBuffer(bytes: UnsafeMutableRawPointer(&data), length: MemoryLayout<T>.stride, options: [])!
	}
	
	func draw(in view : MTKView) {
		
		t += 0.1
		
		let commandBuffer = self.commandQueue.makeCommandBuffer()!
		let drawable = view.currentDrawable!
		
		/// main render pass
		
		do {
			mainRenderPassDescriptor.colorAttachments[0].texture = postProcessingEnabled ? renderTargetA : drawable.texture
			
			let mainRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: mainRenderPassDescriptor)!
			
			let vertices: [Float] = [
				-0.5, -0.5, 0,
				-0.5,  0.5, 0,
				0.5,  0.5, 0,
				0.5, -0.5, 0
			]
			
			let texCoords: [Float] = [
				0.0, 1.0,
				0.0, 0.0,
				1.0, 0.0,
				1.0, 1.0
			]
			
			let colors: [Float] = [
				1.0, 0.0, 0.0, 1.0,
				0.0, 1.0, 0.0, 1.0,
				0.0, 0.0, 1.0, 1.0,
				1.0, 1.0, 0.0, 1.0
			]
			
			let indices: [Int16] = [
				0, 1, 2,
				0, 2, 3
			]

			let exampleTexture = try! loadTexture(device: device, textureName: "exampleTexture")
			
			var modelViewMatrix =
				matrix4x4_translation(-0.5, 0.0, -8)
				* matrix4x4_scale(scale: 5.0)
				* matrix4x4_rotation(radians: cos(t/2), axis: SIMD3<Float>(1, 1 ,1))
				
			let projectionMatrix = self.projectionMatrix
			
			var uniforms: Uniforms = Uniforms(projectionMatrix: projectionMatrix, modelViewMatrix: modelViewMatrix, mode: 0)
			
			mainRenderEncoder.label = "Main Render Encoder"
			mainRenderEncoder.pushDebugGroup("Draw Box")
			mainRenderEncoder.setCullMode(.back)
			mainRenderEncoder.setFrontFacing(.counterClockwise)
			mainRenderEncoder.setDepthStencilState(depthStencilState)
			mainRenderEncoder.setRenderPipelineState(self.mainPipelineState)
			mainRenderEncoder.setVertexBuffer(makeBuffer(vertices), offset: 0, index: 0)
			mainRenderEncoder.setVertexBuffer(makeBuffer(texCoords), offset: 0, index: 1)
			mainRenderEncoder.setVertexBuffer(makeBuffer(colors), offset: 0, index: 2)
			mainRenderEncoder.setVertexBuffer(makeBuffer(&uniforms), offset: 0, index: 3)
			mainRenderEncoder.setFragmentTexture(exampleTexture, index: 0)
			mainRenderEncoder.setFragmentSamplerState(samplerState, index: 0)
			
			mainRenderEncoder.drawIndexedPrimitives(type: .triangleStrip, indexCount: 6, indexType: .uint16, indexBuffer: makeBuffer(indices), indexBufferOffset: 0)
			
			modelViewMatrix =
				matrix4x4_translation(3, 0.0, -12) *
				matrix4x4_scale(scale: 5.0) *
				matrix4x4_rotation(radians: cos((t+3.14)/2), axis: SIMD3<Float>(1, 1 ,1))
			
			uniforms.modelViewMatrix = modelViewMatrix
			uniforms.mode = 1
			
			mainRenderEncoder.setVertexBuffer(makeBuffer(&uniforms), offset: 0, index: 3)
			mainRenderEncoder.drawIndexedPrimitives(type: .triangleStrip, indexCount: 6, indexType: .uint16, indexBuffer: makeBuffer(indices), indexBufferOffset: 0)
			mainRenderEncoder.endEncoding()
		
		}
		
		/// post render passes
		
		if (postProcessingEnabled) {
			let passes = 1
			for i in 0...passes {
				
				// render vertical blur to framebuffer
				postRenderPass(commandBuffer: commandBuffer, texture: renderTargetA, renderTarget: renderTargetB, blurDirection: [0, 1])
				
				// render horizontal blur to screen
				postRenderPass(commandBuffer: commandBuffer, texture: renderTargetB, renderTarget: i == passes ? drawable.texture : renderTargetA, blurDirection: [1, 0])
			}
		}
		
		commandBuffer.present(view.currentDrawable!)
		commandBuffer.commit()
		
	}
	
	func postRenderPass(commandBuffer: MTLCommandBuffer, texture: MTLTexture, renderTarget: MTLTexture, blurDirection: [Float]) {
		postRenderPassDescriptor.colorAttachments[0].texture = renderTarget
		
		let postRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: postRenderPassDescriptor)!
			postRenderEncoder.setRenderPipelineState(self.postPipelineState)
				
		let indices: [Int16] = [
			0, 1, 2,
			0, 2, 3
		]
		
		let resolution: [Float] = [
			Float(renderTarget.width),
			Float(renderTarget.height)
		]
		
		postRenderEncoder.setVertexBuffer(makeBuffer(blurDirection), offset: 0, index: 0)
		postRenderEncoder.setVertexBuffer(makeBuffer(resolution), offset: 0, index: 1)
		postRenderEncoder.setFragmentTexture(texture, index: 0)
		postRenderEncoder.setFragmentSamplerState(samplerState, index: 0)
		postRenderEncoder.drawIndexedPrimitives(type: .triangleStrip, indexCount: 6, indexType: .uint16, indexBuffer: makeBuffer(indices), indexBufferOffset: 0)
		postRenderEncoder.endEncoding()
	}
	
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		let aspect = Float(size.width) / Float(size.height)
        projectionMatrix = matrix_perspective_right_hand(fovyRadians: radians_from_degrees(65), aspectRatio:aspect, nearZ: 0.1, farZ: 100.0)
		
		let mainRenderTargetTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: mtkView.colorPixelFormat, width: Int(size.width), height: Int(size.height), mipmapped: false)
			mainRenderTargetTextureDescriptor.usage = [.shaderRead, .renderTarget]
		
		renderTargetA = device.makeTexture(descriptor: mainRenderTargetTextureDescriptor)
		renderTargetB = device.makeTexture(descriptor: mainRenderTargetTextureDescriptor)
	}
	
}

// Utility functions

func loadTexture(device: MTLDevice,
					   textureName: String) throws -> MTLTexture {
	let textureLoader = MTKTextureLoader(device: device)

	let textureLoaderOptions = [
		MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
		MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.`private`.rawValue)
	]

	return try textureLoader.newTexture(
		name: textureName,
		scaleFactor: 1.0,
		bundle: nil,
		options: textureLoaderOptions
	)

}

func matrix4x4_rotation(radians: Float, axis: SIMD3<Float>) -> matrix_float4x4 {
    let unitAxis = normalize(axis)
    let ct = cosf(radians)
    let st = sinf(radians)
    let ci = 1 - ct
    let x = unitAxis.x, y = unitAxis.y, z = unitAxis.z
    return matrix_float4x4.init(columns:(vector_float4(    ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
                                         vector_float4(x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0),
                                         vector_float4(x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0),
                                         vector_float4(                  0,                   0,                   0, 1)))
}

func matrix4x4_translation(_ translationX: Float, _ translationY: Float, _ translationZ: Float) -> matrix_float4x4 {
    return matrix_float4x4.init(columns:(vector_float4(1, 0, 0, 0),
                                         vector_float4(0, 1, 0, 0),
                                         vector_float4(0, 0, 1, 0),
                                         vector_float4(translationX, translationY, translationZ, 1)))
}

func matrix_perspective_right_hand(fovyRadians fovy: Float, aspectRatio: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let ys = 1 / tanf(fovy * 0.5)
    let xs = ys / aspectRatio
    let zs = farZ / (nearZ - farZ)
    return matrix_float4x4.init(columns:(vector_float4(xs,  0, 0,   0),
                                         vector_float4( 0, ys, 0,   0),
                                         vector_float4( 0,  0, zs, -1),
                                         vector_float4( 0,  0, zs * nearZ, 0)))
}

func radians_from_degrees(_ degrees: Float) -> Float {
    return (degrees / 180) * .pi
}

func matrix4x4_scale(xScale: Float, yScale: Float, zScale: Float) -> matrix_float4x4 {
    return matrix_float4x4.init(columns: (
		vector_float4(xScale,      0, 0, 		0),
		vector_float4(     0, yScale, 0, 		0),
		vector_float4(     0,      0, zScale, 	0),
		vector_float4(     0,      0, 0, 		1)
	))
}

func matrix4x4_scale(scale: Float) -> matrix_float4x4 {
    return matrix_float4x4.init(columns: (
		vector_float4(scale,      0, 0, 		0),
		vector_float4(     0, scale, 0, 		0),
		vector_float4(     0,      0, scale, 	0),
		vector_float4(     0,      0, 0, 		1)
	))
}
