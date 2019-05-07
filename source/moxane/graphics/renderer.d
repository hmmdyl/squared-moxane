module moxane.graphics.renderer;

import moxane.core.eventwaiter;

import dlib.math;

class Camera
{
	Vector3f position;
	Vector3f rotation;
	Matrix4f matrix;
}

class Renderer 
{
	Camera primaryCamera;

	void preShadowPass()
	{

	}

	void postShadowPass()
	{

	}

	void shadowPass()
	{
		preShadowPass;
		scope(exit) postShadowPass;


	}

	void pointLights()
	{

	}

	void directionalLights()
	{

	}

	void lightPass()
	{

	}

	void postProcessPass()
	{

	}

	void render()
	{

	}
}