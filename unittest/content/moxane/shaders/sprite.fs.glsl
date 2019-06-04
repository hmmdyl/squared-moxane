#version 430 core

in vec2 fTexCoord;

uniform sampler2D Texture;
uniform bool UseTexture;

uniform vec4 Colour;
uniform bool MixAlpha;

layout(location = 0) out vec4 Fragment;

void main()
{
	if(UseTexture)
	{
		vec4 tex = texture(Texture, fTexCoord);
		Fragment.rgb = tex.rgb * Colour.rgb;
		if(MixAlpha)
			Fragment.a = tex.a * Colour.a;
		else
			Fragment.a = Colour.a;
	}
	else
	{
		Fragment = Colour;
	}
}