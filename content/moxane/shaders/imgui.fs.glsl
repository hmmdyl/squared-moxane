GL_FRAGMENT_SHADER

#version 430 core

in vec2 fTexCoord;
in vec4 fColour;

out vec4 Fragment;

uniform sampler2D Texture;

void main()
{
	Fragment = fColour;
	Fragment.a *= texture(Texture, vec2(fTexCoord.x, fTexCoord.y)).r;
	//Fragment.a = 0.5;
}