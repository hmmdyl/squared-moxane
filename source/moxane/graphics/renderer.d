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

import moxane.graphics.imgui;
import cimgui.funcs;
import cimgui.types;

import std.algorithm.mutation;
import dlib.math;

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
		//viewMatrix = translationMatrix(-position);
		/*viewMatrix = rotationMatrix(Axis.z, degtorad(rotation.z));
		viewMatrix *= rotationMatrix(Axis.y, degtorad(rotation.y));
		viewMatrix *= rotationMatrix(Axis.x, degtorad(rotation.x));
		viewMatrix *= translationMatrix(-position);*/

		//viewMatrix = rotationMatrix(Axis.y, degtorad(rotation.y));
		//viewMatrix = translationMatrix(-position) * rotationMatrix(Axis.y, degtorad(rotation.y));
		//viewMatrix = rotationMatrix(Axis.y, degtorad(rotation.y)) * translationMatrix(-position);

		viewMatrix = translationMatrix(-position);
		viewMatrix = rotationMatrix(Axis.z, degtorad(-rotation.z)) * viewMatrix;
		viewMatrix = rotationMatrix(Axis.y, degtorad(-rotation.y)) * viewMatrix;
		viewMatrix = rotationMatrix(Axis.x, degtorad(-rotation.x)) * viewMatrix;

		//viewMatrix = Matrix4f.identity;
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
	scene,
	ui
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

class Renderer 
{
	Moxane moxane;
	GLState gl;

	Camera primaryCamera;
	Camera uiCamera;

	RenderTexture scene;
	DepthTexture sceneDepth;

	TriangleTest tt;

	private IRenderable[] sceneRenderables;
	IRenderable[] uiRenderables;

	Log log;

	private struct DebugData
	{
		uint sceneDrawCalls, sceneNumVerts;
		uint uiDrawCalls, uiNumVerts;
	}

	DebugData lastFrameDebug;
	DebugData currentFrameDebug;

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

		//tt = new TriangleTest(moxane);
		//sceneRenderables ~= tt;
	}

	void scenePass()
	{
		scene.bindDraw;
		scene.clear;
		scope(exit) 
			scene.unbindDraw;

		gl.depthTest.push(true);
		scope(exit) gl.depthTest.pop();

		LocalContext lc = 
		{
			projection : primaryCamera.projection, 
			view : primaryCamera.viewMatrix, 
			model : Matrix4f.identity, 
			camera : primaryCamera,
			type : PassType.ui
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

	void render()
	{
		lastFrameDebug = currentFrameDebug;
		currentFrameDebug = DebugData();

		import derelict.opengl3.gl3 : glViewport;
		glViewport(0, 0, primaryCamera.width, primaryCamera.height);
		scenePass;
		scene.blitToScreen(0, 0, uiCamera.width, uiCamera.height);

		{
			import derelict.opengl3.gl3 : glViewport;
			glViewport(0, 0, uiCamera.width, uiCamera.height);

			LocalContext uilc = 
			{
				projection : uiCamera.projection, 
				view : Matrix4f.identity, 
				model : Matrix4f.identity, 
				camera : uiCamera,
				type : PassType.scene
			};
			
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
		if(igCollapsingHeader("Basic", 0))
		{
			igText("Delta: %0.6f s", renderer.moxane.deltaTime);
			igText("Frames: %u", renderer.moxane.frames);

			igText("Scene");
			igIndent();
			igText("Draw calls: %u Vertices: %u", renderer.lastFrameDebug.sceneDrawCalls, renderer.lastFrameDebug.sceneNumVerts);
			igUnindent();

			igText("UI");
			igIndent();
			igText("Draw calls: %u Vertices: %u", renderer.lastFrameDebug.uiDrawCalls, renderer.lastFrameDebug.uiNumVerts);
			igUnindent();

			//char[1024] buf;
			//igInputTextMultiline("???????".toStringz, buf.ptr, 1024);
		}
		igEnd();
	}
}