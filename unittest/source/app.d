import std.stdio;

import moxane.core;
import moxane.graphics.renderer;
import moxane.graphics.light;
import moxane.io.window;
import moxane.graphics.ecs;

import moxane.graphics.standard;

import dlib.math;
import std.math;

import std.datetime.stopwatch;

import bindbc.newton;

//extern(C) __gshared string[] rt_options = ["gcopt=gc:precise profile:1"];

__gshared StopWatch projectileTime;
enum initialVelocity = 3000;
enum angle = degtorad(40f);

__gshared bool first = true;

extern(C) void cb_applyForce(const NewtonBody* body_, dFloat timestep, int threadIndex)
{
	// Fetch user data and body position.
	dFloat[4] pos;
	NewtonBodyGetPosition(body_, pos.ptr);

	dFloat mass;
	dFloat a0, a1, a2;
	NewtonBodyGetMass(body_, &mass, &a0, &a1, &a2);

	// Apply force.
	if(first)
	{
		dFloat[3] force = [initialVelocity * mass, 
						   /+initialVelocity * mass + +/-9.81 * mass, 
						   0];
		NewtonBodySetForce(body_, force.ptr);

		//first = false;
	}
	else
	{
		dFloat[3] force = [0, -9.81 * mass, 0];
		NewtonBodySetForce(body_, force.ptr);
	}


	// Print info to terminal.
	printf("Sleep=%d, %.2f, %.2f, %.2f\n", NewtonBodyGetSleepState(body_), pos[0], pos[1], pos[2]);
}

class TriangleRotateScript : AsyncScript
{
	NewtonWorld* world;
	NewtonBody* ground, sphere, sphere2, boxRight;
	Entity other;

	this(Moxane moxane, Entity other) @trusted
	{
		super(moxane, true, false);

		this.other = other;

		loadNewton;
		world = NewtonCreate();

		float[16] tm = [
			1.0f, 0.0f, 0.0f, 0.0f,
			0.0f, 1.0f, 0.0f, 0.0f,
			0.0f, 0.0f, 1.0f, 0.0f,
			0.0f, 0.0f, -5.0f, 1.0f
		];

		NewtonCollision* csSphere = NewtonCreateSphere(world, 1f, 0, null);
		NewtonCollision* csGround = NewtonCreateBox(world, 100, 0.1f, 100, 0, null);

		NewtonCollision* csBoxRight = NewtonCreateBox(world, 1, 10, 100, 0, null);

		ground = NewtonCreateDynamicBody(world, csGround, tm.ptr);
		tm[13] = 3.0f;
		sphere = NewtonCreateDynamicBody(world, csSphere, tm.ptr);
		tm[12] = 10;
		tm[13] = 0;
		boxRight = NewtonCreateKinematicBody(world, csBoxRight, tm.ptr);
		NewtonBodySetContinuousCollisionMode(boxRight, 1);
		NewtonBodySetContinuousCollisionMode(sphere, 1);


		//sphere2 = NewtonCreateDynamicBody(world, csSphere, tm.ptr);

		NewtonBodySetMassMatrix(sphere, 1f, 1, 1, 1);
		//NewtonBodySetMassMatrix(sphere2, 0.1f, 1, 1, 1);

		NewtonBodySetForceAndTorqueCallback(sphere, &cb_applyForce);
		//NewtonBodySetForceAndTorqueCallback(sphere2, &cb_applyForce);
	}

	override protected void deinit() @trusted
	{}

	override protected void execute() @trusted
	{
		projectileTime = StopWatch(AutoStart.yes);
		projectileTime.start;

		while(!moxane.exit)
		{
			NewtonUpdate(world, 1f / 60f);

			Transform* t = entity.get!Transform;
			float[4] arr;
			NewtonBodyGetPosition(sphere, arr.ptr);
			//writeln(arr);
			t.position.arrayof = arr[0..3];

			float[16] mat;
			NewtonBodyGetMatrix(sphere, mat.ptr);
			Matrix4f m;
			m.arrayof = mat;
			Vector3f euler = toEuler(m);
			t.rotation.x = radtodeg(euler.x);
			t.rotation.y = radtodeg(euler.y);
			t.rotation.z = radtodeg(euler.z);

			float[3] velo = [10, 0, 0];
			//NewtonBodySetVelocity(sphere, velo.ptr);
			//NewtonBodyIntegrateVelocity(sphere, 1/60f);

			/+Transform* t1 = other.get!Transform;
			NewtonBodyGetPosition(sphere2, arr.ptr);
			t1.position.arrayof = arr[0..3];

			NewtonBodyGetMatrix(sphere2, mat.ptr);
			m.arrayof = mat;
			euler = toEuler(m);
			t1.rotation.x = radtodeg(euler.x);
			t1.rotation.y = radtodeg(euler.y);
			t1.rotation.z = radtodeg(euler.z);+/

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

	/+r.primaryCamera.perspective.fieldOfView = 90f;
	r.primaryCamera.perspective.near = 0.1f;
	r.primaryCamera.perspective.far = 10f;
	r.primaryCamera.isOrtho = false;+/
	enum boundVert = 10;
	enum boundHoriz = 30;
	r.primaryCamera.ortho.top = boundVert;
	r.primaryCamera.ortho.bottom = -boundVert;
	r.primaryCamera.ortho.left = -boundHoriz;
	r.primaryCamera.ortho.right = boundHoriz;
	r.primaryCamera.ortho.near = 20f;
	r.primaryCamera.ortho.far = -20f;
	r.primaryCamera.isOrtho = true;
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

	Material material1 = new Material(sr.standardMaterialGroup);
	material1.diffuse = Vector3f(1f, 1f,1f);
	material1.specular = Vector3f(0f, 0f, 0f);
	material1.normal = null;
	material1.depthWrite = true;
	material1.hasLighting = true;
	material1.castsShadow = true;

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

	StaticModel sm1 = new StaticModel(sr, material1, verts, normals);
	sm1.localTransform = Transform.init;

	StaticModel sm = new StaticModel(sr, material, verts, normals);
	sm.localTransform = Transform.init;
	//sm.localTransform.rotation.y f;

	Entity entity = new Entity(entityManager);
	entityManager.add(entity);
	Transform* transform = entity.createComponent!Transform;
	*transform = Transform.init;
	RenderComponent* rc = entity.createComponent!RenderComponent;
	transform.position = Vector3f(0f, 0f, -5f);
	ers.addModel(sm, *rc);

	Entity entity1 = new Entity(entityManager);
	entityManager.add(entity1);
	Transform* transform1 = entity1.createComponent!Transform;
	*transform1 = Transform.init;
	RenderComponent* rc1 = entity1.createComponent!RenderComponent;
	transform1.position = Vector3f(0f, 0f, -5f);
	//ers.addModel(sm1, *rc1);

	entity.attachScript(new TriangleRotateScript(moxane, entity1));

	DirectionalLight dl = new DirectionalLight;
	dl.ambientIntensity = 1f;
	dl.direction = Vector3f(1, 0, 0);
	dl.colour = Vector3f(1, 1, 1);
	dl.diffuseIntensity = 0f;

	r.lights.directionalLights ~= dl;

	moxane.run;
}
