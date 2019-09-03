#version 400 core

layout(location = 0) out vec3 DiffuseOut;

uniform vec3 LightDirection;
uniform vec3 LightColour;
uniform float AmbientIntensity;
uniform float DiffuseIntensity;

uniform vec2 FramebufferSize;

uniform sampler2D WorldPosTexture;
uniform sampler2D DiffuseTexture;
uniform sampler2D NormalTexture;
uniform sampler2D DepthTexture;

uniform vec3 CameraPosition;

uniform mat4 LightViewProjection;
uniform vec3 LightPos;
uniform bool CastShadow;
uniform float ShadowDistance;
uniform float ShadowTransitionDistance;

const float ShadowMapCutoffLower = 0.05;
const float ShadowMapCutoffHigher = 0.95;

vec2 calculateTexCoord() {
	return gl_FragCoord.xy / FramebufferSize;
}

vec4 calculateLight(vec3 colour, float ambientIntensity, float diffuseIntensity, vec3 lightDirection, vec3 worldPosition, vec3 normal, float shadow) {
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
			specularFactor = pow(specularFactor, 0.1); // todo: implement specular mapping
			specularColour = vec4(colour * 0.01 * specularFactor, 1.0);
		}
	}
	
	return (ambientColour + (1.0 - shadow) * (diffuseColour + specularColour));
}

float texture2DCompare(sampler2D depthTexture, vec2 uv, float compare)
{
	float depth = texture2D(depthTexture, uv).r;
	return step(compare, depth);
}

float shadowLerp(sampler2D depthTexture, vec2 texelSize, vec2 size, vec2 coord, float compare)
{
	vec2 f = fract(coord * size + 0.5);
	vec2 centroidUV = floor(coord * size + 0.5) / size;

	float lb = texture2DCompare(depthTexture, centroidUV + texelSize * vec2(0,0), compare);
	float lt = texture2DCompare(depthTexture, centroidUV + texelSize * vec2(0,1), compare);
	float rb = texture2DCompare(depthTexture, centroidUV + texelSize * vec2(1,0), compare);
	float rt = texture2DCompare(depthTexture, centroidUV + texelSize * vec2(1,1), compare);
	float a = mix(lb, lt, f.y);
	float b = mix(rb, rt, f.y);
	float c = mix(a, b, f.x);
	return c;
}

float calculateShadow(vec4 fragPosLightSpace, vec3 normal, vec3 lightDir, vec3 worldPos) {
	vec3 projCoords = fragPosLightSpace.xyz / fragPosLightSpace.w;
	projCoords = projCoords * 0.5 + 0.5;

	if(projCoords.z > 1.0) return 0.0;
	if(projCoords.x < ShadowMapCutoffLower || 
		projCoords.x > ShadowMapCutoffHigher || 
		projCoords.y < ShadowMapCutoffLower || 
		projCoords.y > ShadowMapCutoffHigher) return 0;

	float currentDepth = projCoords.z;
	float bias = 0.005;
	bias = max(0.0025 * (1.0 - dot(normal, lightDir)), 0.0001);
	float shadow = 0.0;
	vec2 texelSize = 1.0 / textureSize(DepthTexture, 0);

	for(int x = -1; x <= 1; ++x)
	{
		for(int y = -1; y <= 1; ++y)
		{
			vec2 offset = vec2(x, y) * texelSize;
			shadow += 1.0 - shadowLerp(DepthTexture, texelSize, 1 / texelSize, projCoords.xy + offset, currentDepth - bias);
			//float depth = texture(DepthTexture, projCoords.xy + vec2(x, y) * texelSize).r;
			//shadow += currentDepth - bias > depth ? 1.0 : 0.0;
		}
	}
	shadow /= 9.0;

	float dist = length(CameraPosition-worldPos);
	dist = dist - (ShadowDistance - ShadowTransitionDistance);
	dist /= ShadowTransitionDistance;
	dist = clamp(1.0 - dist, 0.0, 1.0);
	//shadow *= dist;
	
	///shadow *= clamp(1 - dist, 0, 1);

	return shadow;
	
	/*vec3 projCoords = fragPosLightSpace.xyz / fragPosLightSpace.w;

	vec2 texCoords;
	texCoords.x = 0.5 * projCoords.x + 0.5;
	texCoords.y = 0.5 * projCoords.y + 0.5;
	float z = 0.5 * projCoords.z + 0.5;
	
	//float depth = texture(DepthTexture, texCoords).r;
	
	float bias = 0.0003;
	//float bias = 0;
	//bias = max(0.0015 * (0.0 - dot(normal, lightDir)), 0.00001);
	//bias = max(0.001 * (1.0 - 0.75 * dot(normal, lightDir)), 0.00001);
	//bias = max(0.025 * (1.0 - dot(normal, lightDir)), 0.0001);
	bias = max(0.05 * (1.0 - dot(normal, lightDir)), 0.005);
	
	float shadow = 0.0;
	vec2 texelSize = 1.0 / textureSize(DepthTexture, 0);
	
	for(int x = -1; x <= 1; x++) {
		for(int y = -1; y <= 1; y++) {
			float depth = texture(DepthTexture, texCoords + vec2(x, y) * texelSize).r;
			shadow += z - bias > depth ? 1.0 : 0.0;
		}
	}
	shadow /= 1.0;
	
	shadow = clamp(shadow, 0.0, 1.0);
	
	return shadow;*/
}

vec4 calculateDirectionalLight(vec3 worldPos, vec3 normal, float shadow) {
	return calculateLight(LightColour, AmbientIntensity, DiffuseIntensity, LightDirection, worldPos, normal, shadow);
}

void main() {
	vec2 texCoord = calculateTexCoord();
	vec3 worldPos = texture(WorldPosTexture, texCoord).rgb;
	vec3 diffuse = texture(DiffuseTexture, texCoord).rgb;
	vec3 normal = normalize(texture(NormalTexture, texCoord).rgb);
	
	float shadow = 0.0;
	if(CastShadow) {	
		vec4 fragPosLightSpace = LightViewProjection * vec4(worldPos, 1.0);
		shadow = calculateShadow(fragPosLightSpace, normal, LightDirection, worldPos);
	}
	DiffuseOut = (vec4(diffuse, 1.0) * calculateDirectionalLight(worldPos, normal, shadow)).xyz;
}