#version 430 core

layout(location = 0) in vec2 Vertex;

uniform vec2 Position;
uniform vec2 Dimensions;
uniform mat4 MVP;

out vec2 fTexCoord;

void main()
{
	fTexCoord = vec2(Vertex.x, Vertex.y);
	vec2 vertProper = Position + (Vertex * Dimensions);
	gl_Position = MVP * vec4(vertProper, 0, 1);
}