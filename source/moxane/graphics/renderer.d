module moxane.graphics.renderer;

import moxane.core.engine;
import moxane.core.eventwaiter;
import moxane.core.log;

import moxane.graphics.gl;
import moxane.graphics.log;
import moxane.graphics.rendertexture;

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

	float fieldOfView;
	float near, far;
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
		projection = perspectiveMatrix(fieldOfView, cast(float)height / cast(float)width, near, far);
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

	RenderTexture scene;
	DepthTexture sceneDepth;

	private IRenderable[] sceneRenderables;

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

		gl = new GLState(moxane, debugMode);

		primaryCamera = new Camera;
		primaryCamera.width = winSize.x;
		primaryCamera.height = winSize.y;

		scene = new RenderTexture(winSize.x, winSize.y, gl);

		//sceneDepth = new DepthTexture(winSize.x, winSize.y, gl);
		//scene.bindDepth(sceneDepth);
	}

	void scenePass()
	{
		//scene.bindDepth(sceneDepth);
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