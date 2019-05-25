import std.stdio;

import moxane.core.engine;
import moxane.core.log;
import moxane.graphics.renderer;
import moxane.io.window;
import moxane.core.asset;
import moxane.graphics.transformation;

import moxane.graphics.standard;

import dlib.math;

import std.datetime.stopwatch;

//extern(C) __gshared string[] rt_options = ["gcopt=gc:precise profile:1"];

void main()
{
	const MoxaneBootSettings settings = 
	{
		logSystem : true,
		windowSystem : true,
		graphicsSystem : true,
		assetSystem : true,
		physicsSystem : false,
		networkSystem : false,
		settingsSystem : false,
		asyncSystem : false
	};
	Moxane moxane = new Moxane(settings);
	
	Log log = moxane.services.get!Log;
	log.write(Log.Severity.debug_, "Hello");

	Window win = moxane.services.get!Window;
	Renderer r = moxane.services.get!Renderer;

	r.primaryCamera.perspective.fieldOfView = 90f;
	r.primaryCamera.perspective.near = 0.1f;
	r.primaryCamera.perspective.far = 10f;
	r.primaryCamera.isOrtho = false;
	r.primaryCamera.position = Vector3f(0f, 0f, 0f);
	r.primaryCamera.rotation = Vector3f(0f, 0f, 0f);
	r.primaryCamera.buildView;
	r.primaryCamera.buildProjection;

	win.onFramebufferResize.add((win, size) {
		r.primaryCamera.width = size.x;
		r.primaryCamera.height = size.y;
		r.primaryCamera.buildProjection;
		r.uiCamera.width = size.x;
		r.uiCamera.height = size.y;
		r.uiCamera.deduceOrtho;
		r.uiCamera.buildProjection;
		r.cameraUpdated;
		writeln("CALL");
	});

	StandardRenderer sr = new StandardRenderer(moxane);
	moxane.services.register!StandardRenderer(sr);
	r.addSceneRenderable(sr);

	Material material = new Material(sr.standardMaterialGroup);
	material.diffuse = Vector3f(1f, 0.5f, 0.9f);
	material.specular = Vector3f(0f, 0f, 0f);
	material.normal = null;
	material.depthWrite = true;
	material.hasLighting = true;
	material.castsShadow = true;
	Vector3f[] verts =
	[
		Vector3f(-1f, -1f, 0f),
		Vector3f(0f, 1f, 0f),
		Vector3f(1f, -1f, 0f)
	];
	Vector3f[] verts1 =
	[
		Vector3f(1f, 1f, 0f),
		Vector3f(0f, -1f, 0f),
		Vector3f(-1f, 1f, 0f)
	];
	Vector3f[] normals =
	[
		Vector3f(0f, 0f, 1f),
		Vector3f(0f, 0f, 1f),
		Vector3f(0f, 0f, 1f)
	];
	StaticModel sm = new StaticModel(sr, material, verts, normals);
	sr.addStaticModel(sm);
	sm.transformation = Transform.init;
	sm.transformation.position.x = -2f;
	sm.transformation.position.z = 5f;
	sm.transformation.scale.y = 2.5f;
	sm.transformation.scale.x = 0.5f;

	Material material1 = new Material(sr.standardMaterialGroup);
	material1.diffuse = Vector3f(0f, 0.5f, 0.9f);
	material1.specular = Vector3f(0f, 0f, 0f);
	material1.normal = null;
	material1.depthWrite = true;
	material1.hasLighting = true;
	material1.castsShadow = true;
	StaticModel sm1 = new StaticModel(sr, material1, verts1, normals);
	sr.addStaticModel(sm1);
	sm1.transformation = Transform.init;
	sm1.transformation.position.x = 2f;
	sm1.transformation.position.z = 5f;
	sm1.transformation.scale.y = 2.5f;
	sm1.transformation.scale.x = 0.5f;
	sm1.transformation.rotation.y = 90f;

	StopWatch sw = StopWatch(AutoStart.yes);
	StopWatch oneSecond = StopWatch(AutoStart.yes);
	int frameCount = 0;

	while(!win.shouldClose)
	{
		sw.stop;
		moxane.deltaTime = sw.peek.total!"nsecs" / 1_000_000_000f;
	
		if(oneSecond.peek.total!"msecs" >= 1000)
		{
			oneSecond.reset;
			moxane.frames = frameCount;
			frameCount = 0;
		}

		frameCount++;

		sw.reset;
		sw.start;
		
		sm.transformation.rotation.y += moxane.deltaTime * 180;
		sm1.transformation.rotation.y -= moxane.deltaTime * 180;
		r.render;

		win.swapBuffers;
		win.pollEvents;
	}
}
