module moxane.physics.collider;

import moxane.core;
import moxane.physics.core;
import moxane.physics.commands;
import bindbc.newton;
import dlib.math;

import core.atomic;

@trusted:

enum ColliderType
{
	none,
	box,
	sphere,
	staticMesh,
	capsule
}

abstract class Collider
{
	package NewtonCollision* handle;
	immutable ColliderType type;

	PhysicsSystem system;
	this(PhysicsSystem system, immutable ColliderType type) 
	in(system !is null) 
	{
		this.type = type;
		this.system = system; 
		this.system.issueCommand(PhysicsCommand(PhysicsCommands.colliderCreate, this)); 
	}

	~this() { system.issueCommand(PhysicsCommand(PhysicsCommands.colliderCreate, this)); }

	private shared Vector3f scale_;
	/+@property Vector3f scale() const { return atomicLoad(scale_); }
	@property void scale(Vector3f s) { atomicStore(scale_, s); system.issueCommand(PhysicsCommand(PhysicsCommands.colliderUpdateFields, this)); }

	package void updateFields()
	{
		auto s = scale;
		NewtonCollisionSetScale(handle, s.x, s.y, s.z);
	}+/
} 

class BoxCollider : Collider
{
	Vector3f dimensions;
	Transform offset;

	this(PhysicsSystem system, Vector3f dimensions, Transform offset = Transform.init)
	{
		super(system, ColliderType.box);
		this.dimensions = dimensions;
		this.offset = offset;
		//handle = NewtonCreateBox(system.handle, dimensions.x, dimensions.y, dimensions.z, 0, offset.matrix.arrayof.ptr);
	}
}

class SphereCollider : Collider
{
	float radius;
	Transform offset;

	this(PhysicsSystem system, float radius, Transform offset = Transform.init)
	{
		super(system, ColliderType.sphere);
		this.radius = radius;
		this.offset = offset;
		//handle = NewtonCreateSphere(system.handle, radius, 0, offset.matrix.arrayof.ptr);
	}
}

class StaticMeshCollider : Collider
{
	package bool duplicateArray;
	package Vector3f[] vertexConstArr;
	
	bool optimiseMesh;

	this(PhysicsSystem system, Vector3f[] vertices, bool dupMem = true, bool optimiseMesh = false)
	in(vertices.length % 3 == 0, "vertices must be a triangle mesh")
	{
		super(system, ColliderType.staticMesh);
		this.optimiseMesh = optimiseMesh;
		this.duplicateArray = dupMem;

		if(dupMem)
		{
			import std.experimental.allocator.mallocator;
			import std.algorithm : each;
			vertexConstArr = cast(Vector3f[])Mallocator.instance.allocate(Vector3f.sizeof * vertices.length);
			size_t i;
			vertices.each!(v => vertexConstArr[i++] = v);
		}
		else
			this.vertexConstArr = vertices;

		/+handle = NewtonCreateTreeCollision(system.handle, 1);
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
		writeln("ms.");+/
	}

	package void freeMemory()
	{
		if(duplicateArray)
		{
			import std.experimental.allocator.mallocator;
			Mallocator.instance.deallocate(vertexConstArr);
		}
		vertexConstArr = null;
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
		super(system, ColliderType.capsule);
		this.radius = radius;
		this.radius1 = radius1;
		this.height = height;
		this.offset = offset;
		//handle = NewtonCreateCapsule(system.handle, radius, radius1, height, 0, offset.matrix.arrayof.ptr);
	}
}