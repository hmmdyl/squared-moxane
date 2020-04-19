module moxane.graphics.redo.resources.lights;

import dlib.math.vector;

enum ShadowAllocation
{
	none,
	required,
	ifAvailable
}

class PointLight
{
	Vector3f position;
	Vector3f colour;

	float ambientIntensity;
	float diffuseIntensity;

	float constAtt, linAtt, expAtt;
}

class DirectionalLight
{
	Vector3f direction;
	Vector3f colour;

	float ambientIntensity;
	float diffuseIntensity;
}