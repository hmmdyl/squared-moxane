#version 430 core

layout(location = 0) in vec2 Vertex;
layout(location = 1) in vec2 TexCoord;

uniform ivec2 Position;
uniform ivec2 Dimensions;
uniform mat4 MVP;

out vec2 fTexCoord;

void main()
{
	fTexCoord = TexCoord;
	vec2 vertProper = Position + (Vertex * Dimensions);
	gl_Position = MVP * vec4(vertProper, 0, 1);
}