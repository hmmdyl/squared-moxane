#version 430 core

uniform vec3 LightPosition;
uniform vec3 LightColour;
uniform float AmbientIntensity;
uniform float DiffuseIntensity;
uniform float ConstantAttenuation;
uniform float LinearAttenuation;
uniform float ExponentialAttenuation;

uniform vec2 FramebufferSize;
uniform vec3 CameraPosition;

uniform sampler2D WorldPosTexture;
uniform sampler2D DiffuseTexture;
uniform sampler2D NormalTexture;
uniform sampler2D DepthTexture;
uniform sampler2D SpecTexture;

out vec3 Fragment;

vec4 calculateLight(vec3 colour, float ambientIntensity, float diffuseIntensity, vec3 lightDirection, vec3 worldPosition, vec3 normal, float shadow, vec4 meta) {
	vec4 ambientColour = vec4(colour * ambientIntensity, 1.0);
	float diffuseFactor = dot(normal, -lightDirection);
	
	vec4 diffuseColour = vec4(0.0);
	vec4 specularColour = vec4(0.0);
	
	if(diffuseFactor > 0.0) {
		diffuseColour = vec4(colour * diffuseIntensity * diffuseFactor, 1.0);
		
		vec3 vertToEye = normalize(CameraPosition - worldPosition);
		vec3 lightReflect = normalize(reflect(lightDirection, normal));
		float specularFactor = dot(vertToEye, lightReflect);

		if(specularFactor > 0.0) {
			specularFactor = pow(specularFactor, meta.x); // todo: implement specular mapping
			specularColour = vec4(colour * meta.y * specularFactor, 1.0);
		}
	}
	
	return (ambientColour + shadow * (diffuseColour + specularColour));
}

vec4 calculatePointLight(vec3 worldPosition, vec3 normal, vec4 meta) {
	vec3 lightDir = worldPosition - LightPosition;
	//vec3 lightDir = LightPosition - worldPosition;
	float distance = length(lightDir);
	lightDir = normalize(lightDir);
	
	float shadow = 1.0;
	
	vec4 colour = calculateLight(LightColour, AmbientIntensity, DiffuseIntensity, lightDir, worldPosition, normal, shadow, meta);
	
	float attenuation = ConstantAttenuation + LinearAttenuation * distance + ExponentialAttenuation * distance * distance;
	attenuation = max(1.0, attenuation);
	
	return colour / attenuation;
}

void main()
{
	vec2 tc = gl_FragCoord.xy / FramebufferSize;
	vec3 worldPos = texture(WorldPosTexture, tc).rgb;
	vec3 normal = texture(NormalTexture, tc).rgb;
	vec3 diffuse = texture(DiffuseTexture, tc).rgb;
	vec4 meta  = texture(SpecTexture, tc).rgba;

	vec4 l = normal == vec3(0) ? vec4(1) : calculatePointLight(worldPos, normal, meta);

	Fragment = diffuse * l.xyz;
}