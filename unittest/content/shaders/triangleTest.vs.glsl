GL_VERTEX_SHADER

#version 430 core

layout(location = 0) in vec2 Vertex;
layout(location = 1) in vec3 Colour;

out vec3 vertColour;

void main()
{
	vertColour = Colour;
	gl_Position = vec4(Vertex, 0, 1);
}