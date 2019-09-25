module moxane.physics.rigidbody;

import moxane.core;
import moxane.physics.core;
import moxane.physics.collider;

import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.transformation;
import dlib.math.utils;
import bindbc.newton;

import std.typecons;

class Body
{
	enum Mode
	{
		dynamic,
		kinematic
	}

	package NewtonBody* handle;

	PhysicsSystem system;
	Collider collider;
	const Mode mode;

	Transform transform;

	bool gravity;

	this(Collider collider, Mode mode, PhysicsSystem system, Transform transform = Transform.init) 
	in(collider !is null) in(system !is null)
	{ 
		this.collider = collider; 
		this.mode = mode;
		this.system = system;
		this.transform = transform;

		float[16] matrix = transform.matrix.arrayof;
		if(mode == Mode.dynamic)
			handle = NewtonCreateDynamicBody(system.handle, collider.handle, matrix.ptr);
		else
			handle = NewtonCreateKinematicBody(system.handle, collider.handle, matrix.ptr);

		NewtonBodySetUserData(handle, cast(void*)this);
		NewtonBodySetForceAndTorqueCallback(handle, &newtonApplyForce);
		NewtonBodySetTransformCallback(handle, &newtonTransformResult);
	}

	~this()
	{ NewtonDestroyBody(handle); handle = null; }

	@property const bool freeze() { return cast(bool)NewtonBodyGetFreezeState(handle); }
	@property void freeze(bool n) { NewtonBodySetFreezeState(handle, cast(int)n); }

	private Vector3f sumForce_;
	@property Vector3f sumForce() const { return sumForce_; }
	@property void sumForce(Vector3f sum) { sumForce_ = sum; }
	void addForce(Vector3f force) { sumForce_ += force; }

	private Vector3f sumTorque_;
	@property Vector3f sumTorque() const { return sumTorque_; }
	@property void sumTorque(Vector3f sum) { sumTorque_ = sum; }
	void addTorque(Vector3f torque) { sumTorque_ += torque; }

	@property bool collidable() const { return cast(bool)NewtonBodyGetCollidable(handle); }
	@property void collidable(bool n) const { NewtonBodySetCollidable(handle, cast(int)n); }

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
	@property void linearDamping(float damp) const { NewtonBodySetLinearDamping(handle, damp); }

	@property Tuple!(float, Vector3f) mass() const {
		float m; Vector3f inertia;
		NewtonBodyGetMass(handle, &m, &inertia.arrayof[0], &inertia.arrayof[1], &inertia.arrayof[2]);
		return tuple(m, inertia);
	}
	@property void mass(float m, Vector3f inertia) const { NewtonBodySetMassMatrix(handle, m, inertia.x, inertia.y, inertia.z); }

	@property void massFull(float mass, Matrix4f inertiaMatrix) const { NewtonBodySetFullMassMatrix(handle, mass, inertiaMatrix.arrayof.ptr); }

	@property Vector3f angularVelocity() const {
		Vector3f acc; NewtonBodyGetOmega(handle, acc.arrayof.ptr); return acc; }
	@property void angularVelocity(Vector3f vel) const { NewtonBodySetOmega(handle, vel.arrayof.ptr); }

	@property int simulationState() const { return NewtonBodyGetSimulationState(handle); }

	@property bool asleep() const { return cast(bool)NewtonBodyGetSleepState(handle); }

	@property Vector3f velocity() const {
		Vector3f vel; NewtonBodyGetVelocity(handle, vel.arrayof.ptr); return vel; }
	@property void velocity(Vector3f v) const { NewtonBodySetVelocity(handle, v.arrayof.ptr); }
}

extern(C) nothrow void newtonTransformResult(const NewtonBody* bodyPtr, const dFloat* matrix, int threadIndex)
{
	Body body_ = cast(Body)NewtonBodyGetUserData(bodyPtr);
	assert(body_ !is null, "All Newton Dynamics bodies should be routed through moxane.physics"); 

	Matrix4f m;
	m.arrayof = matrix[0..16]; // death

	Vector3f bodyPosition = translation(m);
	Vector3f bodyRotation = toEuler(m);
	bodyRotation.x = radtodeg(bodyRotation.x);
	bodyRotation.y = radtodeg(bodyRotation.y);
	bodyRotation.z = radtodeg(bodyRotation.z);
	
	body_.transform.position = bodyPosition;
	body_.transform.rotation = bodyRotation;
}

extern(C) nothrow void newtonApplyForce(const NewtonBody* bodyPtr, float timeStep, int threadIndex)
{
	Body body_ = cast(Body)NewtonBodyGetUserData(bodyPtr);
	assert(body_ !is null, "All Newton Dynamics bodies should be routed through moxane.physics");

	float[3] temp = body_.sumForce_.arrayof; 
	NewtonBodySetForce(bodyPtr, temp.ptr);
	body_.sumForce_ = Vector3f(0, 0, 0);

	temp = body_.sumTorque_.arrayof;
	NewtonBodySetTorque(bodyPtr, temp.ptr);
	body_.sumTorque_ = Vector3f(0, 0, 0);
}