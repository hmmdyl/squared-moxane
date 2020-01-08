module moxane.physics.rigidbody;

import moxane.core;
import moxane.physics.core;
import moxane.physics.collider;
import moxane.physics.commands;
import moxane.utils.sharedwrap;

import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.transformation;
import dlib.math.utils;
import dlib.math.linsolve;
import bindbc.newton;

import std.math;
import std.typecons;
import std.algorithm;
import core.atomic;

@trusted:

class BodyMT
{
	enum Mode { dynamic, kinematic }
	immutable Mode mode;

	package NewtonBody* handle;

	PhysicsSystem system;
	Collider collider;

	AtomicTransform transform;

	this(PhysicsSystem system, Mode mode, Collider collider, AtomicTransform transform = AtomicTransform.init)
	in(collider !is null) in(system !is null)
	{
		this.collider = collider; 
		this.mode = mode;
		this.system = system;
		this.transform = transform;

		system.issueCommand(PhysicsCommand(PhysicsCommands.rigidBodyCreate, this));
	
		sumForce = Vector3f(0, 0, 0);
		sumTorque = Vector3f(0, 0, 0);
		atomicStore(updatedFields_, 0);
	}

	final void destroy() { system.issueCommand(PhysicsCommand(PhysicsCommands.rigidBodyDestroy, this)); }

	void initialise()
	{
		if(mode == Mode.dynamic)
			handle = NewtonCreateDynamicBody(system.worldHandle, collider.handle, transform.matrix.arrayof.ptr);
		else	
			handle = NewtonCreateKinematicBody(system.worldHandle, collider.handle, transform.matrix.arrayof.ptr);
	
		NewtonBodySetContinuousCollisionMode(handle, 1);
		NewtonBodySetUserData(handle, cast(void*)this);
		NewtonBodySetForceAndTorqueCallback(handle, &applyForce);
		NewtonBodySetTransformCallback(handle, &transformResult);

		NewtonBodySetMassMatrix(handle, 10f, 1, 1, 1);

		gravity = true;
		transform.set = true;
	}

	void deinitialise()
	{
		NewtonDestroyBody(handle);
		handle = null;
	}

	mixin(evaluateProperties!(bool, "gravity",
							  bool, "freeze",
							  Vector3f, "sumForce",
							  Vector3f, "sumTorque",
							  bool, "collidable",
							  Vector3f, "angularDampening",
							  Vector3f, "centreOfMass",
							  float, "mass",
							  Vector3f, "massMatrix",
							  float, "linearDampening",
							  Vector3f, "velocity",
							  Vector3f, "angularVelocity")());

	mixin(SharedGetter!(Vector3f, "acceleration"));
	mixin(SharedGetter!(Vector3f, "angularAcceleration"));
	mixin(SharedGetter!(int, "simulationState"));
	mixin(SharedGetter!(bool, "asleep"));

	void addForce(Vector3f force) { sumForce = sumForce + force; }
	void addTorque(Vector3f torque) { sumTorque = sumTorque + torque; }

	void updateFields(float dt)
	{
		scope(exit) resetFieldUpdates;
		scope(exit) transform.set = false;

		if(transform.set)
			NewtonBodySetMatrix(handle, transform.matrix.arrayof.ptr);

		NewtonBodySetFreezeState(handle, cast(int)false);

		if(isFieldUpdate(FieldName.freeze))
			NewtonBodySetFreezeState(handle, cast(int)freeze);
		else freeze = cast(bool)NewtonBodyGetFreezeState(handle);

		if(isFieldUpdate(FieldName.collidable))
			NewtonBodySetCollidable(handle, cast(int)collidable);
		else collidable = cast(bool)NewtonBodyGetCollidable(handle);

		if(isFieldUpdate(FieldName.mass) || isFieldUpdate(FieldName.massMatrix))
			NewtonBodySetMassMatrix(handle, mass, massMatrix.x, massMatrix.y, massMatrix.z);
		else
		{
			float m;
			Vector3f inertia;
			NewtonBodyGetMass(handle, &m, &inertia.arrayof[0], &inertia.arrayof[1], &inertia.arrayof[2]);

			mass = m;
			massMatrix = inertia;
		}

		if(isFieldUpdate(FieldName.velocity))
		{
			//NewtonBodySetVelocity(handle, velocity.arrayof.ptr);
			//NewtonBodyIntegrateVelocity(handle, dt);
		}
		else 
		{
			Vector3f v;
			NewtonBodyGetVelocity(handle, v.arrayof.ptr);
			velocity = v;
		}

		// getters
		simulationState = NewtonBodyGetSimulationState(handle);
		asleep = cast(bool)NewtonBodyGetSleepState(handle);
		{
			Vector3f t;
			NewtonBodyGetAcceleration(handle, t.arrayof.ptr);
			acceleration = t;
			NewtonBodyGetAlpha(handle, t.arrayof.ptr);
			angularAcceleration = t;
		}
	}

	private void getTransform()
	{
		Matrix4f m;
		NewtonBodyGetMatrix(handle, m.arrayof.ptr);

		Vector3f bodyPosition = translation(m);
		Vector3f bodyRotation = toEuler(m);
		bodyRotation.x = radtodeg(bodyRotation.x);
		bodyRotation.y = radtodeg(bodyRotation.y);
		bodyRotation.z = radtodeg(bodyRotation.z);

		transform.position = bodyPosition;
		transform.rotation = bodyRotation;
	}

	package static extern(C) nothrow void transformResult(const NewtonBody* bodyPtr, const dFloat* matrix, int threadIndex)
	{
		try 
		{
			BodyMT body_ = cast(BodyMT)NewtonBodyGetUserData(bodyPtr);
			assert(body_ !is null, "All Newton Dynamics bodies should be routed through moxane.physics"); 

			body_.getTransform;
		}
		catch(Exception) {}
	}

	package static extern(C) nothrow void applyForce(const NewtonBody* bodyPtr, float timeStep, int threadIndex)
	{
		try 
		{
			BodyMT body_ = cast(BodyMT)NewtonBodyGetUserData(bodyPtr);
			assert(body_ !is null, "All Newton Dynamics bodies should be routed through moxane.physics");

			Vector3f force = body_.sumForce;
			const float mass = body_.mass;

			if(body_.gravity)
				force += mass * body_.system.gravity;

			NewtonBodySetForce(bodyPtr, force.arrayof.ptr);
			body_.sumForce = Vector3f(0, 0, 0);

			Vector3f t = body_.sumTorque;
			NewtonBodySetTorque(bodyPtr, t.arrayof.ptr);
			body_.sumTorque = Vector3f(0, 0, 0);
		}
		catch(Exception) {}
	}
}

class DynamicPlayerBodyMT : BodyMT
{
	const float height, radius;

	mixin(SharedProperty!(float, "strafe"));
	mixin(SharedProperty!(float, "forward"));
	mixin(SharedProperty!(float, "vertical"));
	mixin(SharedProperty!(float, "floatHeight"));
	mixin(SharedProperty!(bool, "initialised"));

	this(PhysicsSystem system, float radius, float height, AtomicTransform transform = AtomicTransform.init)
	{
		this.height = height;
		this.radius = radius;

		strafe = 0f;
		forward = 0f;
		vertical = 0f;
		floatHeight = 0.6f;
		initialised = false;

		super(system, Mode.dynamic, new BoxCollider(system, Vector3f(0.25f, 1.3f, 0.25f), Transform(Vector3f(0, 0.65f, 0))), transform);
		system.addEvent.addCallback(&onCreateCallback);
	}

	override void initialise()
	{ }

	private void onCreateCallback(ref PhysicsCommand addEvent) @trusted
	{
		if(addEvent.type == PhysicsCommands.colliderCreate && addEvent.target == collider)
		{
			super.initialise;
			//collidable = true;
			//mass = 80;
			//massMatrix = Vector3f(1f, 1f, 1f);
			initialised = true;
		}
	}

	override void updateFields(float dt) 
	{
		if(initialised)
		{
			addForce(Vector3f(strafe, vertical, forward));

			super.updateFields(dt);

			getTransform;
			transform.rotation = Vector3f(0f, 0f, 0f);

			NewtonBodySetMatrix(handle, transform.matrix.arrayof.ptr);
			transform.set = false;

			auto calcVelo = Vector3f(
									 strafe == 0f ? velocity.x * 0.1f : strafe * 0.1f,
									 velocity.y * 0.9f,
									 forward == 0f ? velocity.z * 0.1f : forward * 0.1f
									 );

			NewtonBodySetVelocity(handle, calcVelo.arrayof.ptr);

			raycastHit = false;
			Vector3f start = transform.position;
			Vector3f end = start - Vector3f(0f, floatHeight, 0f);

			NewtonWorldRayCast(system.worldHandle, start.arrayof.ptr, end.arrayof.ptr, &newtonRaycastCallback, cast(void*)this, &newtonPrefilterCallback, 0);
			if(raycastHit)
			{
				transform.position = Vector3f(transform.position.x, raycastHitCoord.y + floatHeight, transform.position.z);
				NewtonBodySetMatrix(handle, transform.matrix.arrayof.ptr);
				transform.set = false;
			}

			//NewtonBodyIntegrateVelocity(handle, dt);

			super.updateFields(dt);
		}
	}

	/+override void updateFields(float dt) 
	{
		if(initialised)
		{
			if(dt == 0) dt = 1f;
			dt *= 1000f;
			super.updateFields(dt);
			getTransform;
			transform.rotation = Vector3f(0f, 0f, 0f);

			NewtonBodySetMatrix(handle, transform.matrix.arrayof.ptr);
			transform.set = false;

			auto calcVelo = Vector3f(velocity.x * 0.1f *  (1f / dt), velocity.y * 0.1f * (1f / dt), velocity.z * 0.1f * (1f / dt));
			NewtonBodySetVelocity(handle, calcVelo.arrayof.ptr);

			raycastHit = false;
			Vector3f start = transform.position;
			Vector3f end = start - Vector3f(0f, floatHeight, 0f);

			NewtonWorldRayCast(system.worldHandle, start.arrayof.ptr, end.arrayof.ptr, &newtonRaycastCallback, cast(void*)this, &newtonPrefilterCallback, 0);
			if(raycastHit)
			{
				transform.position = Vector3f(transform.position.x, raycastHitCoord.y + floatHeight, transform.position.z);
				NewtonBodySetMatrix(handle, transform.matrix.arrayof.ptr);
				transform.set = false;
			}

			//NewtonBodyIntegrateVelocity(handle, dt);

			super.updateFields(dt);
		}
	}+/

	bool raycastHit;
	Vector3f raycastHitCoord = Vector3f(0, 0, 0);

	private static extern(C) float newtonRaycastCallback(const NewtonBody* bodyPtr, const NewtonCollision* shapeHit, const float* hitContact, const float* hitNormal, long collisionID, void* userData, float intersectionParam)
	{
		try
		{
			DynamicPlayerBodyMT dpb = cast(DynamicPlayerBodyMT)userData;
			dpb.raycastHitCoord = Vector3f(hitContact[0], hitContact[1], hitContact[2]);
			dpb.raycastHit = true;
			return intersectionParam;
		}
		catch(Exception){}
	}

	private static extern(C) uint newtonPrefilterCallback(const NewtonBody* bodyPtr, const NewtonCollision* collPtr, void* userData) nothrow
	{
		if(bodyPtr == userData) return 0;
		else return 1;
	}
}