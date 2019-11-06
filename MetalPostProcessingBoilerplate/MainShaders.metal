#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct VertexOut{
	float4 position [[position]];
	float2 texCoord;
	float4 color;
	int mode;
};

struct Uniforms
{
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 modelViewMatrix;
	uint8_t mode;
};

vertex VertexOut main_vertex(
	const device packed_float3* vertex_array [[ buffer(0) ]],
	const device packed_float2* texcoord_array [[ buffer(1) ]],
	const device packed_float4* color_array [[ buffer(2) ]],
	constant Uniforms &uniforms [[buffer(3)]],
	unsigned int vid [[ vertex_id ]]
) {
	float4 position = float4(vertex_array[vid], 1.0);
	float4 finalPosition = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
	
	VertexOut out;
	out.position = finalPosition;
	out.texCoord = texcoord_array[vid];
	out.color = color_array[vid];
	out.mode = uniforms.mode;
	return out;
}

fragment float4 main_fragment(
	VertexOut in [[stage_in]],
	texture2d<float>  texture     [[ texture(0) ]],
	sampler           sampler2D [[ sampler(0) ]]
) {
	if (in.mode == 0) {
		return texture.sample(sampler2D, in.texCoord);
	} else {
		return in.color;
	}
}
