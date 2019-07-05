module moxane.graphics.postprocesses.fog;

import moxane.graphics.rendertexture;
import moxane.graphics.postprocess;
import moxane.graphics.renderer;
import moxane.core;

import dlib.math;

import std.file : readText;

final class Fog : PostProcess
{
	override protected string fragmentShader() { return readText(AssetManager.translateToAbsoluteDir("content/moxane/shaders/fogPostProcess.fs.glsl"));	}

	this(Moxane moxane, PostProcessCommon common)
	{
		super(Fog.stringof, moxane, common);
	}

	override protected void getUniforms() 
	{
		super.getUniforms;
		effect.findUniform("Colour");
		effect.findUniform("Gradient");
		effect.findUniform("Density");
	}

	Vector3f colour;
	float density;
	float gradient;

	void update(Vector3f colour, float density, float gradient)
	in(colour.x != float.nan && colour.y != float.nan && colour.z != float.nan)
	in(density != float.nan && gradient != float.nan)
	{
		this.colour = colour;
		this.density = density;
		this.gradient = gradient;
	}

	override protected void bind(Renderer renderer,ref LocalContext lc,RenderTexture source,PostProcessTexture previousStageSource,PostProcessTexture output) 
	{
		super.bind(renderer,lc,source,previousStageSource,output);
		effect["Colour"].set(colour);
		effect["Gradient"].set(gradient);
		effect["Density"].set(density);
	}
}