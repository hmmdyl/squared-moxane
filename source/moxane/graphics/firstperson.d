module moxane.graphics.firstperson;

import moxane.graphics.renderer;

import dlib.math;
import std.math : sin, cos;

@safe:

class FirstPersonCamera : Camera
{
	void moveOnAxes(Vector3f vec)
	{
		// strafe
		float yr = degtorad(rotation.y);
		position.x += cos(yr) * vec.x;
		position.z += sin(yr) * vec.x;

		// forward
		position.x += sin(yr) * vec.z;
		position.z -= cos(yr) * vec.z;

		position.y += vec.y;
	}

	void rotate(Vector3f vec) 
	{
		rotation += vec;

		if(rotation.x > 90f)
			rotation.x = 90f;
		if(rotation.x < -90f)
			rotation.x = -90f;
		if(rotation.y > 360f)
			rotation.y -= 360f;
		if(rotation.y < 0f)
			rotation.y += 360f;
	}
}