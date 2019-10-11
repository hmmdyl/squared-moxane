module moxane.physics.rigidbody;

import moxane.core;
import moxane.physics.core;
import moxane.physics.collider;
import moxane.utils.newtonmath;

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

		float[16] matrix = transform.matrix.arrayof;
		if(mode == Mode.dynamic)
			handle = NewtonCreateDynamicBody(system.handle, collider.handle, matrix.ptr);
		else
			handle = NewtonCreateKinematicBody(system.handle, collider.handle, matrix.ptr);

		NewtonBodySetContinuousCollisionMode(handle, 1);

		NewtonBodySetUserData(handle, cast(void*)this);
		NewtonBodySetForceAndTorqueCallback(handle, &newtonApplyForce);
		NewtonBodySetTransformCallback(handle, &newtonTransformResult);
	}

	~this()
	{ NewtonDestroyBody(handle); handle = null; }

	void upConstraint() {
		Vector3f up = Vector3f(0, 1, 0);
		NewtonConstraintCreateUpVector(system.handle, up.arrayof.ptr, handle);
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
		handle = NewtonCreateDynamicBody(system.handle, collider.handle, matrix.ptr);
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
			auto calculatedVelocity = Vector3f(velocity.x * 0.1f, raycastHit ? vertical : vertical + velocity.y, velocity.z * 0.1f);
			velocity = calculatedVelocity;

			raycastHit = false;
			Vector3f start = transform.position;
			Vector3f end = start - Vector3f(0, floatHeight, 0);
			NewtonWorldRayCast(system.handle, start.arrayof.ptr, end.arrayof.ptr, &newtonRaycastCallback, cast(void*)this, &newtonPrefilterCallback, 0);

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

class KinematicPlayerBody : Body
{
	private float height, radius, stepHeight;
	private float contactPatch;

	private bool isAirborne, onFloor;

	float lateralSpeed = 0f, forwardSpeed = 0f, headingAngle = 0f;
	Vector3f impulse = Vector3f(0, 0, 0);

	this(PhysicsSystem system, float radius, float height, float mass, AtomicTransform transform = AtomicTransform.init) 
	in(system !is null)
	{ 
		super.system = system;
		super.transform = transform;
		
		stepHeight = height / 3f;
		enum scale = 3f;
		height = max(height - 2f * radius / scale, 0.1f);

		this.height = height;
		this.radius = radius;
		this.contactPatch = radius / scale;

		collider = new CapsuleCollider(system, radius / scale, radius / scale, height);
		collider.scale = Vector3f(1, scale, scale);

		float[16] matrix = transform.matrix.arrayof;
		handle = NewtonCreateKinematicBody(system.handle, collider.handle, matrix.ptr);

		NewtonBodySetUserData(handle, cast(void*)this);
		NewtonBodySetTransformCallback(handle, &newtonTransformResult);

		super.massProperties(mass);
		super.collidable = true;

		impulseSolver = new ImpulseSolver(this);
	} 

	// NOTICE
	// This code is nearly a 1:1 translation from Newton's tutorials

	private class ImpulseSolver
	{
		struct Jacobian
		{
			Vector3f linear, angular;
		}

		Matrix4f invInertia;
		Vector3f veloc;
		Jacobian[maxRows*3] jacobian;
		bool[maxRows*3] contactPointPresent;
		NewtonWorldConvexCastReturnInfo[maxRows*3] contactPoint;
		float[maxRows*3] rhs, low, high, impulseMag;
		int[maxRows*3] normalIndex;
		float mass, invMass;
		int rowCount;

		KinematicPlayerBody outer;

		this(KinematicPlayerBody pb)
		{
			outer = pb;
			mass = outer.mass()[0];
			invMass = outer.inverseMass()[0];
			invInertia = outer.inverseInertiaMatrix;
			rhs[] = 0f;
			low[] = 0f;
			high[] = 0f;
			impulseMag[] = 0f;
			reset;
		}

		void reset()
		{
			rowCount = 0;
			veloc = outer.velocity;
			contactPointPresent[] = false;
		}

		void addAngularRows()
		{
			foreach(i; 0 .. 3)
			{
				contactPointPresent[rowCount] = false;
				jacobian[rowCount].linear = Vector3f(0, 0, 0);
				jacobian[rowCount].angular = Vector3f(0, 0, 0);
				jacobian[rowCount].angular[i] = 1f;
				rhs[rowCount] = 0f;
				impulseMag[rowCount] = 0f;
				low[rowCount] = -10f;
				high[rowCount] = 10f;
				normalIndex[rowCount] = 0;
				rowCount++;
				assert(rowCount < maxRows*3);
			}
		}

		int addLinearRow(Vector3f dir, Vector3f r, float accel, float low, float high, int normalIndex = -1)
		{
			contactPointPresent[rowCount] = false;
			jacobian[rowCount].linear = dir;
			jacobian[rowCount].angular = cross(r, dir);
			this.low[rowCount] = low;
			this.high[rowCount] = high;
			this.normalIndex[rowCount] = (normalIndex == -1) ? 0 : normalIndex - rowCount;
			rhs[rowCount] = accel - dot(veloc, jacobian[rowCount].linear);
			
			rowCount++;
			assert(rowCount < maxRows*3);

			return rowCount - 1;
		}

		Vector3f calculateImpulse()
		{
			dFloat[maxRows*3][maxRows*3] massMatrix;
			foreach(ref r; massMatrix)
				r[] = 0f;
			foreach(i; 0 .. rowCount)
			{
				Jacobian jInvMass = jacobian[i];

				jInvMass.linear = jInvMass.linear * invMass;
				jInvMass.angular = rotateVector(invInertia, jInvMass.angular);

				auto tmp = Vector3f(jInvMass.linear * jacobian[i].linear + jInvMass.angular * jacobian[i].angular);

				dFloat a00 = (tmp.x + tmp.y + tmp.z) * 1.0001f;
				massMatrix[i][i] = a00;

				impulseMag[i] = 0.0f;
				for (int j = i + 1; j < rowCount; j++) {
					auto tmp1 = Vector3f(jInvMass.linear * jacobian[j].linear + jInvMass.angular * jacobian[j].angular);
					dFloat a01 = tmp1.x + tmp1.y + tmp1.z;
					massMatrix[i][j] = a01;
					massMatrix[j][i] = a01;
				}
			}

			//dGaussSeidelLcpSor(m_rowCount, D_MAX_ROWS, &massMatrix[0][0], m_impulseMag, m_rhs, m_normalIndex, m_low, m_high, dFloat(1.0e-6f), 32, dFloat(1.1f));
			//dGaussSeidelLcpSor!float(rowCount, maxRows, &massMatrix[0][0], impulseMag.ptr, rhs.ptr, normalIndex.ptr, low.ptr, high.ptr, 1.0e-6f, 32, 1.1f);
			
			{
				double delta;

				for (int k = 0; k < 32; ++k)
				{
					for (int i = 0; i < rowCount; ++i)
					{
						delta = 0.0;

						for (int j = 0; j < i; ++j)
							delta += massMatrix[j][i] * impulseMag[j];

						for (int j = i + 1; j < rowCount; ++j)
							delta += massMatrix[j][i] * impulseMag[j];

						delta = (rhs[i] - delta) / massMatrix[i][i];
						impulseMag[i] = delta;
					}
				}
			}

			foreach(im; 0..impulseMag.length)
				if(impulseMag[im].isNaN)
					impulseMag[im] = 0f;

			auto netImpulse = Vector3f(0, 0, 0);
			for (int i = 0; i < rowCount; i++) {
				netImpulse += jacobian[i].linear * impulseMag[i];
			}
			return netImpulse;
		}

		void applyReaction(float timestep)
		{
			Matrix4f m;
			auto com = Vector4f(0, 0, 0, 0);
			float mass, ixx, iyy, izz;
			foreach(i; 0 .. rowCount)
			{
				if(contactPointPresent[i])
				{
					NewtonBodyGetMatrix(contactPoint[i].m_hitBody, m.arrayof.ptr);
					NewtonBodyGetCentreOfMass(contactPoint[i].m_hitBody, com.arrayof.ptr);
					auto point = Vector4f(contactPoint[i].m_point);
					point.w = 0;
					auto r = (point - com * m).xyz;
					NewtonBodyGetMass(contactPoint[i].m_hitBody, &mass, &ixx, &iyy, &izz);

					mass *= 0.1f;

					auto linearImpulse = jacobian[i].linear * (-impulseMag[i] * mass / (mass + this.mass));
					auto angularImpulse = cross(r, jacobian[i].linear);
					NewtonBodyApplyImpulsePair(contactPoint[i].m_hitBody, linearImpulse.arrayof.ptr, angularImpulse.arrayof.ptr, timestep);
				}
			}
		}
	}

	private ImpulseSolver impulseSolver;

	private enum maxContacts = 6;
	private enum maxRows = maxContacts * 3;
	private enum maxCollisionSteps = 8;
	private enum maxCollisionPenetration = 5.0e-3f;

	int contactCount;
	private NewtonWorldConvexCastReturnInfo[maxRows] contactBuffer;

	void calculateContacts()
	{
		Matrix4f m = matrix();
		contactCount = NewtonWorldCollide(super.system.handle, m.arrayof.ptr, super.collider.handle, cast(void*)this, &prefilterCallback, contactBuffer.ptr, maxContacts, 0);
	}

	extern(C) private static uint prefilterCallback(const NewtonBody* bodyPtr, const NewtonCollision* collision, void* userPtr)
	{
		Body body_ = cast(Body)userPtr;
		assert(body_ !is null);

		if(body_.handle == bodyPtr) return 0;
		else return 1;
	}

	private enum CollisionState { deepPenetration, collision, free }

	private CollisionState predictCollision(Vector3f v)
	{
		foreach(i; 0 .. contactCount)
			if(contactBuffer[i].m_penetration >= maxCollisionPenetration) 
				return CollisionState.deepPenetration;

		foreach(i; 0 .. contactCount)
		{
			float projectionSpeed = dot(v, Vector3f(contactBuffer[i].m_normal[0..3]));
			if(projectionSpeed < 0)
				return CollisionState.collision;
		}

		return CollisionState.free;
	}

	private float predictTimestep(float timestep)
	{
		getTransform;
		AtomicTransform orig = transform;
		Vector3f v = velocity();

		NewtonBodyIntegrateVelocity(handle, timestep);
		CollisionState playerCollisionState = predictCollision(v);
		transform = orig;
		updateMatrix;

		if(playerCollisionState == CollisionState.deepPenetration)
		{
			float savedTimeStep = timestep;
			timestep *= 0.5f;
			float dt = timestep;

			foreach(i; 0 .. maxCollisionSteps)
			{
				integrateVelocity(timestep);
				calculateContacts;
				transform = orig;
				updateMatrix;

				dt *= 0.5f;
				playerCollisionState = predictCollision(v);
				if(playerCollisionState == CollisionState.collision)
					return timestep;
				else if(playerCollisionState == CollisionState.deepPenetration)
					timestep -= dt;
				else timestep += dt;
			}

			if(timestep > dt * 2f)
				return timestep;

			dt = savedTimeStep / maxCollisionSteps;
			timestep = dt;
			foreach(i; 1 .. maxCollisionSteps)
			{
				integrateVelocity(timestep);
				calculateContacts;
				transform = orig;
				updateMatrix;

				playerCollisionState = predictCollision(v);
				if(playerCollisionState != CollisionState.free)
					return timestep;

				timestep += dt;
			}
		}

		return timestep;
	}

	private void resolveInterpenetrations()
	{
		auto zero = Vector4f(0, 0, 0, 0);
		auto savedVelocity = Vector4f(0, 0, 0, 0);
		NewtonBodyGetVelocity(super.handle, savedVelocity.arrayof.ptr);

		float timestep = 0.1f;
		float invTimestep = 1.0f / timestep;

		float penetration = maxCollisionPenetration * 10f;
		for(int j = 0; (j < 8) && (penetration > maxCollisionPenetration); j++)
		{
			Matrix4f m;
			Vector4f com = Vector4f(0, 0, 0, 0);

			NewtonBodySetVelocity(super.handle, zero.arrayof.ptr);
			NewtonBodyGetMatrix(super.handle, m.arrayof.ptr);
			NewtonBodyGetCentreOfMass(super.handle, com.arrayof.ptr);
			com = com * m;
			com.w = 0.0f;

			impulseSolver.reset;
			impulseSolver.addAngularRows();
			for (int i = 0; i < contactCount; i++) {
				NewtonWorldConvexCastReturnInfo* contact = &contactBuffer[i];

				auto point = Vector4f(contact.m_point[0], contact.m_point[1], contact.m_point[2], 0.0f);
				auto normal = Vector4f(contact.m_normal[0], contact.m_normal[1], contact.m_normal[2], 0.0f);

				penetration = clamp(contact.m_penetration - maxCollisionPenetration * 0.5f, 0.0f, 0.5f);
				int index = impulseSolver.addLinearRow(normal.xyz, (point - com).xyz, 0.0f, 0.0f, 1.0e12f);
				impulseSolver.rhs[index] = penetration * invTimestep;
			}

			float invMass = inverseMass()[0];
			auto veloc = Vector3f(impulseSolver.calculateImpulse() * invMass);
			NewtonBodySetVelocity(super.handle, veloc.arrayof.ptr);
			NewtonBodyIntegrateVelocity(super.handle, timestep);

			penetration = 0.0f;
			calculateContacts;
			for (int i = 0; i < contactCount; i++)
				penetration = max(contactBuffer[i].m_penetration, penetration);
		}
	}

	void resolveCollision(float timestep)
	{
		Matrix4f m = matrix();

		calculateContacts;
		if(contactCount == 0) return;

		float maxPenetration = 0f;
		foreach(i; 0 .. contactCount) maxPenetration = max(contactBuffer[i].m_penetration, maxPenetration);
	
		impulseSolver.reset;
		if(maxPenetration > maxCollisionPenetration)
		{
			resolveInterpenetrations;
			m = matrix();
		}

		Vector3f zero = Vector3f(0, 0, 0), com = super.centreOfMass, veloc = super.velocity;
		com = (Vector4f(com.x, com.y, com.z, 0f) * m).xyz;
		
		impulseSolver.reset;
		Vector4f surfaceVeloc = Vector4f(0, 0, 0, 0);
		immutable float contactPatchHigh = contactPatch * 0.995f;
		foreach(i; 0 .. contactCount)
		{
			NewtonWorldConvexCastReturnInfo contact = contactBuffer[i];

			auto point = Vector4f(contact.m_point[0], contact.m_point[1], contact.m_point[2], 0);
			auto normal = Vector4f(contact.m_normal[0], contact.m_normal[1], contact.m_normal[2], 0);
			immutable int normalIndex = impulseSolver.addLinearRow(normal.xyz, point.xyz - com, 0f, 0f, 1.0e12f);

			float invMass, invIxx, invIyy, invIzz;
			NewtonBodyGetPointVelocity(contact.m_hitBody, point.arrayof.ptr, surfaceVeloc.arrayof.ptr);
			impulseSolver.rhs[impulseSolver.rowCount - 1] = dot(surfaceVeloc, normal);

			NewtonBodyGetInvMass(contact.m_hitBody, &invMass, &invIxx, &invIyy, &invIzz);
			NewtonWorldConvexCastReturnInfo otherBodyContact = (invMass > 0f) ? contact : NewtonWorldConvexCastReturnInfo.init;
			impulseSolver.contactPoint[impulseSolver.rowCount - 1] = otherBodyContact;
			impulseSolver.contactPointPresent[impulseSolver.rowCount - 1] = invMass > 0f;

			isAirborne = false;
			Vector4f localPoint = unrotateVector(transform.matrix, point);
			if(localPoint.x < contactPatchHigh)
			{
				onFloor = true;
				float friction = 2.0f; // needs resolver
				if(friction > 0f)
				{
					Vector3f sideDir = cross(transform.matrix.up, normal.xyz).normalized;
					impulseSolver.addLinearRow(sideDir, (point.xyz - com), -lateralSpeed, -friction, friction, normalIndex);
					impulseSolver.rhs[impulseSolver.rowCount-1] += dot(surfaceVeloc.xyz, sideDir);
					impulseSolver.contactPoint[impulseSolver.rowCount-1] = otherBodyContact;

					Vector3f frontDir = cross(normal.xyz, sideDir);
					impulseSolver.addLinearRow(frontDir, (point.xyz - com), -forwardSpeed, -friction, friction, normalIndex);
					impulseSolver.rhs[impulseSolver.rowCount-1] += dot(surfaceVeloc.xyz, frontDir);
					impulseSolver.contactPoint[impulseSolver.rowCount-1] = otherBodyContact;
				}
			}
		}

		impulseSolver.addAngularRows;
		veloc += impulseSolver.calculateImpulse * inverseMass()[0];
		impulseSolver.applyReaction(timestep);

		velocity = veloc;
	}

	void update(float timestep)
	{
		contactCount = 0;
		float timeLeft = timestep;
		immutable float timeEpsilon = timestep * (1 / 16f);

		getTransform;
		transform.rotation.y = headingAngle;
		transform.rotation.x = 0;
		transform.rotation.z = 0;
		updateMatrix;

		Vector3f v = velocity() + impulse * inverseMass()[0];
		velocity = v;

		isAirborne = true;
		onFloor = false;

		for(int i = 0; (i < 4) && (timeLeft > timeEpsilon); i++)
		{
			if(timeLeft > timeEpsilon)
				resolveCollision(timestep);

			float predictedTime = predictTimestep(timeLeft);
			NewtonBodyIntegrateVelocity(handle, predictedTime);
			timeLeft -= predictedTime;
		}
	}

	private Matrix4f matrix() 
	{
		Matrix4f m;
		NewtonBodyGetMatrix(handle, m.arrayof.ptr);
		return m;
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