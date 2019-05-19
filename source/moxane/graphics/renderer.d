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

import std.algorithm.mutation;
import dlib.math;

// NOTICE: NO OPENGL CALLS WITHIN THIS MODULE
// OpenGL calls slow down the parser. Use wrapped calls or abstracted objects ONLY.
// This is a high activity module.

class Camera
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
		viewMatrix *= rotationMatrix(Axis.x, degtorad(rotation.x));
		viewMatrix *= rotationMatrix(Axis.y, degtorad(rotation.y));
		viewMatrix *= rotationMatrix(Axis.z, degtorad(rotation.z));
	}

	void buildProjection()
	{
		if(isOrtho)
			projection = orthoMatrix(ortho.left, ortho.right, ortho.bottom, ortho.top, ortho.near, ortho.far);
		else
			projection = perspectiveMatrix(perspective.fieldOfView, cast(float)height / cast(float)width, perspective.near, perspective.far);
	}
}

enum PassType
{
	shadow,
	scene
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
	void render(Renderer, ref LocalContext);
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
		uiCamera.ortho.left = 0f;
		uiCamera.ortho.right = cast(float)winSize.x;
		uiCamera.ortho.bottom = cast(float)winSize.y;
		uiCamera.ortho.top = 0f;
		uiCamera.ortho.near = -1f;
		uiCamera.ortho.far = 1f;
		uiCamera.isOrtho = true;
		uiCamera.buildProjection;

		sceneDepth = new DepthTexture(winSize.x, winSize.y, gl);
		scene = new RenderTexture(winSize.x, winSize.y, sceneDepth, gl);

		tt = new TriangleTest(moxane);
		sceneRenderables ~= tt;
	}

	void scenePass()
	{
		scene.bindDraw;
		scene.clear;
		scope(exit) 
		{
			scene.unbindDraw;
		}

		LocalContext lc = 
		{
			projection : primaryCamera.projection, 
			view : primaryCamera.viewMatrix, 
			model : Matrix4f.identity, 
			camera : primaryCamera,
			type : PassType.scene
		};

		foreach(IRenderable r; sceneRenderables)
		{
			r.render(this, lc);
		}
	}

	void render()
	{
		//if(scene is null) cameraUpdated;

		scenePass;
		scene.blitToScreen(0, 0, primaryCamera.width, primaryCamera.height);

		LocalContext uilc = 
		{
			projection : uiCamera.projection, 
			view : Matrix4f.identity, 
			model : Matrix4f.identity, 
			camera : uiCamera,
			type : PassType.scene
		};

		foreach(IRenderable r; uiRenderables)
			r.render(this, uilc);
	}

	void cameraUpdated()
	{
		scene.width = primaryCamera.width;
		scene.height = primaryCamera.height;
		scene.createTextures;

		sceneDepth.width = primaryCamera.width;
		sceneDepth.height = primaryCamera.height;
		sceneDepth.createTextures;
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