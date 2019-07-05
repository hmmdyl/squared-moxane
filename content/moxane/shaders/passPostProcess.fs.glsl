#version 430 core

out vec3 Fragment;

uniform sampler2D DepthTexture;
uniform sampler2D DiffuseTexture;
uniform sampler2D WorldPosTexture;
uniform sampler2D NormalTexture;

uniform vec2 FramebufferSize;

void main()
{
	Fragment = texture(DiffuseTexture, gl_FragCoord.xy / FramebufferSize).rgb;
}