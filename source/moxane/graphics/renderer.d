module moxane.graphics.renderer;

import moxane.core.engine;
import moxane.core.eventwaiter;
import moxane.core.log;
import moxane.core.asset;

import moxane.graphics.gl;
import moxane.graphics.log;
import moxane.graphics.rendertexture;
import moxane.graphics.effect;
import moxane.graphics.triangletest;
import moxane.graphics.postprocess;
import moxane.graphics.light;

import moxane.graphics.imgui;
import cimgui.funcs;
import cimgui.types;

import std.algorithm.mutation;
import dlib.math;
import std.math : floor;

// NOTICE: NO OPENGL CALLS WITHIN THIS MODULE
// OpenGL calls slow down the parser. Use wrapped calls or abstracted objects ONLY.
// This is a high activity module.

@safe class Camera
{
	Vector3f position;
	Vector3f rotation;
	Matrix4f viewMatrix;

	struct Ortho
	{
		float left, right, top, bottom, near, far;
	}
	struct Perspective
	{
		float fieldOfView, near, far;
	}
	union
	{
		Ortho ortho;
		Perspective perspective;
	}
	bool isOrtho;
	Matrix4f projection;

	uint width, height;

	void buildView()
	{
		viewMatrix = translationMatrix(-position);
		viewMatrix = rotationMatrix(Axis.z, degtorad(-rotation.z)) * viewMatrix;
		viewMatrix = rotationMatrix(Axis.y, degtorad(-rotation.y)) * viewMatrix;
		viewMatrix = rotationMatrix(Axis.x, degtorad(-rotation.x)) * viewMatrix;
	}

	void deduceOrtho()
	{
		ortho.left = 0f;
		ortho.right = cast(float)width;
		ortho.bottom = cast(float)height;
		ortho.top = 0f;
	}

	void buildProjection()
	{
		if(isOrtho)
			projection = orthoMatrix(ortho.left, ortho.right, ortho.bottom, ortho.top, ortho.near, ortho.far);
		else
			projection = perspectiveMatrix(perspective.fieldOfView, cast(float)width / cast(float)height, perspective.near, perspective.far);
	}
}

enum PassType
{
	shadow,
	water,
	scene,
	ui,
	glass,
}

struct LocalContext
{
	Matrix4f projection;
	Matrix4f view;
	Matrix4f model; /// user use
	Camera camera;
	PassType type;
}

interface IRenderable
{
	void render(Renderer, ref LocalContext, out uint drawCalls, out uint numVerts);
}

enum RendererHookPass
{
	beginningGlobal,
	endGlobal
}

struct RendererHook
{
	Renderer renderer;
	RendererHookPass pass;
}

class Renderer 
{
	Moxane moxane;
	GLState gl;

	Camera primaryCamera;
	Camera uiCamera;

	bool wireframe;
	RenderTexture scene;
	DepthTexture sceneDepth;

	RenderTexture sceneDup;
	DepthTexture sceneDepthDup;

	RenderTexture sunDirMap;
	DepthTexture sunDirMapDepth;

	LightDistributor lights;
	PostProcessDistributor postProcesses;

	private IRenderable[] sceneRenderables;
	IRenderable[] uiRenderables;

	Log log;

	string rendererName, vendor, glVersion, glslVersion;

	private struct DebugData
	{
		uint wrDrawCalls, wrNumVerts;
		uint sceneDrawCalls, sceneNumVerts;
		uint shadowDrawCalls, shadowNumVerts;
		uint uiDrawCalls, uiNumVerts;
	}

	DebugData lastFrameDebug;
	DebugData currentFrameDebug;

	EventWaiter!RendererHook passHook;

	this(Moxane moxane, Vector2u winSize, bool debugMode = false)
	{
		this.moxane = moxane;
		if(debugMode)
		{
			GraphicsLog log = new GraphicsLog;
			moxane.services.register!GraphicsLog(log);
		}

		log = moxane.services.getAOrB!(GraphicsLog, Log);

		AssetManager am = moxane.services.get!AssetManager;
		am.registerLoader!Shader(new ShaderLoader);

		gl = new GLState(moxane, debugMode);
		rendererName = gl.rendererName;
		vendor = gl.vendorName;
		glVersion = gl.versionStr;
		glslVersion = gl.glslVersion;

		primaryCamera = new Camera;
		primaryCamera.width = winSize.x;
		primaryCamera.height = winSize.y;
		
		uiCamera = new Camera;
		uiCamera.width = winSize.x;
		uiCamera.height = winSize.y;
		uiCamera.deduceOrtho;
		uiCamera.ortho.near = -1f;
		uiCamera.ortho.far = 1f;
		uiCamera.isOrtho = true;
		uiCamera.buildProjection;

		sceneDepth = new DepthTexture(winSize.x, winSize.y, gl);
		scene = new RenderTexture(winSize.x, winSize.y, sceneDepth, gl);

		sceneDepthDup = new DepthTexture(winSize.x, winSize.y, gl);
		sceneDup = new RenderTexture(winSize.x, winSize.y, sceneDepthDup, gl);

		postProcesses = new PostProcessDistributor(winSize.x, winSize.y, moxane);
		lights = new LightDistributor(moxane, postProcesses.common, winSize.x, winSize.y);
	
		enum dirMapSize = 1024;
		sunDirMapDepth = new DepthTexture(dirMapSize, dirMapSize, gl);
		sunDirMap = new RenderTexture(dirMapSize, dirMapSize, sunDirMapDepth, gl);
	}

	void scenePass()
	{
		scene.bindDraw;
		scene.clear;
		scope(exit) 
			scene.unbindDraw;

		gl.depthTest.push(true);
		scope(exit) gl.depthTest.pop();

		if(wireframe)
			gl.wireframe = true;
		scope(exit)
			gl.wireframe = false;

		LocalContext lc = 
		{
			projection : primaryCamera.projection, 
			view : primaryCamera.viewMatrix, 
			model : Matrix4f.identity, 
			camera : primaryCamera,
			type : PassType.scene
		};
		scope(exit) lc.destroy;

		foreach(IRenderable r; sceneRenderables)
		{
			uint drawCalls, numVerts;
			r.render(this, lc, drawCalls, numVerts);
			currentFrameDebug.sceneDrawCalls += drawCalls;
			currentFrameDebug.sceneNumVerts += numVerts;
		}
	}

	void waterPass()
	{
		scene.bindDraw;
		scope(exit) 
			scene.unbindDraw;

		gl.depthTest.push(true);
		scope(exit) gl.depthTest.pop();

		if(wireframe)
			gl.wireframe = true;
		scope(exit)
			gl.wireframe = false;

		LocalContext lc = 
		{
			projection : primaryCamera.projection, 
			view : primaryCamera.viewMatrix, 
			model : Matrix4f.identity, 
			camera : primaryCamera,
			type : PassType.water
		};
		scope(exit) lc.destroy;

		foreach(IRenderable r; sceneRenderables)
		{
			uint drawCalls, numVerts;
			r.render(this, lc, drawCalls, numVerts);
			currentFrameDebug.sceneDrawCalls += drawCalls;
			currentFrameDebug.sceneNumVerts += numVerts;
		}
	}

	void glassPass()
	{
		scene.bindDraw;
		scope(exit) 
			scene.unbindDraw;

		gl.depthTest.push(true);
		scope(exit) gl.depthTest.pop();

		if(wireframe)
			gl.wireframe = true;
		scope(exit)
			gl.wireframe = false;

		LocalContext lc = 
		{
			projection : primaryCamera.projection, 
			view : primaryCamera.viewMatrix, 
			model : Matrix4f.identity, 
			camera : primaryCamera,
			type : PassType.glass
		};
		scope(exit) lc.destroy;

		foreach(IRenderable r; sceneRenderables)
		{
			uint drawCalls, numVerts;
			r.render(this, lc, drawCalls, numVerts);
			currentFrameDebug.sceneDrawCalls += drawCalls;
			currentFrameDebug.sceneNumVerts += numVerts;
		}
	}

	void shadowPass()
	{
		sunDirMap.bindDraw;
		sunDirMap.clear;
		scope(exit) 
			scene.unbindDraw;

		gl.depthTest.push(true);
		scope(exit) gl.depthTest.pop();

		gl.wireframe = false;

		Matrix4f proj = orthoMatrix!float(-10, 10, -10, 10, -10, 10);
		immutable lightDir = Vector3f(0, 0.5f, 0.5f);
		//Matrix4f view = lookAtMatrix!float(Vector3f(20, 0, 0), Vector3f(20, 0, 0) - lightDir, Vector3f(0, 1, 0));
		// ^^^ works

		Vector3f eye = Vector3f(floor(primaryCamera.position.x), floor(primaryCamera.position.y), floor(primaryCamera.position.z));
		Matrix4f view = lookAtMatrix!float(eye, eye - lightDir*0.1f, Vector3f(0, 1, 0));
		lights.lpv = proj * view;

		LocalContext lc = 
		{
			projection : proj, 
			view : view, 
			model : Matrix4f.identity, 
			camera : primaryCamera,
			type : PassType.shadow
		};
		scope(exit) lc.destroy;

		foreach(IRenderable r; sceneRenderables)
		{
			uint drawCalls, numVerts;
			r.render(this, lc, drawCalls, numVerts);
			currentFrameDebug.shadowDrawCalls += drawCalls;
			currentFrameDebug.shadowNumVerts += numVerts;
		}
	}

	void render()
	{
		lastFrameDebug = currentFrameDebug;
		currentFrameDebug = DebugData();

		RendererHook hook;
		hook.renderer = this;
		hook.pass = RendererHookPass.beginningGlobal;
		passHook.emit(hook);

		scope(success)
		{
			hook.pass = RendererHookPass.endGlobal;
			passHook.emit(hook);
		}

		import derelict.opengl3.gl3;
		glBindFramebuffer(GL_FRAMEBUFFER, 0);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

		shadowPass;

		scenePass;
		sceneDup.bindDraw;
		sceneDup.clear;
		sceneDup.unbindDraw;
		scene.blitTo(sceneDup);
		waterPass;

		LocalContext uilc = 
		{
			projection : uiCamera.projection, 
			view : Matrix4f.identity, 
			model : Matrix4f.identity, 
			camera : uiCamera,
			type : PassType.scene
		};
		lights.shadow = sunDirMap;
		lights.render(this, uilc, scene, postProcesses.lightTexture, primaryCamera.position);

		//postProcesses.lightTexture.blitTo(scene);
		//sceneDup.bindDraw;
		//sceneDup.clear;
		//sceneDup.unbindDraw;
		//scene.blitTo(sceneDup);
		//glassPass;

		postProcesses.render(this, uilc);

		debug sunDirMap.blitToScreen(0, 0, uiCamera.width, uiCamera.height);

		{
			import derelict.opengl3.gl3 : glViewport;
			glViewport(0, 0, uiCamera.width, uiCamera.height);
			
			foreach(IRenderable r; uiRenderables) 
			{
				uint dc, nv;
				r.render(this, uilc, dc, nv);
				currentFrameDebug.uiDrawCalls += dc;
				currentFrameDebug.uiNumVerts += nv;
			}
		}
	}

	void cameraUpdated()
	{
		if(scene.width != primaryCamera.width || scene.height != primaryCamera.height)
		{
			scene.width = primaryCamera.width;
			scene.height = primaryCamera.height;
			scene.createTextures;

			sceneDepth.width = primaryCamera.width;
			sceneDepth.height = primaryCamera.height;
			sceneDepth.createTextures;

			sceneDup.width = primaryCamera.width;
			sceneDup.height = primaryCamera.height;
			sceneDup.createTextures;

			sceneDepthDup.width = primaryCamera.width;
			sceneDepthDup.height = primaryCamera.height;
			sceneDepthDup.createTextures;
			
			postProcesses.updateFramebufferSize(primaryCamera.width, primaryCamera.height);
			lights.updateFramebufferSize(primaryCamera.width, primaryCamera.height);
		}
	}

	void addSceneRenderable(IRenderable renderable)
	{ sceneRenderables ~= renderable; }

	void removeSceneRenderable(IRenderable renderable)
	{
		bool found = false;
		size_t index;
		foreach(size_t i, IRenderable r; sceneRenderables)
		{
			if(r == renderable)
			{
				found = true;
				index = i;
				break;
			}
		}
		if(!found) throw new Exception("Item not found.");
		sceneRenderables.remove(index);
	}
}

class RendererDebugAttachment : IImguiRenderable
{
	Renderer renderer;

	this(Renderer renderer)
	{
		this.renderer = renderer;
	}

	void renderUI(ImguiRenderer imgui, Renderer renderer, ref LocalContext lc)
	{
		import std.conv : to;
		import std.string : toStringz;
		igBegin("Renderer Statistics");
		if(igCollapsingHeader("Basic", ImGuiTreeNodeFlags_DefaultOpen))
		{
			igText("Delta: %0.6f s", renderer.moxane.deltaTime);
			igText("Frames: %u", renderer.moxane.frames);

			igText("Renderer: %s", renderer.rendererName.toStringz);
			igText("Vendor: %s", renderer.vendor.toStringz);
			igText("Version: %s", renderer.glVersion.toStringz);
			igText("GLSL version: %s", renderer.glslVersion.toStringz);

			igText("Scene");
			igIndent();
			igText("Draw calls: %u Vertices: %u", renderer.lastFrameDebug.sceneDrawCalls, renderer.lastFrameDebug.sceneNumVerts);
			igUnindent();

			igText("UI");
			igIndent();
			igText("Draw calls: %u Vertices: %u", renderer.lastFrameDebug.uiDrawCalls, renderer.lastFrameDebug.uiNumVerts);
			igUnindent();

			igText("Shadow");
			igIndent();
			igText("Draw calls: %u Vertices: %u", renderer.lastFrameDebug.shadowDrawCalls, renderer.lastFrameDebug.shadowNumVerts);
			igUnindent();
		}
		igEnd();
	}
}