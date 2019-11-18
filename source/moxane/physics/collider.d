module moxane.physics.collider;

import moxane.core;
import moxane.physics.core;
import bindbc.newton;
import dlib.math;

@trusted:

abstract class Collider
{
	enum Shape
	{
		box,
	}

	package NewtonCollision* handle;

	PhysicsSystem system;
	this(PhysicsSystem system) in(system !is null) { this.system = system; }

	~this() { NewtonDestroyCollision(handle); handle = null; }

	@property Vector3f scale() const { Vector3f s; NewtonCollisionGetScale(handle, &s.x, &s.y, &s.z); return s; }
	@property void scale(Vector3f s) { NewtonCollisionSetScale(handle, s.x, s.y, s.z); }
} 

class BoxCollider : Collider
{
	Vector3f dimensions;
	Transform offset;

	this(PhysicsSystem system, Vector3f dimensions, Transform offset = Transform.init)
	{
		super(system);
		this.dimensions = dimensions;
		this.offset = offset;
		handle = NewtonCreateBox(system.handle, dimensions.x, dimensions.y, dimensions.z, 0, offset.matrix.arrayof.ptr);
	}
}

class SphereCollider : Collider
{
	float radius;
	Transform offset;

	this(PhysicsSystem system, float radius, Transform offset = Transform.init)
	{
		super(system);
		this.radius = radius;
		this.offset = offset;
		handle = NewtonCreateSphere(system.handle, radius, 0, offset.matrix.arrayof.ptr);
	}
}

class StaticMeshCollider : Collider
{
	this(PhysicsSystem system, Vector3f[] vertices, bool optimiseMesh = false)
	in(vertices.length % 3 == 0, "vertices must be a triangle mesh")
	{
		super(system);
		handle = NewtonCreateTreeCollision(system.handle, 1);
		NewtonTreeCollisionBeginBuild(handle);

		import std.datetime.stopwatch;

		//for(size_t triangleIndex = 0; triangleIndex < vertices.length; triangleIndex += 3)
		//	NewtonTreeCollisionAddFace(handle, 3, &vertices[triangleIndex].x, Vector3f.sizeof, cast(int)(triangleIndex + 1));
		
		auto additionSw = StopWatch(AutoStart.yes);
		for(size_t tidx = 0; tidx < vertices.length; tidx += 3)
			NewtonTreeCollisionAddFace(handle, 3, &vertices[tidx].x, Vector3f.sizeof, 1);
		additionSw.stop;

		auto endSw = StopWatch(AutoStart.yes);
		NewtonTreeCollisionEndBuild(handle, cast(int)optimiseMesh);
		endSw.stop;

		import std.stdio;
		write("Physics add time: ");
		write(additionSw.peek.total!"nsecs" / 1_000_000f);
		write("ms. End time: ");
		write(endSw.peek.total!"nsecs" / 1_000_000f);
		writeln("ms.");
	}
}

class CapsuleCollider : Collider
{
	const float radius;
	const float radius1;
	const float height;
	const Transform offset;

	this(PhysicsSystem system, float radius, float radius1, float height, Transform offset = Transform.init)
	{
		super(system);
		this.radius = radius;
		this.radius1 = radius1;
		this.height = height;
		this.offset = offset;
		handle = NewtonCreateCapsule(system.handle, radius, radius1, height, 0, offset.matrix.arrayof.ptr);
	}
}