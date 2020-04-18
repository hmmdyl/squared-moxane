module moxane.graphics.redo.pipeline;

import moxane.core;
import moxane.io.window;

import moxane.graphics.redo.camera;
import moxane.graphics.redo.resources;

import dlib.math;
import containers;

import std.exception : enforce;

enum PipelineDrawState : ubyte
{
	ui,
	scene
}

struct PipelineStatics
{
	uint drawCalls;
	uint vertexCount;
	uint effectBinds;
}

struct LocalContext
{
	Camera camera;
	Matrix4f inheritedModel;
	immutable PipelineDrawState state;

	this(Camera camera, Matrix4f inheritModel, immutable PipelineDrawState state)
	{
		this.camera = camera;
		this.inheritedModel = inheritedModel;
		this.state = state;
	}
}

interface IDrawable
{ void draw(Pipeline, ref LocalContext, ref PipelineStatics); }

class Pipeline
{
	Moxane moxane;

	private Scene scene_;
	@property Scene scene() { return scene_; }

	private Camera outputOrtho;
	private DefaultFramebuffer screenFramebuffer;
	private DepthTexture sceneDepthBuffer;
	private SceneFramebuffer sceneFramebuffer;

	UnrolledList!IDrawable shadowQueue;
	UnrolledList!IDrawable physicalQueue;
	UnrolledList!IDrawable uiQueue;

	Window window;
	PipelineCommon common;

	this(Moxane moxane, Scene scene)
		in { assert(moxane !is null); assert(!scene is null); }
	do {
		common = moxane.services.get!PipelineCommon;
		if(common is null)
		{
			common = new PipelineCommon;
			moxane.services.register!PipelineCommon(common);
		}

		window = moxane.services.get!Window;
		enforce(window !is null);
		window.onFramebufferResize ~= &windowFramebufferResize;

		screenFramebuffer = new DefaultFramebuffer(window.framebufferSize.width, window.framebufferSize.height);
		sceneDepthBuffer = new DepthTexture(window.framebufferSize.width, window.framebufferSize.height);
		sceneFramebuffer = new SceneFramebuffer(window.framebufferSize.width, window.framebufferSize.height, sceneDepthBuffer);

		outputOrtho = new Camera;
		outputOrtho.ortho.near = -1f;
		outputOrtho.ortho.far = 1f;
	}

	~this()
	{
		destroy(outputOrtho);
		destroy(screenFramebuffer);
		destroy(sceneDepthBuffer);
		destroy(sceneFramebuffer);
	}

	void draw(Camera camera, IFramebuffer output = null)
	{
		if(output is null) output = screenFramebuffer;

		void scenePass()
		{
			sceneFramebuffer.beginDraw;
			scope(exit) sceneFramebuffer.endDraw;

			auto state = PipelineDrawState.scene;
			PipelineStatics stats;
			LocalContext context = LocalContext(camera, Matrix4f.identity, state);

			foreach(IDrawable drawable; physicalQueue)
				drawable.draw(this, context, stats);
		}

		scenePass;
		outputOrtho.width = output.width;
		outputOrtho.height = output.height;
		outputOrtho.deduceOrtho;
		outputOrtho.buildProjection;
		common.passThrough.draw(outputOrtho.projection);
	}

	private void windowFramebufferResize(Window win, Vector2i size)
	{
		screenFramebuffer.update(size.x, size.y);
		sceneDepthBuffer.update(size.x, size.y);
		sceneFramebuffer.update(size.x, size.y);
	}
}

class PipelineCommon
{		
	private PassThrough passThrough;

	this(Moxane moxane)
	{
		passThrough = new PassThrough(moxane);
	}

	~this()
	{
		destroy(passThrough);
	}
}

private class PassThrough
{
	private Effect effect;
	private uint vbo, vao;

	this(Moxane moxane)
	{
		import derelict.opengl3.gl3;

		Log log = moxane.services.getAOrB!(GraphicsLog, Log)();
		assert(log !is null);

		Shader fs = new Shader, vs = new Shader;
		vs.compile(vsCode, GL_VERTEX_SHADER, log);
		fs.compile(fsCode, GL_FRAGMENT_SHADER, log);
		effect = new Effect(moxane, typeof(this).stringof);
		effect.attachAndLink(vs, fs);
		effect.bind;
		effect.findUniform("Size");
		effect.findUniform("Fragment");
		effect.findUniform("Diffuse");
		effect.findUniform("DiffuseSize");
		effect.unbind;

		glGenVertexArrays(1, &vao);
		glGenBuffers(1, &vbo);
		glBindBuffer(GL_ARRAY_BUFFER, vbo);
		auto vertices = [
			Vector2f(0, 0),
			Vector2f(0, 1),
			Vector2f(1, 1),
			Vector2f(1, 1),
			Vector2f(1, 0),
			Vector2f(0, 0)
		];
		glBufferData(GL_ARRAY_BUFFER, Vector2f.sizeof * vertices.length, vertices.ptr, GL_STATIC_DRAW);
		glBindBuffer(GL_ARRAY_BUFFER, 0);
	}

	~this()
	{
		import derelict.opengl3.gl3;

		destroy(effect);
		glDeleteBuffers(1, &vbo);
		glDeleteVertexArrays(1, &vao);
	}

	void draw(ref Matrix4f mvp, IFramebuffer input, IFramebuffer output)
	{
		import derelict.opengl3.gl3;

		glBindVertexArray(vao);
		scope(exit) glBindVertexArray(0);

		glEnableVertexAttribArray(0);
		scope(exit) glDisableVertexAttribArray(0);

		effect.bind;
		scope(exit) effect.unbind;

		input.read([GL_TEXTURE0]);
		scope(exit) input.endRead;
		effect["Diffuse"].set(0);
		effect["Size"].set(Vector2f(output.width, output.height));
		effect["DiffuseSize"].set(Vector2f(input.width, input.height));
		effect["MVP"].set(&mvp);

		output.beginDraw;
		scope(exit) output.endDraw;

		glBindBuffer(GL_ARRAY_BUFFER, vbo);
		scope(exit) glBindBuffer(GL_ARRAY_BUFFER, 0);

		glVertexAttribPointer(0, 2, GL_FLOAT, false, 0, null);

		glDrawArrays(GL_TRIANGLES, 0, 6);
	}

	enum vsCode = "
#version 410 core
		
layout(location = 0) in vec2 Vertex;

uniform vec2 Size;
uniform mat4 MVP;
		
void main()
{
	gl_Position = MVP * vec4(Vertex.x * Size.x, Vertex.y * Size.y, 0, 1);
}";

	enum fsCode = "
#version 410 core

layout(location = 0) out vec4 Fragment;

uniform vec2 DiffuseSize;
uniform sampler2D Diffuse;

void main()
{
	Fragment = texture(Diffuse, gl_FragCoord.xy / DiffuseSize);
}";
}