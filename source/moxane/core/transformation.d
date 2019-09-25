module moxane.core.transformation;

import dlib.math;

@safe @nogc:

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
		return makeMatrix(position, rotation, scale);
	}
}

Matrix4f makeMatrix(Vector3f position, Vector3f rotation, Vector3f scale)
{
	Matrix4f m = translationMatrix(position);
	m *= rotationMatrix(Axis.x, degtorad(rotation.x));
	m *= rotationMatrix(Axis.y, degtorad(rotation.y));
	m *= rotationMatrix(Axis.z, degtorad(rotation.z));
	m *= scaleMatrix(scale);
	return m;
}