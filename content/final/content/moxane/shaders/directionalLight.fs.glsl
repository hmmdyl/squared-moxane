#version 400 core

layout(location = 0) out vec3 DiffuseOut;

uniform vec3 LightDirection;
uniform vec3 LightColour;
uniform float AmbientIntensity;
uniform float DiffuseIntensity;

uniform vec2 FramebufferSize;
uniform vec3 CameraPosition;

uniform sampler2D WorldPosTexture;
uniform sampler2D DiffuseTexture;
uniform sampler2D NormalTexture;
uniform sampler2D DepthTexture;
uniform sampler2D SpecTexture;

vec2 calculateTexCoord() {
	return gl_FragCoord.xy / FramebufferSize;
}

vec4 calculateLight(vec3 colour, float ambientIntensity, float diffuseIntensity, vec3 lightDirection, vec3 worldPosition, vec3 normal, float shadow, float specPower, float specStrength) {
	vec4 ambientColour = vec4(colour * ambientIntensity, 1.0);
	float diffuseFactor = dot(normal, lightDirection);
	
	vec4 diffuseColour = vec4(0.0);
	vec4 specularColour = vec4(0.0);
	
	if(diffuseFactor > 0.0) {
		diffuseColour = vec4(colour * diffuseIntensity * diffuseFactor, 1.0);
		
		vec3 vertToEye = normalize(CameraPosition - worldPosition);
		vec3 lightReflect = normalize(reflect(lightDirection, normal));
		float specularFactor = dot(vertToEye, lightReflect);
		
		if(specularFactor > 0.0) {
			specularFactor = pow(specularFactor, specPower); // todo: implement specular mapping
			specularColour = vec4(colour * specStrength * specularFactor, 1.0);
		}
	}
	
	return (ambientColour + (1.0 - shadow) * (diffuseColour + specularColour));
}

vec4 calculateDirectionalLight(vec3 worldPos, vec3 normal, float shadow, float specPower, float specStrength) {
	return calculateLight(LightColour, AmbientIntensity, DiffuseIntensity, LightDirection, worldPos, normal, shadow, specPower, specStrength);
}

void main() {
	vec2 texCoord = calculateTexCoord();
	vec3 worldPos = texture(WorldPosTexture, texCoord).rgb;
	vec3 diffuse = texture(DiffuseTexture, texCoord).rgb;
	vec3 normal = normalize(texture(NormalTexture, texCoord).rgb);
	vec2 spec = texture(SpecTexture, texCoord).rg;
	
	float shadow = 0.0;
	DiffuseOut = (vec4(diffuse, 1.0) * (normal == vec3(0) ? vec4(1) : calculateDirectionalLight(worldPos, normal, shadow, spec.x, spec.y))).xyz;
}