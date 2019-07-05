#version 430 core

uniform vec2 FramebufferSize;
uniform sampler2D DepthTexture;
uniform sampler2D DiffuseTexture;
uniform sampler2D WorldPosTexture;
uniform sampler2D NormalTexture;

uniform vec3 Colour;
uniform float Gradient;
uniform float Density;

out vec3 Fragment;

void main()
{
	vec2 tc = gl_FragCoord.xy / FramebufferSize;
	vec3 worldPos = texture(WorldPosTexture, tc).rgb;
	vec3 diffuse = texture(DiffuseTexture, tc).rgb;

	float dist = length(worldPos);
	float fogFactor = clamp(exp(-pow(dist * Density, Gradient)), 0, 1);

	Fragment = mix(Colour, diffuse, fogFactor);
}