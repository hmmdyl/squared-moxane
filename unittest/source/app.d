import std.stdio;

import moxane.core.engine;
import moxane.core.log;
import moxane.graphics.renderer;
import moxane.graphics.light;
import moxane.io.window;
import moxane.core.asset;
import moxane.graphics.transformation;
import moxane.core.entity;
import moxane.graphics.ecs;
import moxane.core.async;

import moxane.graphics.standard;

import dlib.math;

import std.datetime.stopwatch;

import bindbc.newton;

//extern(C) __gshared string[] rt_options = ["gcopt=gc:precise profile:1"];

extern(C) void cb_applyForce(const NewtonBody* body_, dFloat timestep, int threadIndex)
{
	// Fetch user data and body position.
	dFloat[4] pos;
	NewtonBodyGetPosition(body_, pos.ptr);

	// Apply force.
	dFloat[3] force = [1, -10.0, 0];
	NewtonBodySetForce(body_, force.ptr);

	// Print info to terminal.
	printf("Sleep=%d, %.2f, %.2f, %.2f\n", NewtonBodyGetSleepState(body_), pos[0], pos[1], pos[2]);
}

class TriangleRotateScript : AsyncScript
{
	NewtonWorld* world;
	NewtonBody* ground, sphere;

	this(Moxane moxane) @trusted
	{
		super(moxane, true, false);

		loadNewton;
		world = NewtonCreate();

		float[16] tm = [
			1.0f, 0.0f, 0.0f, 0.0f,
			0.0f, 1.0f, 0.0f, 0.0f,
			0.0f, 0.0f, 1.0f, 0.0f,
			0.0f, 0.0f, -5.0f, 1.0f
		];

		NewtonCollision* csSphere = NewtonCreateSphere(world, 0.5f, 0, null);
		NewtonCollision* csGround = NewtonCreateBox(world, 100, 0.1f, 100, 0, null);

		ground = NewtonCreateDynamicBody(world, csGround, tm.ptr);
		tm[13] = 3.0f;
		sphere = NewtonCreateDynamicBody(world, csSphere, tm.ptr);
		//float[3] force = [0, -1, 0];
		//NewtonBodySetForce(sphere, force.ptr);

		NewtonBodySetMassMatrix(sphere, 1f, 1, 1, 1);

		NewtonBodySetForceAndTorqueCallback(sphere, &cb_applyForce);
	}

	override protected void deinit() @trusted
	{}

	override protected void execute() @trusted
	{
		while(!moxane.exit)
		{
			NewtonUpdate(world, 1f / 600f);

			Transform* t = entity.get!Transform;
			float[4] arr;
			NewtonBodyGetPosition(sphere, arr.ptr);
			//writeln(arr);
			t.position.arrayof = arr[0..3];

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
	sm.localTransform = Transform.init;
	sm.localTransform.rotation.y = 125f;

	Entity entity = new Entity(entityManager);
	entityManager.add(entity);
	Transform* transform = entity.createComponent!Transform;
	*transform = Transform.init;
	RenderComponent* rc = entity.createComponent!RenderComponent;
	transform.position = Vector3f(0f, 0f, -5f);
	ers.addModel(sm, *rc);
	entity.attachScript(new TriangleRotateScript(moxane));

	DirectionalLight dl = new DirectionalLight;
	dl.ambientIntensity = 1f;
	dl.direction = Vector3f(1, 0, 0);
	dl.colour = Vector3f(1, 1, 1);
	dl.diffuseIntensity = 0f;

	r.lights.directionalLights ~= dl;

	moxane.run;
}
