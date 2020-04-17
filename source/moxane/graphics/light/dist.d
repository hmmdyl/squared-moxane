module moxane.graphics.light.dist;

import moxane.core;
import moxane.graphics.postprocess;
import moxane.graphics.light.types;
import moxane.graphics.renderer;
import moxane.graphics.rendertexture;

import derelict.opengl3.gl3;
import dlib.math;
import containers;
import std.file : readText;


import std.range;
import std.typecons;

private final class PointLightPostProcess : PostProcess
{
	override protected string fragmentShader() {
		return readText(AssetManager.translateToAbsoluteDir("content/moxane/shaders/pointLight.fs.glsl"));
	}

	this(Moxane moxane, PostProcessCommon comm) { super(PointLightPostProcess.stringof, moxane, comm); }

	override protected void getUniforms() 
	{
		super.getUniforms;
		effect.findUniform("LightPosition");
		effect.findUniform("LightColour");
		effect.findUniform("AmbientIntensity");
		effect.findUniform("DiffuseIntensity");
		effect.findUniform("ConstantAttenuation");
		effect.findUniform("LinearAttenuation");
		effect.findUniform("ExponentialAttenuation");
		effect.findUniform("CameraPosition");
	}

	InputRange!PointLight pointLights;
	Vector3f cameraPosition;
	float strengthOverride = 1f;

	override protected void draw() 
	{
		glBindBuffer(GL_ARRAY_BUFFER, common.quadVbo);
		glVertexAttribPointer(0, 2, GL_FLOAT, false, 0, null);
		effect["CameraPosition"].set(cameraPosition);

		foreach(PointLight pl; pointLights)
		{
			effect["LightPosition"].set(pl.position);
			effect["LightColour"].set(pl.colour);
			effect["AmbientIntensity"].set(pl.ambientIntensity);
			effect["DiffuseIntensity"].set(pl.diffuseIntensity * strengthOverride);
			effect["ConstantAttenuation"].set(pl.constAtt);
			effect["LinearAttenuation"].set(pl.linAtt);
			effect["ExponentialAttenuation"].set(pl.expAtt);

			glDrawArrays(GL_TRIANGLES, 0, common.vertices);
		}
	}
}

private final class DirectionalLightPostProcess : PostProcess
{
	override protected string fragmentShader() {
		return readText(AssetManager.translateToAbsoluteDir("content/moxane/shaders/directionalLight.fs.glsl"));
	}

	this(Moxane moxane, PostProcessCommon comm) { super(DirectionalLightPostProcess.stringof, moxane, comm); }

	override protected void getUniforms()
	{
		super.getUniforms;
		effect.findUniform("LightDirection");
		effect.findUniform("LightColour");
		effect.findUniform("AmbientIntensity");
		effect.findUniform("DiffuseIntensity");
		effect.findUniform("CameraPosition");
	}

	InputRange!DirectionalLight lights;
	Vector3f cameraPosition;

	override protected void draw()
	{
		glBindBuffer(GL_ARRAY_BUFFER, common.quadVbo);
		glVertexAttribPointer(0, 2, GL_FLOAT, false, 0, null);
		effect["CameraPosition"].set(cameraPosition);

		foreach(DirectionalLight dl; lights)
		{
			effect["LightDirection"].set(dl.direction);
			effect["LightColour"].set(dl.colour);
			effect["AmbientIntensity"].set(dl.ambientIntensity);
			effect["DiffuseIntensity"].set(dl.diffuseIntensity);

			glDrawArrays(GL_TRIANGLES, 0, common.vertices);
		}
	}
}

immutable string directionalLightShadowFrag = q{
	#version 430 core

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

	uniform sampler2D ShadowDepthTexture;

	uniform mat4 LPV;
	uniform vec2 Bias;
	uniform float SampleMaxCutoff;

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
			vec3 lightReflect = normalize(reflect(-lightDirection, normal));
			float specularFactor = dot(vertToEye, lightReflect);

			if(specularFactor > 0.0) {
				specularFactor = pow(specularFactor, specPower); // todo: implement specular mapping
				specularColour = vec4(colour * specStrength * specularFactor, 1.0);
				//specularColour = vec4(1);
			}
		}

		return (ambientColour + (1.0 - shadow) * (diffuseColour + specularColour));
	}

	vec4 calculateDirectionalLight(vec3 worldPos, vec3 normal, float shadow, float specPower, float specStrength) {
		return calculateLight(LightColour, AmbientIntensity, DiffuseIntensity, LightDirection, worldPos, normal, shadow, specPower, specStrength);
	}

	float calcShadow(vec4 lightSpacePos, vec3 normal)
	{
		vec3 projC = lightSpacePos.xyz / lightSpacePos.w;
		vec2 uvcoords;
		uvcoords.x = 0.5 * projC.x + 0.5;
		uvcoords.y = 0.5 * projC.y + 0.5;
		float z = 0.5 * projC.z + 0.5;

		if(uvcoords.x < 0.01 || uvcoords.x > 0.99 || uvcoords.y < 0.01 || uvcoords.y > 0.99)
			return 0;

		float bias = max(Bias.x * (1.0 - dot(normal, LightDirection)), Bias.y);

		float depthSample = texture(ShadowDepthTexture, uvcoords).x;
		if(depthSample > SampleMaxCutoff)
			return 0;

		float shadow = z - bias > depthSample ? 1 : 0;
		return shadow;
	}

	void main() {
		vec2 texCoord = calculateTexCoord();
		vec3 worldPos = texture(WorldPosTexture, texCoord).rgb;
		vec3 diffuse = texture(DiffuseTexture, texCoord).rgb;
		vec3 normal = normalize(texture(NormalTexture, texCoord).rgb);
		vec2 spec = texture(SpecTexture, texCoord).rg;

		vec4 lps = LPV * vec4(worldPos, 1);
		float vis = calcShadow(lps, normal);
		DiffuseOut = (vec4(diffuse, 1.0) * (normal == vec3(0) ? vec4(1) : calculateDirectionalLight(worldPos, normal, vis, spec.x, spec.y))).xyz;
	}
};

private final class DirLightShadowPP : PostProcess
{
	override protected string fragmentShader() { return directionalLightShadowFrag; }

	this(Moxane moxane, PostProcessCommon comm) { super(DirLightShadowPP.stringof, moxane, comm); }

	override protected void getUniforms() 
	{
		super.getUniforms;
		effect.findUniform("LightDirection");
		effect.findUniform("LightColour");
		effect.findUniform("AmbientIntensity");
		effect.findUniform("DiffuseIntensity");
		effect.findUniform("CameraPosition");
		effect.findUniform("Bias");
		effect.findUniform("ShadowDepthTexture");
		effect.findUniform("LPV");
		effect.findUniform("SampleMaxCutoff");
	}

	DirectionalLight light;
	Vector3f cameraPosition;
	RenderTexture rt;
	Matrix4f lpv;
	float biasL, biasS;

	override protected void draw()
	{
		glActiveTexture(GL_TEXTURE10);
		glBindTexture(GL_TEXTURE_2D, rt.depthTexture.depth);

		glBindBuffer(GL_ARRAY_BUFFER, common.quadVbo);
		glVertexAttribPointer(0, 2, GL_FLOAT, false, 0, null);
		effect["CameraPosition"].set(cameraPosition);

		effect["LightDirection"].set(light.direction);
		effect["LightColour"].set(light.colour);
		effect["AmbientIntensity"].set(light.ambientIntensity);
		effect["DiffuseIntensity"].set(light.diffuseIntensity);
		effect["LPV"].set(&lpv);
		effect["ShadowDepthTexture"].set(10);
		effect["Bias"].set(Vector2f(biasL, biasS));
		effect["SampleMaxCutoff"].set(0.95f);

		glDrawArrays(GL_TRIANGLES, 0, common.vertices);
	}
}

final class LightDistributor
{
	UnrolledList!PointLight pointLights;
	UnrolledList!DirectionalLight directionalLights;

	private PointLightPostProcess pointLightEffect;
	private PostProcessTexture intermediate;
	private DirectionalLightPostProcess directionalLightEffect;
	private DirLightShadowPP shadowLightEffect;

	RenderTexture shadow;
	Matrix4f lpv;
	float biasSmall = 0f, biasLarge = 0.002196532f;

	this(Moxane moxane, PostProcessCommon common, uint width, uint height)
	{
		pointLightEffect = new PointLightPostProcess(moxane, common);
		directionalLightEffect = new DirectionalLightPostProcess(moxane, common);
		shadowLightEffect = new DirLightShadowPP(moxane, common);
		intermediate = new PostProcessTexture(width, height);
	}

	~this()
	{
		destroy(intermediate); intermediate = null;
		destroy(pointLightEffect); pointLightEffect = null;
		destroy(directionalLightEffect); directionalLightEffect = null;
	}

	void updateFramebufferSize(uint width, uint height)
	{
		intermediate.width = width;
		intermediate.height = height;
		intermediate.createTextures;
	}

	void render(Renderer renderer, ref LocalContext lc, RenderTexture scene, PostProcessTexture output, Vector3f cam, float strengthOverride = 1f)
	{
		renderer.gl.blend.push(true);
		scope(exit) renderer.gl.blend.pop;
		renderer.gl.blendEquation.push(GL_FUNC_ADD);
		scope(exit) renderer.gl.blendEquation.pop;
		renderer.gl.blendFunc.push(tuple(GL_ONE, GL_ONE));
		scope(exit) renderer.gl.blendFunc.pop;
		renderer.gl.depthTest.push(false);
		scope(exit) renderer.gl.depthTest.pop;

		output.bindDraw;
		output.clear;

		/+directionalLightEffect.lights = inputRangeObject(directionalLights[]);
		directionalLightEffect.cameraPosition = cam;
		directionalLightEffect.render(renderer, lc, scene, null, output);+/

		shadowLightEffect.light = directionalLights.front;
		shadowLightEffect.cameraPosition = cam;
		shadowLightEffect.rt = shadow;
		shadowLightEffect.lpv = lpv;
		shadowLightEffect.biasL = biasLarge;
		shadowLightEffect.biasS = biasSmall;
		shadowLightEffect.render(renderer, lc, scene, null, output);

		pointLightEffect.pointLights = inputRangeObject(pointLights[]);
		pointLightEffect.cameraPosition = cam;
		pointLightEffect.strengthOverride = strengthOverride;
		pointLightEffect.render(renderer, lc, scene, null, output); // TODO: change output to intermediate when next light stage is added.
		
	}
}