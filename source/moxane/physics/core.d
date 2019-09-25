module moxane.physics.core;

import moxane.core;
import moxane.physics.collider;
import moxane.physics.rigidbody;

import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.transformation;
import bindbc.newton;

struct PhysicsComponent
{
	Collider collider;
	Body rigidBody;
}

class PhysicsSystem : System
{
	Moxane moxane;

	package NewtonWorld* handle;

	Vector3f gravity;

	this(Moxane moxane, EntityManager manager)
	{
		super(moxane, manager);
		handle = NewtonCreate();
	}

	~this()
	{
		NewtonDestroy(handle);
		handle = null;
	}

	override void update()
	{
		NewtonUpdate(handle, moxane.deltaTime);

		auto entities = entityManager.entitiesWith!(PhysicsComponent, Transform);
		foreach(Entity entity; entities)
		{
			Transform* transform = entity.get!Transform;
			PhysicsComponent* phys = entity.get!PhysicsComponent;

			*transform = *phys.rigidBody.transform;
		}
	}
}