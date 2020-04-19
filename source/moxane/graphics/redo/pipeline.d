module moxane.graphics.redo.pipeline;

import moxane.core;
import moxane.io.window;

import moxane.graphics.gl;
import moxane.graphics.redo.camera;
import moxane.graphics.redo.resources;

import dlib.math;
import containers;

import std.exception : enforce;
import std.typecons : Tuple, tuple;

@safe:

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

final class Pipeline
{
	Moxane moxane;

	private Scene scene_;
	@property Scene scene() { return scene_; }

	private Camera outputOrtho;
	private DefaultFramebuffer screenFramebuffer;
	private DepthTexture sceneDepthBuffer;
	private SceneFramebuffer sceneFramebuffer;
	private PostProcessFramebuffer lightFramebuffer;
	private PostProcessFramebuffer fogFramebuffer;

	FogPostProcess fog;

	UnrolledList!IDrawable shadowQueue;
	UnrolledList!IDrawable physicalQueue;
	UnrolledList!IDrawable uiQueue;

	UnrolledList!DirectionalLight directionalLights;
	UnrolledList!PointLight pointLights;

	Window window;
	PipelineCommon common;

	private GLState openGL_;
	@property GLState openGL() { return openGL_; }

	this(Moxane moxane, Scene scene) @trusted
		in { assert(moxane !is null); assert(scene !is null); }
	do {
		moxane.services.register!GraphicsLog(new GraphicsLog);
		common = moxane.services.get!PipelineCommon;
		if(common is null)
		{
			common = new PipelineCommon(moxane);
			moxane.services.register!PipelineCommon(common);
		}
		openGL_ = new GLState(moxane, true);

		window = moxane.services.get!Window;
		enforce(window !is null);

		screenFramebuffer = new DefaultFramebuffer(window.framebufferSize.x, window.framebufferSize.y);
		sceneDepthBuffer = new DepthTexture(window.framebufferSize.x, window.framebufferSize.y);
		sceneFramebuffer = new SceneFramebuffer(window.framebufferSize.x, window.framebufferSize.y, sceneDepthBuffer);
		lightFramebuffer = new PostProcessFramebuffer(window.framebufferSize.x, window.framebufferSize.y);
		fogFramebuffer = new PostProcessFramebuffer(window.framebufferSize.x, window.framebufferSize.y);

		outputOrtho = new Camera;
		outputOrtho.ortho.near = -1f;
		outputOrtho.ortho.far = 1f;

		window.onFramebufferResize.add(&windowFramebufferResize);
		
		fog = new FogPostProcess(moxane, common);

		DirectionalLight dl = new DirectionalLight;
		dl.direction = Vector3f(0, 1, 0);
		dl.colour = Vector3f(1, 1, 1);
		dl.ambientIntensity = 0.5f;
		dl.diffuseIntensity = 1f;
		directionalLights ~= dl;
	}

	~this() @trusted
	{
		destroy(outputOrtho);
		destroy(screenFramebuffer);
		destroy(sceneDepthBuffer);
		destroy(sceneFramebuffer);
	}

	void draw(Camera camera, IFramebuffer output = null) @trusted
	{
		if(output is null) output = screenFramebuffer;

		void scenePass()
		{
			sceneFramebuffer.beginDraw;
			sceneFramebuffer.clear;
			scope(exit) sceneFramebuffer.endDraw;

			openGL_.depthTest.push(true);
			scope(exit) openGL_.depthTest.pop;

			auto state = PipelineDrawState.scene;
			PipelineStatics stats;
			LocalContext context = LocalContext(camera, Matrix4f.identity, state);

			foreach(IDrawable drawable; physicalQueue)
				drawable.draw(this, context, stats);
		}

		void lightPass()
		{
			lightFramebuffer.beginDraw;
			lightFramebuffer.setClearColor();
			lightFramebuffer.clear;
			scope(exit) {
				lightFramebuffer.setClearColor;
				lightFramebuffer.endDraw;
			}

			import derelict.opengl3.gl3 : GL_ONE, GL_FUNC_ADD;
			openGL_.blend.push(true);
			openGL_.blendEquation.push(GL_FUNC_ADD);
			openGL_.blendFunc.push(tuple(GL_ONE, GL_ONE));
			scope(exit) openGL_.blend.pop;
			scope(exit) openGL_.blendEquation.pop;
			scope(exit) openGL_.blendFunc.pop;

			foreach(light; directionalLights)
				common.directionalLight.draw(outputOrtho.projection, sceneFramebuffer, lightFramebuffer, light);
			foreach(light; pointLights)
				common.pointLight.draw(outputOrtho.projection, sceneFramebuffer, lightFramebuffer, light);
		}

		scenePass;
		lightPass;

		outputOrtho.width = output.width;
		outputOrtho.height = output.height;
		outputOrtho.deduceOrtho;
		outputOrtho.buildProjection;
		//common.passThrough.draw(outputOrtho.projection, sceneFramebuffer, output);
		common.lightCombinator.draw(outputOrtho.projection, sceneFramebuffer, lightFramebuffer, fogFramebuffer);
	
		void fogPass()
		{
			fog.view = camera.viewMatrix;
			fog.draw(outputOrtho.projection, sceneFramebuffer, fogFramebuffer, output);
		}
		fogPass;
	}

	private void windowFramebufferResize(Window win, Vector2i size) @trusted
	{
		screenFramebuffer.update(size.x, size.y);
		sceneDepthBuffer.update(size.x, size.y);
		sceneFramebuffer.update(size.x, size.y);
		lightFramebuffer.update(size.x, size.y);
		fogFramebuffer.update(size.x, size.y);
	}
}

package final class PipelineCommon
{		
	private PassThrough passThrough;
	private LightCombinator lightCombinator;
	private DirectionalLightRenderer directionalLight;
	private PointLightRenderer pointLight;
	private uint quadVbo, quadVao;

	this(Moxane moxane) @trusted
	{
		passThrough = new PassThrough(moxane, this);
		lightCombinator = new LightCombinator(moxane, this);
		directionalLight = new DirectionalLightRenderer(moxane, this);
		pointLight = new PointLightRenderer(moxane, this);

		import derelict.opengl3.gl3;
		glGenVertexArrays(1, &quadVao);
		glGenBuffers(1, &quadVbo);
		glBindBuffer(GL_ARRAY_BUFFER, quadVbo);
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

	~this() @trusted
	{
		import derelict.opengl3.gl3;
		glDeleteBuffers(1, &quadVbo);
		glDeleteVertexArrays(1, &quadVao);
		destroy(passThrough);
	}
}

private final class PassThrough
{
	PipelineCommon common;

	private Effect effect;

	this(Moxane moxane, PipelineCommon common) @trusted
	{
		this.common = common;
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
		effect.findUniform("Diffuse");
		effect.findUniform("MVP");
		effect.unbind;
	}

	~this() @trusted
	{
		destroy(effect);
	}

	void draw(ref Matrix4f mvp, IFramebuffer input, IFramebuffer output) @trusted
	{
		import derelict.opengl3.gl3;

		glBindVertexArray(common.quadVao);
		scope(exit) glBindVertexArray(0);

		glEnableVertexAttribArray(0);
		scope(exit) glDisableVertexAttribArray(0);

		effect.bind;
		scope(exit) effect.unbind;

		input.read([GL_TEXTURE0]);
		scope(exit) input.endRead([GL_TEXTURE0]);
		effect["Diffuse"].set(cast(int)0);
		effect["Size"].set(Vector2f(output.width, output.height));
		effect["MVP"].set(&mvp);

		output.beginDraw;
		output.clear;
		scope(exit) output.endDraw;

		glBindBuffer(GL_ARRAY_BUFFER, common.quadVbo);
		scope(exit) glBindBuffer(GL_ARRAY_BUFFER, 0);
		glVertexAttribPointer(0, 2, GL_FLOAT, false, 0, null);

		glDrawArrays(GL_TRIANGLES, 0, 6);
	}

	private enum fsCode = "
#version 410 core

layout(location = 0) out vec4 Fragment;

uniform vec2 Size;
uniform sampler2D Diffuse;

void main()
{
	Fragment = texture(Diffuse, gl_FragCoord.xy / Size);
}";
}

private final class LightCombinator
{
	PipelineCommon common;

	private Effect effect;

	this(Moxane moxane, PipelineCommon common) @trusted
	{
		this.common = common;
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
		effect.findUniform("SceneDiffuse");
		effect.findUniform("SceneNormal");
		effect.findUniform("MVP");
		effect.findUniform("LightMap");
		effect.unbind;
	}

	~this() @trusted
	{
		destroy(effect);
	}

	void draw(ref Matrix4f mvp, IFramebuffer scene, IFramebuffer light, IFramebuffer output) @trusted
	{
		import derelict.opengl3.gl3;

		glBindVertexArray(common.quadVao);
		scope(exit) glBindVertexArray(0);

		glEnableVertexAttribArray(0);
		scope(exit) glDisableVertexAttribArray(0);

		effect.bind;
		scope(exit) effect.unbind;

		scene.read([GL_TEXTURE0, GL_TEXTURE1, GL_TEXTURE2]);
		scope(exit) scene.endRead([GL_TEXTURE0, GL_TEXTURE1, GL_TEXTURE2]);

		light.read([GL_TEXTURE3]);
		scope(exit) light.endRead([GL_TEXTURE3]);
		effect["SceneDiffuse"].set(0);
		effect["SceneNormal"].set(2);
		effect["LightMap"].set(3);
		effect["Size"].set(Vector2f(output.width, output.height));
		effect["MVP"].set(&mvp);

		output.beginDraw;
		output.clear;
		scope(exit) output.endDraw;

		glBindBuffer(GL_ARRAY_BUFFER, common.quadVbo);
		scope(exit) glBindBuffer(GL_ARRAY_BUFFER, 0);

		glVertexAttribPointer(0, 2, GL_FLOAT, false, 0, null);

		glDrawArrays(GL_TRIANGLES, 0, 6);
	}

	private enum fsCode = "
		#version 410 core

		layout(location = 0) out vec4 Fragment;

		uniform sampler2D SceneDiffuse;
		uniform sampler2D SceneNormal;
		uniform sampler2D LightMap;
		uniform vec2 Size;

		void main()
		{
			vec2 textureCoord = gl_FragCoord.xy / Size;
			vec3 light = texture(LightMap, textureCoord).rgb;
			vec4 diffuse = texture(SceneDiffuse, textureCoord);
			vec3 normal = texture(SceneNormal, textureCoord).rgb;
			Fragment.a = diffuse.a;
			if(normal == vec3(0, 0, 0))
				Fragment.rgb = diffuse.rgb;
			else
				Fragment.rgb = light.rgb * diffuse.rgb;
		}";
}

private final class DirectionalLightRenderer
{
	PipelineCommon common;

	private Effect effect;

	this(Moxane moxane, PipelineCommon common) @trusted
	{
		this.common = common;
		import derelict.opengl3.gl3;

		Log log = moxane.services.getAOrB!(GraphicsLog, Log)();
		assert(log !is null);

		Shader fs = new Shader, vs = new Shader;
		vs.compile(vsCode, GL_VERTEX_SHADER, log);
		fs.compile(fsCode, GL_FRAGMENT_SHADER, log);
		effect = new Effect(moxane, typeof(this).stringof);
		effect.attachAndLink(vs, fs);
		effect.bind;
		effect.findUniform("LightDirection");
		effect.findUniform("LightColour");
		effect.findUniform("AmbientIntensity");
		effect.findUniform("DiffuseIntensity");
		effect.findUniform("Size");
		effect.findUniform("MVP");
		effect.findUniform("WorldPositionTexture");
		effect.findUniform("NormalTexture");
		effect.findUniform("DepthTexture");
		effect.findUniform("SpecularTexture");
		effect.unbind;
	}

	~this() @trusted
	{
		destroy(effect);
	}

	void draw(ref Matrix4f mvp, IFramebuffer scene, IFramebuffer light, DirectionalLight dl) @trusted
	{
		import derelict.opengl3.gl3;

		glBindVertexArray(common.quadVao);
		scope(exit) glBindVertexArray(0);

		glEnableVertexAttribArray(0);
		scope(exit) glDisableVertexAttribArray(0);

		effect.bind;
		scope(exit) effect.unbind;

		scene.read([GL_TEXTURE0, GL_TEXTURE1, GL_TEXTURE2, GL_TEXTURE3]);
		scope(exit) scene.endRead([GL_TEXTURE0, GL_TEXTURE1, GL_TEXTURE2, GL_TEXTURE3]);

		scene.depthTexture.read([GL_TEXTURE4]);
		scope(exit) scene.depthTexture.endRead([GL_TEXTURE4]);

		effect["WorldPositionTexture"].set(1);
		effect["NormalTexture"].set(2);
		effect["DepthTexture"].set(4);
		effect["SpecularTexture"].set(3);

		effect["LightDirection"].set(dl.direction);
		effect["LightColour"].set(dl.colour);
		effect["AmbientIntensity"].set(dl.ambientIntensity);
		effect["DiffuseIntensity"].set(dl.diffuseIntensity);
		effect["Size"].set(Vector2f(light.width, light.height));
		effect["MVP"].set(&mvp);

		light.beginDraw;
		scope(exit) light.endDraw;

		glBindBuffer(GL_ARRAY_BUFFER, common.quadVbo);
		scope(exit) glBindBuffer(GL_ARRAY_BUFFER, 0);

		glVertexAttribPointer(0, 2, GL_FLOAT, false, 0, null);

		glDrawArrays(GL_TRIANGLES, 0, 6);
	}

	private enum fsCode = "
		#version 410 core

		layout(location = 0) out vec4 LightMapOut;

		uniform vec3 LightDirection;
		uniform vec3 LightColour;
		uniform float AmbientIntensity;
		uniform float DiffuseIntensity;

		uniform vec2 Size;

		uniform sampler2D WorldPositionTexture;
		uniform sampler2D NormalTexture;
		uniform sampler2D DepthTexture;
		uniform sampler2D SpecularTexture;
		
		void main()
		{
			vec2 texCoord = gl_FragCoord.xy / Size;
			vec3 worldPosition = texture(WorldPositionTexture, texCoord).rgb;
			vec3 normal = texture(NormalTexture, texCoord).rgb;
			vec2 spec = texture(SpecularTexture, texCoord).rg;

			vec4 ambientColour = vec4(LightColour * AmbientIntensity, 1.0);
			float diffuseFactor = dot(normal, LightDirection);

			vec4 diffuseColour = vec4(0.0);
			vec4 specularColour = vec4(0.0);

			if(diffuseFactor > 0.0) {
				diffuseColour = vec4(LightColour * DiffuseIntensity * diffuseFactor, 1.0);
			}

			LightMapOut.rgb = ambientColour.xyz + diffuseColour.xyz;
			LightMapOut.a = 1f;
		}";
}

private final class PointLightRenderer
{
	PipelineCommon common;

	private Effect effect;

	this(Moxane moxane, PipelineCommon common) @trusted
	{
		this.common = common;
		import derelict.opengl3.gl3;

		Log log = moxane.services.getAOrB!(GraphicsLog, Log)();
		assert(log !is null);

		Shader fs = new Shader, vs = new Shader;
		vs.compile(vsCode, GL_VERTEX_SHADER, log);
		fs.compile(fsCode, GL_FRAGMENT_SHADER, log);
		effect = new Effect(moxane, typeof(this).stringof);
		effect.attachAndLink(vs, fs);
		effect.bind;
		effect.findUniform("LightPosition");
		effect.findUniform("LightColour");
		effect.findUniform("AmbientIntensity");
		effect.findUniform("DiffuseIntensity");
		effect.findUniform("Attenuation");
		effect.findUniform("Size");
		effect.findUniform("CameraPosition");
		effect.findUniform("MVP");
		effect.findUniform("WorldPositionTexture");
		effect.findUniform("NormalTexture");
		effect.findUniform("DepthTexture");
		effect.findUniform("SpecularTexture");
		effect.unbind;
	}

	~this() @trusted
	{
		destroy(effect);
	}

	void draw(ref Matrix4f mvp, IFramebuffer scene, IFramebuffer light, PointLight pl) @trusted
	{
		import derelict.opengl3.gl3;

		glBindVertexArray(common.quadVao);
		scope(exit) glBindVertexArray(0);

		glEnableVertexAttribArray(0);
		scope(exit) glDisableVertexAttribArray(0);

		effect.bind;
		scope(exit) effect.unbind;

		scene.read([GL_TEXTURE0, GL_TEXTURE1, GL_TEXTURE2, GL_TEXTURE3]);
		scope(exit) scene.endRead([GL_TEXTURE0, GL_TEXTURE1, GL_TEXTURE2, GL_TEXTURE3]);

		scene.depthTexture.read([GL_TEXTURE4]);
		scope(exit) scene.depthTexture.endRead([GL_TEXTURE4]);

		effect["WorldPositionTexture"].set(1);
		effect["NormalTexture"].set(2);
		effect["DepthTexture"].set(4);
		effect["SpecularTexture"].set(3);

		effect["LightPosition"].set(pl.position);
		effect["LightColour"].set(pl.colour);
		effect["AmbientIntensity"].set(pl.ambientIntensity);
		effect["DiffuseIntensity"].set(pl.diffuseIntensity);
		effect["Attenuation"].set(Vector3f(pl.constAtt, pl.linAtt, pl.expAtt));
		effect["Size"].set(Vector2f(light.width, light.height));
		effect["MVP"].set(&mvp);

		light.beginDraw;
		scope(exit) light.endDraw;

		glBindBuffer(GL_ARRAY_BUFFER, common.quadVbo);
		scope(exit) glBindBuffer(GL_ARRAY_BUFFER, 0);

		glVertexAttribPointer(0, 2, GL_FLOAT, false, 0, null);

		glDrawArrays(GL_TRIANGLES, 0, 6);
	}

	private enum fsCode = "
		#version 410 core

		layout(location = 0) out vec4 LightMapOut;

		uniform vec3 LightPosition;
		uniform vec3 LightColour;
		uniform float AmbientIntensity;
		uniform float DiffuseIntensity;
		uniform vec3 Attenuation;

		uniform vec2 Size;

		uniform sampler2D WorldPositionTexture;
		uniform sampler2D NormalTexture;
		uniform sampler2D DepthTexture;
		uniform sampler2D SpecularTexture;

		void main()
		{
			vec2 texCoord = gl_FragCoord.xy / Size;
			vec3 worldPosition = texture(WorldPositionTexture, texCoord).rgb;
			vec3 normal = texture(NormalTexture, texCoord).rgb;
			vec2 spec = texture(SpecularTexture, texCoord).rg;

			vec3 lightDirection = worldPosition - LightPosition;
			float lightDirDistance = length(lightDirection);
			lightDirection = normalize(lightDirection);

			vec4 ambientColour = vec4(LightColour * AmbientIntensity, 1.0);
			float diffuseFactor = dot(normal, -lightDirection);

			vec4 diffuseColour = vec4(0.0);
			vec4 specularColour = vec4(0.0);

			if(diffuseFactor > 0.0) {
				diffuseColour = vec4(LightColour * DiffuseIntensity * diffuseFactor, 1.0);
			}

			vec3 unattenuatedLight = ambientColour.xyz + diffuseColour.xyz;
			float attenuation = Attenuation.x + Attenuation.y * lightDirDistance + Attenuation.z * lightDirDistance * lightDirDistance;
			attenuation = max(1.0, attenuation);

			LightMapOut.rgb = (ambientColour.rgb + diffuseColour.rgb) / attenuation;
			LightMapOut.a = 1f;
		}";
}

abstract class PostProcess
{
	package PipelineCommon common;

	protected Effect effect;

	this(Moxane moxane, PipelineCommon common, string fsCode, string name) @trusted
	{
		this.common = common;
		import derelict.opengl3.gl3;

		Log log = moxane.services.getAOrB!(GraphicsLog, Log)();
		assert(log !is null);

		Shader fs = new Shader, vs = new Shader;
		vs.compile(vsCode, GL_VERTEX_SHADER, log);
		fs.compile(fsCode, GL_FRAGMENT_SHADER, log);
		effect = new Effect(moxane, name);
		effect.attachAndLink(vs, fs);
		effect.bind;
		effect.findUniform("Size");
		effect.findUniform("DiffuseTexture");
		effect.findUniform("DepthTexture");
		effect.findUniform("WorldPosTexture");
		effect.findUniform("NormalTexture");
		effect.findUniform("SpecTexture");
		effect.findUniform("StageDiffuseTexture");
		effect.findUniform("MVP");
		effect.unbind;
	}

	~this() @trusted
	{
		destroy(effect);
	}

	abstract void beginDraw();
	abstract void endDraw();

	void draw(ref Matrix4f mvp, IFramebuffer scene, IFramebuffer stage, IFramebuffer output) @trusted
	{
		import derelict.opengl3.gl3;

		glBindVertexArray(common.quadVao);
		scope(exit) glBindVertexArray(0);

		glEnableVertexAttribArray(0);
		scope(exit) glDisableVertexAttribArray(0);

		effect.bind;
		scope(exit) effect.unbind;

		scene.read([GL_TEXTURE0, GL_TEXTURE1, GL_TEXTURE2, GL_TEXTURE3]);
		scope(exit) scene.endRead([GL_TEXTURE0, GL_TEXTURE1, GL_TEXTURE2, GL_TEXTURE3]);
		stage.read([GL_TEXTURE4]);
		scope(exit) stage.endRead([GL_TEXTURE4]);
		scene.depthTexture.read([GL_TEXTURE5]);
		scope(exit) scene.depthTexture.endRead([GL_TEXTURE5]);

		effect["DiffuseTexture"].set(cast(int)0);
		effect["WorldPosTexture"].set(cast(int)1);
		effect["NormalTexture"].set(cast(int)2);
		effect["SpecTexture"].set(cast(int)3);
		effect["StageDiffuseTexture"].set(cast(int)4);
		effect["DepthTexture"].set(cast(int)5);
		effect["Size"].set(Vector2f(output.width, output.height));
		effect["MVP"].set(&mvp);

		output.beginDraw;
		output.clear;
		scope(exit) output.endDraw;

		glBindBuffer(GL_ARRAY_BUFFER, common.quadVbo);
		scope(exit) glBindBuffer(GL_ARRAY_BUFFER, 0);
		glVertexAttribPointer(0, 2, GL_FLOAT, false, 0, null);

		beginDraw;
		scope(exit) endDraw;

		glDrawArrays(GL_TRIANGLES, 0, 6);
	}

	enum fsHeader = "
		#version 410 core

		layout(location = 0) out vec4 Fragment;

		uniform sampler2D DiffuseTexture, WorldPosTexture, NormalTexture, SpecTexture, StageDiffuseTexture, DepthTexture;
		uniform vec2 Size;
		";
}

class FogPostProcess : PostProcess
{
	Matrix4f view;
	Vector3f colour;

	this(Moxane moxane, PipelineCommon common) @trusted
	{
		super(moxane, common, fs, typeof(this).stringof);
		effect.bind;
		effect.findUniform("Colour");
		effect.findUniform("Gradient");
		effect.findUniform("Density");
		effect.findUniform("View");
		effect.unbind;
	}

	override void beginDraw() @trusted
	{
		effect["Colour"].set(colour);
		effect["Gradient"].set(2.819f);
		effect["Density"].set(0.022892f);
		effect["View"].set(&view);
	}

	override void endDraw() @trusted {}

	enum fs = fsHeader ~ "
		uniform vec3 Colour;
		uniform float Gradient;
		uniform float Density;

		uniform mat4 View;

		void main()
		{
			vec2 texCoord = gl_FragCoord.xy / Size;
			vec3 diffuseStage = texture(StageDiffuseTexture, texCoord).rgb;
			vec3 worldPos = texture(WorldPosTexture, texCoord).rgb;
			vec3 normal = texture(NormalTexture, texCoord).rgb;

			vec3 mvPos = (View * vec4(worldPos, 1)).xyz;
			float dist = length(mvPos);
			float fogFactor = clamp(exp(-pow(dist * Density, Gradient)), 0, 1);
			
			if(normal == vec3(0, 0, 0)) Fragment = vec4(diffuseStage, 1);
			else Fragment = vec4(mix(Colour, diffuseStage, fogFactor), 1);
		}
		";
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