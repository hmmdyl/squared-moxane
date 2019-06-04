#version 430 core

layout(location = 0) in vec2 Vertex;

uniform ivec2 Position;
uniform ivec2 Dimensions;
uniform mat4 MVP;

out vec2 fTexCoord;

void main()
{
	fTexCoord = vec2(Vertex.x, 1.0 - Vertex.y);
	vec2 vertProper = Position + (Vertex * Dimensions);
	gl_Position = MVP * vec4(vertProper, 0, 1);
}