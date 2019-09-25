module moxane.physics.collider;

import moxane.core;
import moxane.physics.core;
import bindbc.newton;
import dlib.math;

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
		handle = NewtonCreateBox(system.handle, dimensions.x, dimensions.y, dimensions.z, 1, offset.matrix.arrayof.ptr);
	}
}

class StaticMeshCollider : Collider
{
	this(PhysicsSystem system, Vector3f[] vertices, bool optimiseMesh = true)
	in(vertices.length % 3 == 0, "vertices must be a triangle mesh")
	{
		super(system);
		handle = NewtonCreateTreeCollision(system.handle, 1);
		NewtonTreeCollisionBeginBuild(handle);

		for(size_t triangleIndex = 0; triangleIndex < vertices.length; triangleIndex += 3)
			NewtonTreeCollisionAddFace(handle, 3, &vertices[triangleIndex].x, Vector3f.sizeof, cast(int)(triangleIndex + 1));
		
		NewtonTreeCollisionEndBuild(handle, cast(int)optimiseMesh);
	}
}