module moxane.physics.core;

import moxane.core;
import moxane.physics.collider;
import moxane.physics.rigidbody;
import moxane.physics.commands;
import moxane.utils.maybe;

import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.transformation;
import bindbc.newton;

import core.thread;
import core.atomic;
import std.datetime : StopWatch, AutoStart;

import containers.unrolledlist;

@safe:

struct PhysicsComponent
{
	Collider collider;
	Body rigidBody;
}

class PhysicsSystem : System
{
	//package NewtonWorld* handle;

	Vector3f gravity;

	this(Moxane moxane, EntityManager manager) @trusted
	{
		super(moxane, manager);
		//handle = NewtonCreate();
		//NewtonSetNumberOfSubsteps(handle, 10);
	}

	~this() @trusted
	{
		//NewtonDestroy(handle);
		//handle = null;
	}

	override void update() @trusted
	{
		//NewtonUpdate(handle, moxane.deltaTime);

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
	package NewtonWorld* worldHandle;
	Channel!PhysicsCommand queue;

	private shared bool terminated_ = false;
	@property bool terminated() const { return atomicLoad(terminated_); }
	@property void terminated(bool n) { atomicStore(terminated_, n); }

	private shared bool pendTermination_ = false;
	@property bool pendTermination() const { return atomicLoad(pendTermination_); }
	@property void pendTermination(bool n) { atomicStore(pendTermination_, n); }

	//private Tid thread;

	this(Log log)
	{
		queue = new Channel!PhysicsCommand;
		//thread = spawn(&physicsThreadWorker, cast(shared)this, cast(shared)log);
	}

	//void terminate() { thread.send(false); }

	private UnrolledList!Collider colliders;
	private UnrolledList!Body rigidBodies;

	private void worker()
	{
		enum limitMs = 30;
		enum commandWaitTimeMs = 5;
		enum nullCommandHaltNs = 500;

		worldHandle = NewtonCreate();
		scope(exit) NewtonDestroy(worldHandle);

		StopWatch limiter = StopWatch(AutoStart.yes);
		while(!pendTermination)
		{
			StopWatch commandWait = StopWatch(AutoStart.yes);
			while(commandWait.peek().total!"msecs" <= 5)
			{
				Maybe!PhysicsCommand commandWrapped = queue.tryGet;
				if(commandWrapped.isNull)
				{
					Thread.sleep(dur!"usecs"(nullCommandHaltNs));
					continue;
				}

				handleCommand(*commandWrapped.unwrap);
			}
		}
	}

	private void handleCommand(PhysicsCommand command)
	{
		if(command.type == PhysicsCommands.colliderCreate)
		{
			Collider collider = cast(Collider)command.target;
			assert(collider !is null);

			final switch(collider.type) with(ColliderType)
			{
				case none:
					throw new Exception("none type not expected");
					break;
				case box:
					BoxCollider boxc = cast(BoxCollider)collider;
					boxc.handle = NewtonCreateBox(worldHandle, boxc.dimensions.x, boxc.dimensions.y, boxc.dimensions.z, 0, boxc.offset.matrix.arrayof.ptr);
					break;
				case sphere:
					SphereCollider spherec = cast(SphereCollider)collider;
					spherec.handle = NewtonCreateSphere(worldHandle, spherec.radius, 0, spherec.offset.matrix.arrayof.ptr);
					break;
				case staticMesh:
					StaticMeshCollider smc = cast(StaticMeshCollider)collider;
					smc.handle = NewtonCreateTreeCollision(worldHandle, 1);
					for(size_t tidx = 0; tidx < smc.vertexConstArr.length; tidx += 3)
						NewtonTreeCollisionAddFace(smc.handle, 3, &smc.vertexConstArr[tidx].x, Vector3f.sizeof, 1);
					NewtonTreeCollisionEndBuild(handle, cast(int)smc.optimiseMesh);
					smc.freeMemory;
					break;
				case capsule:
					CapsuleCollider cc = cast(CapsuleCollider)collider;
					cc.handle = NewtonCreateCapsule(worldHandle, cc.radius, cc.radius1, cc.height, 0, cc.offset.matrix.arrayof.ptr);
					break;
			}

			if(collider.type != ColliderType.none)
			{
				assert(collider.handle !is null);
				NewtonCollisionSetUserData(collider.handle, cast(void*)collider);
				colliders ~= collider;
			}
		}
		else if(command.type == PhysicsCommands.colliderDestroy)
		{
			Collider collider = cast(Collider)command.target;
			NewtonDestroyCollision(worldHandle, collider.handle);
			colliders.remove(collider);
		}
		else if(command.type == PhysicsCommands.colliderUpdateFields)
		{
			Collider collider = cast(Collider)command.target;
			collider.updateFields;
		}
	}
}

/+private void physicsThreadWorker(shared PhysicsThread threadS, shared Log logS)
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
}+/