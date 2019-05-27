module moxane.graphics.transformation;

import dlib.math;

@safe:

struct Transform
{
	Vector3f position;
	Vector3f rotation;
	Vector3f scale;

	static Transform init()
	{
		Transform t;
		t.position = Vector3f(0f, 0f, 0f);
		t.rotation = Vector3f(0f, 0f, 0f);
		t.scale = Vector3f(1f, 1f, 1f);
		return t;
	}

	@property Matrix4f matrix() @trusted
	{
		Matrix4f m = translationMatrix(-position);
		m *= rotationMatrix(Axis.x, degtorad(rotation.x));
		m *= rotationMatrix(Axis.y, degtorad(rotation.y));
		m *= rotationMatrix(Axis.z, degtorad(rotation.z));
		m *= scaleMatrix(scale);
		return m;
	}
}