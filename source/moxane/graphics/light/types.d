module moxane.graphics.light.types;

import dlib.math.vector;

enum ShadowAllocation
{
	none,
	must,
	available
}

struct PointLight
{
	Vector3f position;
	Vector3f colour;

	float ambientIntensity;
	float diffuseIntensity;

	float constAtt, linAtt, expAtt;
}

struct DirectionalLight
{
	Vector3f direction;
	Vector3f colour;

	float ambientIntensity;
	float diffuseIntensity;
}