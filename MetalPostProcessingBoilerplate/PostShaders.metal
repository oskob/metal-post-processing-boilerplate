//
//  Shaders.metal
//  metalfromscratch
//
//  Created by Oskar on 2019-10-27.
//  Copyright © 2019 Shortcut Labs AB. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct VertexOut{
	float4 position [[position]];
	float2 texCoord;
	float4 color;
	float2 direction;
	float2 resolution;
};

vertex VertexOut post_vertex(
	const device float2& direction [[ buffer(0) ]],
	const device float2& resolution [[ buffer(1) ]],
	unsigned int vid [[ vertex_id ]]
) {
	
	float4x3 vertices = float4x3(
		-1, -1, 0,
		-1,  1, 0,
		1,  1, 0,
		1, -1, 0
	);
	
	float4x2 texCoords = float4x2(
		0.0, 1.0,
		0.0, 0.0,
		1.0, 0.0,
		1.0, 1.0
	);
	
	VertexOut out;
	out.position = float4(vertices[vid], 1.0);
	out.texCoord = texCoords[vid];
	out.direction = direction;
	out.resolution = resolution;
	return out;
}

// ported from https://github.com/Jam3/glsl-fast-gaussian-blur/blob/master/9.glsl

float4 blur9(sampler sampler2D, texture2d<float> texture, float2 uv, float2 resolution, float2 direction) {
  float4 color = float4(0.0);
  float2 off1 = float2(1.3846153846) * direction;
  float2 off2 = float2(3.2307692308) * direction;
  color += texture.sample(sampler2D, uv) * 0.2270270270;
  color += texture.sample(sampler2D, uv + (off1 / resolution)) * 0.3162162162;
  color += texture.sample(sampler2D, uv - (off1 / resolution)) * 0.3162162162;
  color += texture.sample(sampler2D, uv + (off2 / resolution)) * 0.0702702703;
  color += texture.sample(sampler2D, uv - (off2 / resolution)) * 0.0702702703;
  return color;
}

fragment float4 post_fragment(
	VertexOut in [[stage_in]],
	texture2d<float> texture [[ texture(0) ]],
	sampler sampler2D [[ sampler(0) ]]
) {
	return blur9(sampler2D, texture, in.texCoord, in.resolution, in.direction);
}
