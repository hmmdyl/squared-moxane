#version 430 core

in vec2 fTexCoord;

uniform sampler2D Texture;

uniform vec4 Colour;

layout(location = 0) out vec4 Fragment;

void main()
{
	float tex = texture(Texture, fTexCoord).r;
	Fragment.rgb = Colour.rgb;
	Fragment.a = Colour.a * tex;
}