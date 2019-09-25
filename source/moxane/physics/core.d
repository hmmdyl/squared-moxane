module moxane.physics.core;

import moxane.core;

import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.transformation;
import bindbc.newton;

class PhysicsSystem
{
	package NewtonWorld* handle;

	Vector3f gravity;
}