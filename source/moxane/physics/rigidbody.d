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

abstract class BodyRootMT
{
	PhysicsSystem system;
	AtomicTransform transform;

	private this(PhysicsSystem system) in(system !is null)
	{
		this.system = system;
		this.system.issueCommand(PhysicsCommand(PhysicsCommands.rigidBodyCreate, this));
	}

	final void destroy() { system.issueCommand(PhysicsCommand(PhysicsCommands.rigidBodyDestroy, this)); }

	abstract void initialise();
	abstract void deinitialise();

	abstract void updateFields(float dt);
}

class BodyMT : BodyRootMT
{
	enum Mode { dynamic, kinematic }
	immutable Mode mode;

	package NewtonBody* handle;

	Collider collider;

	this(PhysicsSystem system, Mode mode, Collider collider, AtomicTransform transform = AtomicTransform.init)
	{
		this.collider = collider; 
		this.mode = mode;
		this.transform = transform;
	
		sumForce = Vector3f(0, 0, 0);
		sumTorque = Vector3f(0, 0, 0);
		atomicStore(updatedFields_, 0);

		super(system);
	}

	override void initialise()
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

	override void deinitialise()
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

	override void updateFields(float dt)
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

class DynamicPlayerBodyMT : BodyRootMT
{
	immutable float totalHeight, floatHeight, radius;

	mixin(SharedProperty!(Vector3f, "velocity"));
	mixin(SharedProperty!(float, "terminalVelocity"));

	this(PhysicsSystem system, 
		 float radius, float totalHeight, float floatHeight, 
		 AtomicTransform transform = AtomicTransform.init)
	in(radius > 0) in(totalHeight > 0) in(floatHeight > 0)
	{
		this.transform = transform;
		this.radius = radius;
		this.totalHeight = totalHeight;
		this.floatHeight = floatHeight;
		super(system);
	}

	override void initialise() {}
	override void deinitialise() {}

	private bool raycastHit;
	private Vector3f raycastHitCoord = Vector3f(0, 0, 0);

	bool footHit, dirHit;

	override void updateFields(float dt) 
	{
		footHit = false;
		dirHit = false;

		Vector3f horizontalVelocity = Vector3f(velocity.x, 0f, velocity.z);
		horizontalVelocity.normalize;

		Vector3f nextVelocity = velocity;

		Vector3f start = transform.position + Vector3f(0, floatHeight, 0);
		Vector3f end = transform.position  - Vector3f(0, 0.05f, 0);

		//velocity = Vector3f(velocity.x,  -9.81, velocity.z);

		if(velocity.y < 0)
		{
			NewtonWorldRayCast(system.worldHandle, start.arrayof.ptr, end.arrayof.ptr, 
				&newtonRaycastCallback, cast(void*)this, &newtonPrefilterCallback, 0);
			if(raycastHit)
			{
				footHit = true;
				nextVelocity.y = 0;
				Vector3f nt = transform.position;
				nt.y = raycastHitCoord.y;
				transform.position = nt;
			}
			raycastHit = false;
		}

		if(velocity.x != 0 || velocity.z != 0)
		{
			start = transform.position + Vector3f(0, floatHeight + 0.1f, 0);
			end = start + horizontalVelocity * radius;

			NewtonWorldRayCast(system.worldHandle, start.arrayof.ptr, end.arrayof.ptr, 
							   &newtonRaycastCallback, cast(void*)this, &newtonPrefilterCallback, 0);
			if(raycastHit)
			{
				dirHit = true;
				nextVelocity.x = 0;
				nextVelocity.z = 0;
			}
			raycastHit = false;
		}

		//velocity = nextVelocity;

		transform.position = transform.position + nextVelocity * dt;
	}

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
		return 1;
	}
}