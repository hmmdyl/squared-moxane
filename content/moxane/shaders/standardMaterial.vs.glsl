#version 430 core

layout(location = 0) in vec3 Vertex;
layout(location = 1) in vec3 Normal;
layout(location = 2) in vec2 TexCoord;

out vec3 fWorldPos;
out vec3 fNormal;
out vec2 fTexCoord;

uniform mat4 Model;
uniform mat4 MVP;

void main()
{
	fWorldPos = (Model * vec4(Vertex, 1.0)).xyz;
	gl_Position = MVP * vec4(Vertex, 1.0);
	
	fNormal = (Model * vec4(Normal, 1)).xyz;
	fTexCoord = TexCoord;
}