#version 430 core

layout(location = 0) in vec2 Vertex;

uniform vec2 FramebufferSize;
uniform mat4 Projection;

void main()
{
	gl_Position = Projection * vec4(Vertex.x * FramebufferSize.x, Vertex.y * FramebufferSize.y, 0, 1);
}