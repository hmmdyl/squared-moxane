module moxane.graphics.light.dist;

import moxane.core;
import moxane.graphics.postprocess;

import std.file : readText;

final class PointLightPostProcess : PostProcess
{
	override protected string fragmentShader() {
		return readText(AssetManager.translateToAbsoluteDir("content/moxane/shaders/pointLight.vs.glsl"));
	}

	this(Moxane moxane, PostProcessCommon comm) { super(PointLightPostProcess.stringof, moxane, comm); }

	override protected void getUniforms() {
		super.getUniforms;
		effect.findUniform("LightPosition");
		effect.findUniform("LightColour");
		effect.findUniform("AmbientIntensity");
		effect.findUniform("DiffuseIntensity");
		effect.findUniform("ConstantAttenuation");
		effect.findUniform("LinearAttenuation");
		effect.findUniform("ExponentialAttenuation");
	}


}