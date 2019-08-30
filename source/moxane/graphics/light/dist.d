module moxane.graphics.light.dist;

import moxane.core;
import moxane.graphics.postprocess;
import moxane.graphics.light.types;
import moxane.graphics.renderer;
import moxane.graphics.rendertexture;

import derelict.opengl3.gl3;
import dlib.math.vector;
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

final class LightDistributor
{
	UnrolledList!PointLight pointLights;

	private PointLightPostProcess pointLightEffect;
	private PostProcessTexture intermediate;

	this(Moxane moxane, PostProcessCommon common, uint width, uint height)
	{
		pointLightEffect = new PointLightPostProcess(moxane, common);
		intermediate = new PostProcessTexture(width, height);
	}

	~this()
	{
		destroy(intermediate);
		intermediate = null;
		destroy(pointLightEffect);
		pointLightEffect = null;
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

		pointLightEffect.pointLights = inputRangeObject(pointLights[]);
		pointLightEffect.cameraPosition = cam;
		pointLightEffect.strengthOverride = strengthOverride;
		pointLightEffect.render(renderer, lc, scene, null, output); // TODO: change output to intermediate when next light stage is added.
	}
}