module moxane.physics.core;

import moxane.core;
import moxane.physics.collider;
import moxane.physics.rigidbody;
import moxane.physics.commands;

import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.transformation;
import bindbc.newton;

import std.concurrency;
import core.atomic;

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
		NewtonSetNumberOfSubsteps(handle, 10);
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

			*transform = Transform(phys.rigidBody.transform);
		}
	}

	package void issueCommand(PhysicsCommand comm) {}
}

private class PhysicsThread
{
	Channel!PhysicsCommand queue;

	private shared bool terminated_ = false;
	@property bool terminated() const { return atomicLoad(terminated_); }
	@property void terminated(bool n) { atomicStore(terminated_, n); }

	private Tid thread;

	this(Log log)
	{
		queue = new Channel!PhysicsCommand;
		thread = spawn(&physicsThreadWorker, cast(shared)this, cast(shared)log);
	}

	void terminate() { thread.send(false); }
}

private void physicsThreadWorker(shared PhysicsThread threadS, shared Log logS)
{
	PhysicsThread thread = cast(PhysicsThread)threadS;
	Log log = cast(Log)logS;

	log.write(Log.Severity.info, "Physics thread started.");
	scope(failure) log.write(Log.Severity.panic, "Panic in physics thread.");
	scope(success) log.write(Log.Severity.info, "Physics thread terminated.");

	while(!thread.terminated)
	{
		receive(
			(bool m)
			{
				if(!m)
				{
					thread.terminated = true;
					return;
				}


			}
		);
	}
}