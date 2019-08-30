module moxane.graphics.postprocess;

import moxane.graphics.effect;
import moxane.graphics.rendertexture;
import moxane.graphics.renderer;
import moxane.graphics.log;
import moxane.core;

import dlib.math;
import derelict.opengl3.gl3;
import std.file : readText;
import containers.unrolledlist;

class PostProcessCommon
{
	uint quadVao;
	uint quadVbo;
	enum vertices = 6;

	this()
	{
		immutable Vector2f[] verts = [
			Vector2f(0, 0),
			Vector2f(1, 0),
			Vector2f(1, 1),
			Vector2f(1, 1),
			Vector2f(0, 1),
			Vector2f(0, 0)
		];

		glGenVertexArrays(1, &quadVao);
		glGenBuffers(1, &quadVbo);
		glBindBuffer(GL_ARRAY_BUFFER, quadVbo);
		glBufferData(GL_ARRAY_BUFFER, verts.length * Vector2f.sizeof, verts.ptr, GL_STATIC_DRAW);
		glBindBuffer(GL_ARRAY_BUFFER, 0);
	}

	~this()
	{
		glDeleteVertexArrays(1, &quadVao);
		glDeleteBuffers(1, &quadVbo);
	}
}

abstract class PostProcess
{
	protected abstract string fragmentShader();
	protected string vertexShader() { return readText(AssetManager.translateToAbsoluteDir("content/moxane/shaders/postProcess.vs.glsl")); }

	protected Effect effect;
	PostProcessCommon common;

	this(string postProcessName, Moxane moxane, PostProcessCommon common)
	in(postProcessName !is null) in(moxane !is null) in(common !is null)
	do {
		this.common = common;

		Log log = moxane.services.getAOrB!(GraphicsLog, Log);
		Shader vs = new Shader, fs = new Shader;
		vs.compile(vertexShader, GL_VERTEX_SHADER, log);
		fs.compile(fragmentShader, GL_FRAGMENT_SHADER, log);
		effect = new Effect(moxane, postProcessName);
		effect.attachAndLink(vs, fs);
		effect.bind;
		getUniforms;
		effect.unbind;
	}

	protected void getUniforms()
	{
		effect.findUniform("FramebufferSize");
		effect.findUniform("Projection");
		effect.findUniform("DepthTexture");
		effect.findUniform("DiffuseTexture");
		effect.findUniform("WorldPosTexture");
		effect.findUniform("NormalTexture");
		effect.findUniform("MetaTexture");
	}

	~this()
	{
		destroy(effect);
	}

	protected void bind(Renderer renderer, ref LocalContext lc, RenderTexture source, PostProcessTexture previousStageSource, PostProcessTexture output)
	{
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, previousStageSource is null ? source.diffuse : previousStageSource.diffuse);
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, source.worldPos);
		glActiveTexture(GL_TEXTURE2);
		glBindTexture(GL_TEXTURE_2D, source.normal);
		glActiveTexture(GL_TEXTURE3);
		glBindTexture(GL_TEXTURE_2D, source.depthTexture.depth);
		glActiveTexture(GL_TEXTURE4);
		glBindTexture(GL_TEXTURE_2D, source.spec);

		effect.bind;
		effect["FramebufferSize"].set(Vector2f(lc.camera.width, lc.camera.height));
		effect["Projection"].set(&lc.projection);
		effect["MetaTexture"].set(4);
		effect["DepthTexture"].set(3);
		effect["DiffuseTexture"].set(0);
		effect["WorldPosTexture"].set(1);
		effect["NormalTexture"].set(2);

		if(output is null)
		{
			glBindFramebuffer(GL_FRAMEBUFFER, 0);
			glClear(GL_COLOR_BUFFER_BIT);
		}
		else
		{
			output.bindDraw;
			output.clear;
		}

		glBindVertexArray(common.quadVao);
		glEnableVertexAttribArray(0);
	}

	protected void unbind()
	{
		glDisableVertexAttribArray(0);
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, 0);
		glActiveTexture(GL_TEXTURE2);
		glBindTexture(GL_TEXTURE_2D, 0);
		glActiveTexture(GL_TEXTURE3);
		glBindTexture(GL_TEXTURE_2D, 0);
		glActiveTexture(GL_TEXTURE4);
		glBindTexture(GL_TEXTURE_2D, 0);
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, 0);

		glBindVertexArray(0);
		glBindBuffer(GL_ARRAY_BUFFER, 0);
		effect.unbind;
	}

	protected void draw()
	{
		glBindBuffer(GL_ARRAY_BUFFER, common.quadVbo);
		glVertexAttribPointer(0, 2, GL_FLOAT, false, 0, null);

		glDrawArrays(GL_TRIANGLES, 0, common.vertices);
	}

	void render(Renderer renderer, ref LocalContext lc, RenderTexture source, PostProcessTexture previousStageSource, PostProcessTexture output)
	in(renderer !is null) in(source !is null)
	do {
		bind(renderer, lc, source, previousStageSource, output);
		draw;
		unbind;
	}
}

final class PassPostProcess : PostProcess
{
	override protected string fragmentShader() { return readText(AssetManager.translateToAbsoluteDir("content/moxane/shaders/passPostProcess.fs.glsl")); }

	this(Moxane moxane, PostProcessCommon common)
	{
		super(PassPostProcess.stringof, moxane, common);
	}
}

final class PostProcessDistributor
{
	UnrolledList!PostProcess processes;

	PostProcessCommon common;
	PostProcessTexture lightTexture;
	private PostProcessTexture[2] ppTextures;

	PassPostProcess passThrough;

	this(uint width, uint height, Moxane moxane, bool lightingInput = true)
	{
		common = new PostProcessCommon;
		ppTextures[0] = new PostProcessTexture(width, height);
		ppTextures[1] = new PostProcessTexture(width, height);
		if(lightingInput) lightTexture = new PostProcessTexture(width, height);
		passThrough = new PassPostProcess(moxane, common);
	}

	void updateFramebufferSize(uint width, uint height)
	{
		foreach(PostProcessTexture pp; ppTextures)
		{
			pp.width = width;
			pp.height = height;
			pp.createTextures;
		}
		lightTexture.width = width;
		lightTexture.height = height;
		lightTexture.createTextures;
	}

	void render(Renderer renderer, ref LocalContext lc)
	{
		if(processes.length == 0)
			passThrough.render(renderer, lc, renderer.scene, lightTexture is null ? null : lightTexture, null);
		else if(processes.length == 1)
			processes.front.render(renderer, lc, renderer.scene, lightTexture is null ? null : lightTexture, null);
		else
		{
			size_t idPrev = 0;
			size_t id = 0;

			foreach(PostProcess pp; processes)
			{
				scope(exit) id++;

				if(id == 0)
					pp.render(renderer, lc, renderer.scene, lightTexture is null ? null : lightTexture, ppTextures[0]);
				else if(id == processes.length - 1)
					pp.render(renderer, lc, renderer.scene, ppTextures[idPrev], null);
				else
				{
					size_t next = idPrev == 0 ? 1 : 0;
					pp.render(renderer, lc, renderer.scene, ppTextures[idPrev], ppTextures[next]);
					idPrev = next;
				}
			}
		}
	}
}