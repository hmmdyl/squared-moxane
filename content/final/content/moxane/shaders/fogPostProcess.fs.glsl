#version 430 core

uniform vec2 FramebufferSize;
uniform sampler2D DepthTexture;
uniform sampler2D DiffuseTexture;
uniform sampler2D WorldPosTexture;
uniform sampler2D NormalTexture;

uniform vec3 Colour;
uniform float Gradient;
uniform float Density;

uniform mat4 View;

out vec3 Fragment;

void main()
{
	vec2 tc = gl_FragCoord.xy / FramebufferSize;
	vec3 worldPos = texture(WorldPosTexture, tc).rgb;
	vec3 diffuse = texture(DiffuseTexture, tc).rgb;
	vec3 normal = texture(NormalTexture, tc).rgb;

	vec3 mvPos = (View * vec4(worldPos, 1)).xyz;
	float dist = length(mvPos);
	float fogFactor = clamp(exp(-pow(dist * Density, Gradient)), 0, 1);

	Fragment = (normal.x == 0 && normal.y == 0 && normal.z == 0) ? diffuse : mix(Colour, diffuse, fogFactor);
}