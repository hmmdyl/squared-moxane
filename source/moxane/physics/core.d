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

@Component 
struct PhysicsComponent
{
	Collider collider;
	BodyRootMT rigidBody;
}

class PhysicsSystem : System
{
	private PhysicsThread physicsThread;
	package NewtonWorld* worldHandle() { return physicsThread.worldHandle; }

	ref EventWaiter!PhysicsCommand addEvent() { return physicsThread.addEvent; }

	@property float deltaTime() const { return physicsThread.deltaTime; }

	mixin(SharedProperty!(Vector3f, "gravity"));

	this(Moxane moxane, EntityManager manager) @trusted
	{
		super(moxane, manager);
		physicsThread = new PhysicsThread(moxane.services.get!Log);

		gravity = Vector3f(0, 10, 0);
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

	EventWaiter!PhysicsCommand addEvent;

	private shared bool terminated_ = false;
	@property bool terminated() const { return atomicLoad(terminated_); }
	@property void terminated(bool n) { atomicStore(terminated_, n); }

	private shared bool pendTermination_ = false;
	@property bool pendTermination() const { return atomicLoad(pendTermination_); }
	@property void pendTermination(bool n) { atomicStore(pendTermination_, n); }

	private Thread thread;

	Log log;

	this(Log log) @trusted
	{
		this.log = log;
		queue = new Channel!PhysicsCommand;

		thread = new Thread(&worker);
		thread.name = PhysicsThread.stringof;
		thread.isDaemon = true;
		thread.start;
	}

	private UnrolledList!Collider colliders;
	private UnrolledList!BodyRootMT rigidBodies;

	float deltaTime = 0f;

	private void worker() @trusted
	{
		enum limitMs = 30;
		enum commandWaitTimeMs = 5;
		enum nullCommandHaltNs = 500;
		enum limiterHaltNs = 500;

		worldHandle = NewtonCreate();
		NewtonSetNumberOfSubsteps(worldHandle, 10);
		assert(worldHandle !is null);

		scope(exit) NewtonDestroy(worldHandle);

		StopWatch limiter = StopWatch(AutoStart.yes);
		while(!pendTermination)
		{
			limiter.start;

			StopWatch commandWait = StopWatch(AutoStart.yes);
			/+while(commandWait.peek.total!"msecs" <= 1)
			{
				Maybe!PhysicsCommand commandWrapped = queue.tryGet;
				if(commandWrapped.isNull)
				{
					Thread.sleep(dur!"usecs"(nullCommandHaltNs));
					continue;
				}

				handleCommand(*commandWrapped.unwrap);
			}
			commandWait.reset;+/

			Maybe!PhysicsCommand commandWrapped = queue.tryGet;
			if(!commandWrapped.isNull)
			{
				handleCommand(*commandWrapped.unwrap);
			}

			foreach(BodyRootMT b; rigidBodies)
				b.updateFields(deltaTime);
			foreach(Collider c; colliders)
				c.updateFields();

			// limiter
			//while(limiter.peek.total!"msecs" < 30)
			//	Thread.sleep(dur!"usecs"(limiterHaltNs));

			NewtonUpdate(worldHandle, deltaTime);

			limiter.stop;
			deltaTime = limiter.peek.total!"nsecs" * (1f / 1_000_000_000f);
			limiter.reset;
		}
	}

	private void handleCommand(PhysicsCommand command) @trusted
	{
		import std.stdio;
		if(command.type == PhysicsCommands.colliderCreate)
		{
			Collider collider = cast(Collider)command.target;
			assert(collider !is null);

			collider.initialise;
			colliders ~= collider;

			addEvent.emit(command);
		}
		else if(command.type == PhysicsCommands.colliderDestroy)
		{
			Collider collider = cast(Collider)command.target;
			NewtonDestroyCollision(collider.handle);
			colliders.remove(collider);
		}
		else if(command.type == PhysicsCommands.rigidBodyCreate)
		{
			BodyRootMT b = cast(BodyRootMT)command.target;
			b.initialise;
			rigidBodies ~= b;
		}
		else if(command.type == PhysicsCommands.rigidBodyDestroy)
		{
			BodyRootMT b = cast(BodyRootMT)command.target;
			b.deinitialise;
			rigidBodies.remove(b);
		}
	}
}