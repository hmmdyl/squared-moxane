GL_VERTEX_SHADER

#version 430 core

layout(location = 0) in vec2 Vertex;
layout(location = 1) in vec2 TexCoord;
layout(location = 2) in vec4 Colour;

out vec2 fTexCoord;
out vec4 fColour;

uniform mat4 Projection;

void main()
{
	fTexCoord = TexCoord;
	fColour = Colour;
	gl_Position = Projection * vec4(Vertex, 0, 1);
}