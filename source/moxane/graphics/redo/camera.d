module moxane.graphics.redo.camera;

import dlib.math;

@safe class Camera
{
	Vector3f position;
	Vector3f rotation;
	Matrix4f viewMatrix;

	struct Ortho
	{
		float left, right, top, bottom, near, far;
	}
	struct Perspective
	{
		float fieldOfView, near, far;
	}
	union
	{
		Ortho ortho;
		Perspective perspective;
	}
	bool isOrtho;
	Matrix4f projection;

	uint width, height;

	void buildView()
	{
		viewMatrix = translationMatrix(-position);
		viewMatrix = rotationMatrix(Axis.z, degtorad(-rotation.z)) * viewMatrix;
		viewMatrix = rotationMatrix(Axis.y, degtorad(-rotation.y)) * viewMatrix;
		viewMatrix = rotationMatrix(Axis.x, degtorad(-rotation.x)) * viewMatrix;
	}

	void deduceOrtho()
	{
		ortho.left = 0f;
		ortho.right = cast(float)width;
		ortho.bottom = cast(float)height;
		ortho.top = 0f;
		isOrtho = true;
	}

	void buildProjection()
	{
		if(isOrtho)
			projection = orthoMatrix(ortho.left, ortho.right, ortho.bottom, ortho.top, ortho.near, ortho.far);
		else
			projection = perspectiveMatrix(perspective.fieldOfView, cast(float)width / cast(float)height, perspective.near, perspective.far);
	}
}


@safe class FirstPersonCamera : Camera
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