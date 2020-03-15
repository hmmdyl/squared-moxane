#version 430 core

in vec2 fTexCoord;

uniform sampler2D Texture;
uniform vec3 Colour;
uniform float Alpha;
uniform bool Text;

layout(location = 0) out vec4 Fragment;

void main()
{
	vec4 tex = texture(Texture, fTexCoord);
    if(Text)
    {
        Fragment.rgb = tex.r * Colour.rgb;
        Fragment.a = tex.r * Alpha;
    }
    else
    {
	    Fragment.rgb = tex.rgb * Colour.rgb;
	    Fragment.a = tex.a * Alpha;
    }
}