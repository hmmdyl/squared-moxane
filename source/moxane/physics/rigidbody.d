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
	}

	final void destroy() { system.issueCommand(PhysicsCommand(PhysicsCommands.rigidBodyDestroy, this)); }

	package void initialise()
	{
		if(mode == Mode.dynamic)
			handle = NewtonCreateDynamicBody(system.worldHandle, collider.handle, transform.matrix.arrayof.ptr);
		else	
			handle = NewtonCreateKinematicBody(system.worldHandle, collider.handle, transform.matrix.arrayof.ptr);
	
		NewtonBodySetContinuousCollisionMode(handle, 1);
		NewtonBodySetUserData(handle, cast(void*)this);
		NewtonBodySetForceAndTorqueCallback(handle, &applyForce);
		NewtonBodySetTransformCallback(handle, &transformResult);
	}

	package void deinitialise()
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

	mixin(SharedGetter(Vector3f, "acceleration"));
	mixin(SharedGetter(Vector3f, "angularAcceleration"));
	mixin(SharedGetter(int, "simulationState"));
	mixin(SharedGetter(bool, "asleep"));

	void addForce(Vector3f force) { sumForce += force; }
	void addTorque(Vector3f torque) { sumTorque += torque; }

	package void updateFields(float dt)
	{
		scope(success) resetFieldUpdates;
		scope(success) transform.set = false;

		if(transform.set)
			NewtonBodySetMatrix(handle, transform.matrix.arrayof.ptr);

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
			NewtonBodySetVelocity(handle, velocity.arrayof.ptr);
			NewtonBodyIntegrateVelocity(handle, dt);
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

			NewtonBodySetTorque(bodyPtr, body_.sumTorque.arrayof.ptr);
			body_.sumTorque = Vector3f(0, 0, 0);
		}
		catch(Exception) {}
	}
}

class Body
{
	enum Mode
	{
		dynamic = 0,
		kinematic = 1
	}

	package NewtonBody* handle;

	PhysicsSystem system;
	Collider collider;
	const Mode mode;

	AtomicTransform transform;

	bool gravity;
	bool dampenPlayer;

	this() { mode = Mode.dynamic; }

	this(Collider collider, Mode mode, PhysicsSystem system, AtomicTransform transform = AtomicTransform.init) 
	in(collider !is null) in(system !is null)
	{ 
		this.collider = collider; 
		this.mode = mode;
		this.system = system;
		this.transform = transform;

		/+float[16] matrix = transform.matrix.arrayof;
		if(mode == Mode.dynamic)
			handle = NewtonCreateDynamicBody(system.handle, collider.handle, matrix.ptr);
		else
			handle = NewtonCreateKinematicBody(system.handle, collider.handle, matrix.ptr);

		NewtonBodySetContinuousCollisionMode(handle, 1);

		NewtonBodySetUserData(handle, cast(void*)this);
		NewtonBodySetForceAndTorqueCallback(handle, &newtonApplyForce);
		NewtonBodySetTransformCallback(handle, &newtonTransformResult);+/
	}

	~this()
	{ if(handle !is null) NewtonDestroyBody(handle); handle = null; }

	void upConstraint() {
		Vector3f up = Vector3f(0, 1, 0);
		//NewtonConstraintCreateUpVector(system.handle, up.arrayof.ptr, handle);
	}

	@property const bool freeze() { return cast(bool)NewtonBodyGetFreezeState(handle); }
	@property void freeze(bool n) { NewtonBodySetFreezeState(handle, cast(int)n); }

	private Vector3f sumForce_ = Vector3f(0, 0, 0);
	@property Vector3f sumForce() const { return sumForce_; }
	@property void sumForce(Vector3f sum) { sumForce_ = sum; }
	void addForce(Vector3f force) { sumForce_ += force; }

	void setForce() { NewtonBodySetForce(handle, sumForce_.arrayof.ptr); }

	private Vector3f sumTorque_ = Vector3f(0, 0, 0);
	@property Vector3f sumTorque() const { return sumTorque_; }
	@property void sumTorque(Vector3f sum) { sumTorque_ = sum; }
	void addTorque(Vector3f torque) { sumTorque_ += torque; }

	@property bool collidable() const { return cast(bool)NewtonBodyGetCollidable(handle); }
	@property void collidable(bool n) { NewtonBodySetCollidable(handle, cast(int)n); }

	@property Vector3f acceleration() const {
		Vector3f acc; NewtonBodyGetAcceleration(handle, acc.arrayof.ptr); return acc; }

	@property Vector3f angularAcceleration() const {
		Vector3f acc; NewtonBodyGetAlpha(handle, acc.arrayof.ptr); return acc; }

	@property Vector3f angularDamping() const {
		Vector3f damp; NewtonBodyGetAngularDamping(handle, damp.arrayof.ptr); return damp; }
	@property void angularDamping(Vector3f v) const { NewtonBodySetAngularDamping(handle, v.arrayof.ptr); }

	@property Vector3f centreOfMass() const {
		Vector3f com; NewtonBodyGetCentreOfMass(handle, com.arrayof.ptr); return com; }
	@property void centreOfMass(Vector3f com) { NewtonBodySetCentreOfMass(handle, com.arrayof.ptr); }

	@property Matrix4f inertiaMatrix() const {
		Matrix4f inm; NewtonBodyGetInertiaMatrix(handle, inm.arrayof.ptr); return inm; }

	@property Matrix4f inverseInertiaMatrix() const {
		Matrix4f invinm; NewtonBodyGetInvInertiaMatrix(handle, invinm.arrayof.ptr); return invinm; }

	@property Tuple!(float, Vector3f) inverseMass() const {
		float m; Vector3f inertia;
		NewtonBodyGetInvMass(handle, &m, &inertia.arrayof[0], &inertia.arrayof[1], &inertia.arrayof[2]);
		return tuple(m, inertia);
	}

	@property float linearDamping() const { return NewtonBodyGetLinearDamping(handle); }
	@property void linearDamping(float damp) { NewtonBodySetLinearDamping(handle, damp); }

	@property Tuple!(float, Vector3f) mass() const {
		float m; Vector3f inertia;
		NewtonBodyGetMass(handle, &m, &inertia.arrayof[0], &inertia.arrayof[1], &inertia.arrayof[2]);
		return tuple(m, inertia);
	}
	@property void mass(float m, Vector3f inertia) { NewtonBodySetMassMatrix(handle, m, inertia.x, inertia.y, inertia.z); }

	@property void massFull(float mass, Matrix4f inertiaMatrix) { NewtonBodySetFullMassMatrix(handle, mass, inertiaMatrix.arrayof.ptr); }

	@property massProperties(float mass) { NewtonBodySetMassProperties(handle, mass, collider.handle); }

	void updateMatrix()
	{
		NewtonBodySetMatrix(handle, transform.matrix.arrayof.ptr);
	}

	void getTransform()
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

	@property Vector3f angularVelocity() const {
		Vector3f acc; NewtonBodyGetOmega(handle, acc.arrayof.ptr); return acc; }
	@property void angularVelocity(Vector3f vel) { NewtonBodySetOmega(handle, vel.arrayof.ptr); }

	@property int simulationState() const { return NewtonBodyGetSimulationState(handle); }

	@property bool asleep() const { return cast(bool)NewtonBodyGetSleepState(handle); }

	@property Vector3f velocity() const {
		Vector3f vel; NewtonBodyGetVelocity(handle, vel.arrayof.ptr); return vel; }
	@property void velocity(Vector3f v) { NewtonBodySetVelocity(handle, v.arrayof.ptr); }

	void integrateVelocity(float ts) { NewtonBodyIntegrateVelocity(handle, ts); }
}

class DynamicPlayerBody : Body
{
	const float height, radius;

	float yaw = 0f;
	float strafe = 0f, forward = 0f, vertical = 0f;

	float floatHeight = 0.6f;

	this(PhysicsSystem system, float radius, float height, float mass, AtomicTransform transform = AtomicTransform.init) 
	in(system !is null)
	{ 
		super.system = system;
		super.transform = transform;

		enum scale = 3f;
		height = max(height - 2f * radius / scale, 0.1f);

		this.height = height;
		this.radius = radius;

		collider = new BoxCollider(system, Vector3f(0.25f, 1.3f, 0.25f), Transform(Vector3f(0, 0.65f, 0)));
			//new CapsuleCollider(system, 0.1f, 0.1f, 0.3f);
		//collider.scale = Vector3f(1, scale, scale);

		float[16] matrix = transform.matrix.arrayof;
		//handle = NewtonCreateDynamicBody(system.handle, collider.handle, matrix.ptr);
		NewtonBodySetForceAndTorqueCallback(handle, &newtonApplyForce);
		gravity = true;

		NewtonBodySetContinuousCollisionMode(handle, 1);

		upConstraint;

		NewtonBodySetUserData(handle, cast(void*)this);
		NewtonBodySetTransformCallback(handle, &newtonTransformResult);

		super.mass(mass, Vector3f(1, 1, 1));
		super.collidable = true;
	} 

	void update(float dt)
	{
		getTransform;
		Vector3f rot = Vector3f(0, 0, 0);
		transform.rotation = rot;
		updateMatrix;
		
		foreach(t; 0 .. 1)
		{
			auto calculatedVelocity = Vector3f(velocity.x * 0.1f, /+raycastHit ? vertical : vertical + velocity.y+/velocity.y * 0.1f, velocity.z * 0.1f);
			velocity = calculatedVelocity;

			raycastHit = false;
			Vector3f start = transform.position;
			Vector3f end = start - Vector3f(0, floatHeight, 0);
			//NewtonWorldRayCast(system.handle, start.arrayof.ptr, end.arrayof.ptr, &newtonRaycastCallback, cast(void*)this, &newtonPrefilterCallback, 0);

			if(raycastHit)// || velocity.y == 0f)
			{
				transform.position = Vector3f(transform.position.x, raycastHitCoord.y + floatHeight, transform.position.z);
				updateMatrix;
			}

			integrateVelocity(dt / 1);
			getTransform;
		}
	}

	bool raycastHit;
	Vector3f raycastHitCoord = Vector3f(0, 0, 0);

	private static extern(C) float newtonRaycastCallback(const NewtonBody* bodyPtr, const NewtonCollision* shapeHit, const float* hitContact, const float* hitNormal, long collisionID, void* userData, float intersectParam)
	{
		try
		{
			DynamicPlayerBody dpb = cast(DynamicPlayerBody)userData;
			dpb.raycastHitCoord = Vector3f(hitContact[0], hitContact[1], hitContact[2]);
			dpb.raycastHit = true;
			return intersectParam;
		}
		catch(Exception) {}
	}

	private static extern(C) uint newtonPrefilterCallback(const NewtonBody* bodyPtr, const NewtonCollision* collPtr, void* userData) nothrow
	{
		if(bodyPtr == userData) return 0;
		else return 1;
	}
}

extern(C) nothrow void newtonTransformResult(const NewtonBody* bodyPtr, const dFloat* matrix, int threadIndex)
{
	try 
	{
		Body body_ = cast(Body)NewtonBodyGetUserData(bodyPtr);
		assert(body_ !is null, "All Newton Dynamics bodies should be routed through moxane.physics"); 

		body_.getTransform;
	}
	catch(Exception) {}
}

extern(C) nothrow void newtonApplyForce(const NewtonBody* bodyPtr, float timeStep, int threadIndex)
{
	try 
	{
		Body body_ = cast(Body)NewtonBodyGetUserData(bodyPtr);
		assert(body_ !is null, "All Newton Dynamics bodies should be routed through moxane.physics");

		if(body_.gravity)
			body_.sumForce_ += Vector3f(body_.mass[0] * body_.system.gravity.x, body_.mass[0] * body_.system.gravity.y, body_.mass[0] * body_.system.gravity.z);

		float[3] temp = body_.sumForce_.arrayof; 
		NewtonBodySetForce(bodyPtr, temp.ptr);
		body_.sumForce_ = Vector3f(0, 0, 0);

		temp = body_.sumTorque_.arrayof;
		NewtonBodySetTorque(bodyPtr, temp.ptr);
		body_.sumTorque_ = Vector3f(0, 0, 0);
	}
	catch(Exception) {}
}