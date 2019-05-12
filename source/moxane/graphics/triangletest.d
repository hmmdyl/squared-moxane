module moxane.graphics.triangletest;

import moxane.core.engine;
import moxane.core.asset;

import moxane.graphics.renderer;
import moxane.graphics.effect;
import moxane.graphics.gl;
import moxane.graphics.effect;

import dlib.math;
import derelict.opengl3.gl3;

class TriangleTest : IRenderable
{
	Moxane moxane;
	GLuint vao;
	GLuint[2] buffers;

	Effect effect;

	this(Moxane moxane)
	{
		this.moxane = moxane;

		glGenVertexArrays(1, &vao);
		glGenBuffers(2, buffers.ptr);

		Vector2f[] vertices = 
		[
			Vector2f(-1f, -1f),
			Vector2f(0f, 1f),
			Vector2f(1f, -1)
		];
		Vector3f[] colours = 
		[
			Vector3f(1f, 0f, 0f),
			Vector3f(0f, 1f, 0f),
			Vector3f(0f, 0f, 1f)
		];

		glBindBuffer(GL_ARRAY_BUFFER, buffers[0]);
		glBufferData(GL_ARRAY_BUFFER, vertices.length * Vector2f.sizeof, vertices.ptr, GL_STREAM_DRAW);
		glBindBuffer(GL_ARRAY_BUFFER, buffers[1]);
		glBufferData(GL_ARRAY_BUFFER, colours.length * Vector3f.sizeof, colours.ptr, GL_STATIC_DRAW);
		glBindBuffer(GL_ARRAY_BUFFER, 0);

		AssetManager am = moxane.services.get!AssetManager;
		Shader vs = am.uniqueLoad!Shader("content/shaders/triangleTest.vs.glsl");
		Shader fs = am.uniqueLoad!Shader("content/shaders/triangleTest.fs.glsl");
		effect = new Effect(moxane, TriangleTest.stringof ~ "Effect");
		effect.attachAndLink(vs, fs);
	}

	void render(Renderer renderer, ref LocalContext lc)
	{
		effect.bind;
		scope(exit) effect.unbind;

		glBindVertexArray(vao);
		scope(exit) glBindVertexArray(0);

		glEnableVertexAttribArray(0);
		glEnableVertexAttribArray(1);
		scope(exit)
		{
			glDisableVertexAttribArray(0);
			glDisableVertexAttribArray(1);
		}

		glBindBuffer(GL_ARRAY_BUFFER, buffers[0]);
		glVertexAttribPointer(0, 2, GL_FLOAT, false, 0, null);
		glBindBuffer(GL_ARRAY_BUFFER, buffers[1]);
		glVertexAttribPointer(1, 3, GL_FLOAT, false, 0, null);
		glBindBuffer(GL_ARRAY_BUFFER, 0);

		glDrawArrays(GL_TRIANGLES, 0, 3);
	}
}