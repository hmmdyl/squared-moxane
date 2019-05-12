GL_FRAGMENT_SHADER

#version 430 core

in vec3 vertColour;

out vec3 fragment;

void main()
{
	fragment = vertColour;
}