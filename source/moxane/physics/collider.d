module moxane.physics.collider;

import moxane.core;
import moxane.physics.core;
import moxane.physics.commands;
import bindbc.newton;
import dlib.math;
import moxane.utils.sharedwrap;

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
	
		scale = Vector3f(1, 1, 1);
	}

	~this() { system.issueCommand(PhysicsCommand(PhysicsCommands.colliderCreate, this)); }

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
		super(system, ColliderType.box);
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
		super(system, ColliderType.sphere);
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

	override void initialise() 
	{
		handle = NewtonCreateTreeCollision(system.worldHandle, 1);
		for(size_t tidx = 0; tidx < vertexConstArr.length; tidx += 3)
			NewtonTreeCollisionAddFace(handle, 3, &vertexConstArr[tidx].x, Vector3f.sizeof, 1);
		NewtonTreeCollisionEndBuild(handle, cast(int)optimiseMesh);
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
		super(system, ColliderType.capsule);
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