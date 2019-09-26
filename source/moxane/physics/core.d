module moxane.physics.core;

import moxane.core;
import moxane.physics.collider;
import moxane.physics.rigidbody;

import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.transformation;
import bindbc.newton;

@safe:

struct PhysicsComponent
{
	Collider collider;
	Body rigidBody;
}

class PhysicsSystem : System
{
	package NewtonWorld* handle;

	Vector3f gravity;

	this(Moxane moxane, EntityManager manager) @trusted
	{
		super(moxane, manager);
		handle = NewtonCreate();
	}

	~this() @trusted
	{
		NewtonDestroy(handle);
		handle = null;
	}

	override void update() @trusted
	{
		NewtonUpdate(handle, moxane.deltaTime);

		auto entities = entityManager.entitiesWith!(PhysicsComponent, Transform);
		foreach(Entity entity; entities)
		{
			Transform* transform = entity.get!Transform;
			PhysicsComponent* phys = entity.get!PhysicsComponent;

			*transform = phys.rigidBody.transform;
		}
	}
}