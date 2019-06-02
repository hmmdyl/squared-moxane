module moxane.graphics.sprite;

import moxane.core : Moxane, Log;
import moxane.core.asset;
import moxane.graphics.renderer;
import moxane.graphics.texture;
import moxane.graphics.effect;
import moxane.graphics.log;

import dlib.math;

import derelict.opengl3.gl3;

import std.exception : enforce;
import std.file : readText;

final class SpriteRenderer : IRenderable
{
	private struct SpriteOrder
	{
		Vector2i position;
		Vector2i dimensions;
		Texture2D texture;
		Vector3f colour;
		float alpha;
		bool mixAlpha;
	}
	private SpriteOrder[] orders;

	void drawSprite(Vector2i position, Vector2i dimensions, Vector3f colour, float alpha = 1.0f, bool mixAlpha = false)
	{ drawSprite(position, dimensions, null, colour, alpha, mixAlpha); }

	void drawSprite(Vector2i position, Vector2i dimensions, Texture2D texture, Vector3f colour = Vector3f(1f, 1f, 1f), float alpha = 1f, bool mixAlpha = true)
	{
		SpriteOrder order = {
			position : position,
			dimensions : dimensions,
			texture : texture,
			colour : colour,
			alpha : alpha,
			mixAlpha : mixAlpha
		};
		orders ~= order;
	}

	Moxane moxane;
	Renderer renderer;
	
	private uint vao, vbo;
	private Effect effect;

	private enum vertexCount = 6;

	this(Moxane moxane, Renderer renderer) @trusted
	{
		this.moxane = moxane;
		this.renderer = renderer;

		const Vector2f[] verts = [
			Vector2f(0, 0),
			Vector2f(1, 0),
			Vector2f(1, 1),
			Vector2f(1, 1),
			Vector2f(0, 1),
			Vector2f(0, 0)
		];

		glGenVertexArrays(1, &vao);
		glGenBuffers(1, &vbo);
		glBindBuffer(GL_ARRAY_BUFFER, vbo);
		glBufferData(GL_ARRAY_BUFFER, verts.length * Vector2f.sizeof, verts.ptr, GL_STATIC_DRAW);
		glBindBuffer(GL_ARRAY_BUFFER, 0);

		Log log = moxane.services.getAOrB!(GraphicsLog, Log);
		Shader vs = new Shader, fs = new Shader;
		enforce(vs.compile(readText(AssetManager.translateToAbsoluteDir("content/shaders/moxane/sprite.vs.glsl")), GL_VERTEX_SHADER, log));
		enforce(fs.compile(readText(AssetManager.translateToAbsoluteDir("content/shaders/moxane/sprite.fs.glsl")), GL_FRAGMENT_SHADER, log));
		effect = new Effect(moxane, SpriteRenderer.stringof);
		effect.attachAndLink(vs, fs);
		effect.bind;
		effect.findUniform("Position");
		effect.findUniform("Dimensions");
		effect.findUniform("MVP");
		effect.findUniform("Texture");
		effect.findUniform("UseTexture");
		effect.findUniform("Colour");
		effect.findUniform("MixAlpha");
		effect.unbind;
	}

	void render(Renderer renderer, ref LocalContext lc, out uint drawCalls, out uint numVerts)
	{
		scope(success) orders.length = 0;

		glBindVertexArray(vao);
		scope(exit) glBindVertexArray(0);
		glEnableVertexAttribArray(0);
		scope(exit) glDisableVertexAttribArray(0);
		effect.bind;
		scope(exit) effect.unbind;

		Matrix4f mvp = lc.projection * lc.view * lc.model;
		effect["MVP"].set(&mvp);

		glBindBuffer(GL_ARRAY_BUFFER, vbo);
		glVertexAttribPointer(0, 2, GL_FLOAT, false, 0, null);
		glBindBuffer(GL_ARRAY_BUFFER, 0);

		glActiveTexture(0);

		foreach(ref SpriteOrder order; orders)
		{
			if(order.texture !is null) order.texture.bind;
			scope(exit) if(order.texture !is null) order.texture.unbind;

			effect["Position"].set(order.position);
			effect["Dimensions"].set(order.dimensions);
			effect["Texture"].set(0);
			effect["UseTexture"].set(order.texture !is null);
			effect["Colour"].set(Vector4f(order.colour.x, order.colour.y, order.colour.z, order.alpha));
			effect["MixAlpha"].set(order.alpha);

			glDrawArrays(GL_TRIANGLES, 0, vertexCount);
		}
	}
}