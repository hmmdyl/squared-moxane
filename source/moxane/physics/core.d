module moxane.physics.core;

import moxane.core;
import moxane.physics.collider;
import moxane.physics.rigidbody;
import moxane.physics.commands;
import moxane.utils.maybe;
import moxane.utils.sharedwrap;

import dlib.math.vector;
import bindbc.newton;

import core.thread;
import core.atomic;
import std.datetime.stopwatch;

import containers.unrolledlist;

@safe:

struct PhysicsComponent
{
	Collider collider;
	Body rigidBody;
}

class PhysicsSystem : System
{
	private PhysicsThread physicsThread;
	package NewtonWorld* worldHandle() { return physicsThread.worldHandle; }

	mixin(SharedProperty!(Vector3f, "gravity"));

	this(Moxane moxane, EntityManager manager) @trusted
	{
		super(moxane, manager);
		physicsThread = new PhysicsThread(moxane.services.get!Log);
	}

	~this()
	{
		physicsThread.pendTermination = true;
	}

	override void update() @trusted
	{
		auto entities = entityManager.entitiesWith!(PhysicsComponent, Transform);
		foreach(Entity entity; entities)
		{
			Transform* transform = entity.get!Transform;
			PhysicsComponent* phys = entity.get!PhysicsComponent;

			*transform = Transform(phys.rigidBody.transform);
		}
	}

	package void issueCommand(PhysicsCommand comm) 
	{ physicsThread.queue.send(comm); }
}

private class PhysicsThread
{
	NewtonWorld* worldHandle;
	Channel!PhysicsCommand queue;

	private shared bool terminated_ = false;
	@property bool terminated() const { return atomicLoad(terminated_); }
	@property void terminated(bool n) { atomicStore(terminated_, n); }

	private shared bool pendTermination_ = false;
	@property bool pendTermination() const { return atomicLoad(pendTermination_); }
	@property void pendTermination(bool n) { atomicStore(pendTermination_, n); }

	private Thread thread;

	this(Log log) @trusted
	{
		queue = new Channel!PhysicsCommand;

		thread = new Thread(&worker);
		thread.name = PhysicsThread.stringof;
		thread.isDaemon = true;
		thread.start;
	}

	private UnrolledList!Collider colliders;
	private UnrolledList!BodyMT rigidBodies;

	private void worker() @trusted
	{
		enum limitMs = 30;
		enum commandWaitTimeMs = 5;
		enum nullCommandHaltNs = 500;
		enum limiterHaltNs = 500;

		worldHandle = NewtonCreate();
		assert(worldHandle !is null);
		scope(exit) NewtonDestroy(worldHandle);

		double deltaTime = 1.0 / (limitMs / 1000.0);

		StopWatch limiter = StopWatch(AutoStart.yes);
		while(!pendTermination)
		{
			limiter.start;

			StopWatch commandWait = StopWatch(AutoStart.yes);
			while(commandWait.peek.total!"msecs" <= 5)
			{
				Maybe!PhysicsCommand commandWrapped = queue.tryGet;
				if(commandWrapped.isNull)
				{
					Thread.sleep(dur!"usecs"(nullCommandHaltNs));
					continue;
				}

				handleCommand(*commandWrapped.unwrap);
			}

			foreach(BodyMT b; rigidBodies)
				b.updateFields(deltaTime);

			NewtonUpdate(worldHandle, cast(float)deltaTime);

			while(limiter.peek.total!"msecs" < 30)
				Thread.sleep(dur!"usecs"(limiterHaltNs));

			limiter.stop;
			deltaTime = limiter.peek.total!"nsecs" * (1.0 / 1_000_000_000.0);
			limiter.reset;
		}
	}

	private void handleCommand(PhysicsCommand command) @trusted
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
					NewtonTreeCollisionEndBuild(smc.handle, cast(int)smc.optimiseMesh);
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
			NewtonDestroyCollision(collider.handle);
			colliders.remove(collider);
		}
		else if(command.type == PhysicsCommands.rigidBodyCreate)
		{
			BodyMT b = cast(BodyMT)command.target;
			b.initialise;
			rigidBodies ~= b;
		}
		else if(command.type == PhysicsCommands.rigidBodyDestroy)
		{
			BodyMT b = cast(BodyMT)command.target;
			b.deinitialise;
			rigidBodies.remove(b);
		}
	}
}