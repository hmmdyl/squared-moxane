module moxane.graphics.effect;

import derelict.opengl3.gl3;
import dlib.math;

import moxane.core.engine;
import moxane.core.log;
import moxane.graphics.log;

struct EffectUniform
{
	string name;
	GLint location;

	this(string name, GLint location)
	{
		this.name = name;
		this.location = location;
	}

	public void set(bool v) { glUniform1i(location, cast(int)v); }

	public void set(int v) { glUniform1i(location, v); }
	public void set(uint v) { glUniform1ui(location, v); }
	public void set(float v) { glUniform1f(location, v); }
	public void set(double v) { glUniform1d(location, v); }

	public void set(Vector2f v) { glUniform2f(location, v.x, v.y); }
	public void set(Vector2f* v) { glUniform2fv(location, 1, v.ptr); }
	public void set(Vector2d v) { glUniform2d(location, v.x, v.y); }
	public void set(Vector2d* v) { glUniform2dv(location, 1, v.ptr); }

	public void set(Vector3f v) { glUniform3f(location, v.x, v.y, v.z); }
	public void set(Vector3f* v) { glUniform3fv(location, 1, v.ptr); }
	public void set(Vector3d v) { glUniform3d(location, v.x, v.y, v.z); }
	public void set(Vector3d* v) { glUniform3dv(location, 1, v.ptr); }

	public void set(Vector4f v) { glUniform4f(location, v.x, v.y, v.z, v.w); }
	public void set(Vector4f* v) { glUniform4fv(location, 1, v.ptr); }
	public void set(Vector4d v) { glUniform4d(location, v.x, v.y, v.z, v.w); }
	public void set(Vector4d* v) { glUniform4dv(location, 1, v.ptr); }

	public void set(Matrix4f* m, bool transpose = false) { glUniformMatrix4fv(location, 1, transpose, m.ptr); }
}

class Shader
{
	GLuint id;

	void compileFromSource(string source)
	{

	}

	void compileFromFile(string filename)
	{

	}
}