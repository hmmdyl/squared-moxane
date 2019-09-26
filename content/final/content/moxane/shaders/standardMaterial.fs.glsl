#version 430 core

in vec3 fWorldPos;
in vec3 fNormal;
in vec2 fTexCoord;

uniform sampler2D DiffuseTexture;
uniform vec3 Diffuse;
uniform bool UseDiffuseTexture;

uniform sampler2D SpecularTexture;
uniform vec3 Specular;
uniform bool UseSpecularTexture;

uniform sampler2D NormalTexture;
uniform bool UseNormalTexture;

layout(location = 0) out vec3 OutDiffuse;
layout(location = 1) out vec3 OutWorldPos;
layout(location = 2) out vec3 OutNormal;

void main()
{
	if(UseDiffuseTexture) OutDiffuse = texture(DiffuseTexture, fTexCoord).rgb;
	else OutDiffuse = Diffuse;
	
	vec3 OutSpecular;
	if(UseSpecularTexture) OutSpecular = texture(SpecularTexture, fTexCoord).rgb;
	else OutSpecular = Specular;
	
	if(UseNormalTexture) OutNormal = texture(NormalTexture, fTexCoord).rgb;
	else OutNormal = fNormal;
	
	OutWorldPos = fWorldPos;
}