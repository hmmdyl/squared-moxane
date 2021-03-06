module moxane.physics.collider;

import moxane.core;
import moxane.physics.core;
import moxane.physics.commands;
import bindbc.newton;
import dlib.math;
import moxane.utils.sharedwrap;

import core.atomic;

@trusted:

abstract class Collider
{
	package NewtonCollision* handle;

	PhysicsSystem system;
	this(PhysicsSystem system) 
	in(system !is null) 
	{
		this.system = system; 
		this.system.issueCommand(PhysicsCommand(PhysicsCommands.colliderCreate, this)); 
	
		scale = Vector3f(1, 1, 1);
	}

	final void destroy() { system.issueCommand(PhysicsCommand(PhysicsCommands.colliderCreate, this)); }

	void initialise() { NewtonCollisionSetUserData(handle, cast(void*)this); }
	void deinitialise() {}

	mixin(SharedProperty!(Vector3f, "scale"));

	package void updateFields()
	{
		auto s = scale;
		NewtonCollisionSetScale(handle, s.x, s.y, s.z);
	}
} 

class BoxCollider : Collider
{
	const Vector3f dimensions;
	const Transform offset;

	this(PhysicsSystem system, Vector3f dimensions, Transform offset = Transform.init)
	{
		super(system);
		this.dimensions = dimensions;
		this.offset = offset;
	}

	override void initialise()
	{
		handle = NewtonCreateBox(system.worldHandle, dimensions.x, dimensions.y, dimensions.z, 0, offset.matrix.arrayof.ptr);
		super.initialise;
	}
}

class SphereCollider : Collider
{
	const float radius;
	const Transform offset;

	this(PhysicsSystem system, float radius, Transform offset = Transform.init)
	{
		super(system);
		this.radius = radius;
		this.offset = offset;
	}

	override void initialise() 
	{
		handle = NewtonCreateSphere(system.worldHandle, radius, 0, offset.matrix.arrayof.ptr);
		super.initialise;
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
		this.optimiseMesh = optimiseMesh;
		this.duplicateArray = dupMem;

		if(dupMem)
		{
			import std.experimental.allocator.mallocator;
			import std.algorithm : each;
			vertexConstArr = cast(Vector3f[])Mallocator.instance.allocate(Vector3f.sizeof * vertices.length);
			assert(vertexConstArr !is null);
			assert(vertexConstArr.length == vertices.length);
			
			size_t i;
			vertices.each!(v => vertexConstArr[i++] = v);
		}
		else
			this.vertexConstArr = vertices;

		super(system);
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

	bool initted = false;
	override void initialise() 
	{
		if(initted) return;

		scope(exit) initted = true;

		import std.datetime.stopwatch;

		handle = NewtonCreateTreeCollision(system.worldHandle, 1);
		NewtonTreeCollisionBeginBuild(handle);

		// slow
		for(size_t tidx = 0; tidx < vertexConstArr.length; tidx += 3)
			NewtonTreeCollisionAddFace(handle, 3, &vertexConstArr[tidx].x, Vector3f.sizeof, 1);

		NewtonTreeCollisionEndBuild(handle, cast(int)false);

		freeMemory;
		super.initialise;
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
	}

	override void initialise() 
	{
		handle = NewtonCreateCapsule(system.worldHandle, radius, radius1, height, 0, offset.matrix.arrayof.ptr);
		super.initialise;
	}

}