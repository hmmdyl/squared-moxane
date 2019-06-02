import std.stdio;

import moxane.core.engine;
import moxane.core.log;
import moxane.graphics.renderer;
import moxane.io.window;
import moxane.core.asset;
import moxane.graphics.transformation;
import moxane.core.entity;
import moxane.graphics.ecs;
import moxane.core.async;

import moxane.graphics.standard;

import dlib.math;

import std.datetime.stopwatch;

//extern(C) __gshared string[] rt_options = ["gcopt=gc:precise profile:1"];

class TriangleRotateScript : AsyncScript
{
	this(Moxane moxane) @trusted
	{
		super(moxane, true, false);
	}

	override protected void deinit() @trusted
	{}

	override protected void execute() @trusted
	{
		while(!moxane.exit)
		{
			moxane.services.get!Log().write(Log.Severity.info, "yeet");
			Transform* t = entity.get!Transform;
			t.rotation.y += 10f;

			moxane.services.get!AsyncSystem().awaitNextFrame(this);
			mixin(checkCancel);
		}
	}
}

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
		asyncSystem : true,
		entitySystem : true
	};
	Moxane moxane = new Moxane(settings, "Moxane Unittest");
	
	Log log = moxane.services.get!Log;
	log.write(Log.Severity.debug_, "Hello");

	Window win = moxane.services.get!Window;
	Renderer r = moxane.services.get!Renderer;
	StandardRenderer sr = new StandardRenderer(moxane);
	moxane.services.register!StandardRenderer(sr);
	EntityManager entityManager = moxane.services.get!EntityManager;
	EntityRenderSystem ers = new EntityRenderSystem(moxane);

	r.primaryCamera.perspective.fieldOfView = 90f;
	r.primaryCamera.perspective.near = 0.1f;
	r.primaryCamera.perspective.far = 10f;
	r.primaryCamera.isOrtho = false;
	r.primaryCamera.position = Vector3f(0f, 0f, 0f);
	r.primaryCamera.rotation = Vector3f(0f, 0f, 0f);
	r.primaryCamera.buildView;
	r.primaryCamera.buildProjection;

	win.onFramebufferResize.add((win, size) @trusted {
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
	//sr.addStaticModel(sm);
	sm.localTransform = Transform.init;
	sm.localTransform.rotation.y = 125f;

	/*Material material1 = new Material(sr.standardMaterialGroup);
	material1.diffuse = Vector3f(0f, 0.5f, 0.9f);
	material1.specular = Vector3f(0f, 0f, 0f);
	material1.normal = null;
	material1.depthWrite = true;
	material1.hasLighting = true;
	material1.castsShadow = true;
	StaticModel sm1 = new StaticModel(sr, material1, verts1, normals);
	sr.addStaticModel(sm1);
	sm1.finalTransform = Transform.init;
	sm1.finalTransform.position.x = 0.01f;
	sm1.finalTransform.position.z = 5f;
	sm1.finalTransform.scale.y = 2.5f;
	sm1.finalTransform.scale.x = 0.5f;
	sm1.finalTransform.rotation.y = 90f;*/

	Entity entity = new Entity;
	entityManager.add(entity);
	Transform* transform = entity.createComponent!Transform;
	*transform = Transform.init;
	RenderComponent* rc = entity.createComponent!RenderComponent;
	transform.position = Vector3f(0f, 0f, 5f);
	ers.addModel(sm, *rc);
	entity.attachScript(new TriangleRotateScript(moxane));

	moxane.run;

	/*StopWatch sw = StopWatch(AutoStart.yes);
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
	}*/
}
