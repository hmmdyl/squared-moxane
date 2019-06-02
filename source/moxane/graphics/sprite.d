module moxane.graphics.sprite;

import moxane.core : Moxane, Log;
import moxane.core.asset;
import moxane.graphics.renderer;
import moxane.graphics.texture;
import moxane.graphics.effect;
import moxane.graphics.log;

import dlib.math;

import derelict.opengl3.gl3;
import derelict.freetype.ft;

import std.exception : enforce;
import std.file : readText;
import std.typecons;

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
	private SpriteOrder[] spriteOrders;

	private struct TextSpriteOrder
	{
		SpriteFont font;
		string text;
		Vector2i position;
		Vector3f colour;
		float alpha;
		float scale;
	}
	private TextSpriteOrder[] textSpriteOrders;

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
		spriteOrders ~= order;
	}

	void drawText(string text, SpriteFont font, Vector2i position, Vector3f colour = Vector3f(1f, 1f, 1f), float alpha = 1f, float scale = 1f)
	{
		TextSpriteOrder order = {
			text : text,
			font : font,
			position : position,
			colour : colour,
			alpha : alpha,
			scale : scale,
		};
		textSpriteOrders ~= order;
	}

	Moxane moxane;
	Renderer renderer;
	
	private uint vao, vbo;
	private Effect effect, textEffect;

	private enum vertexCount = 6;

	private FT_Library ftLib;

	this(Moxane moxane, Renderer renderer) @trusted
	{
		this.moxane = moxane;
		this.renderer = renderer;

		FT_Init_FreeType(&ftLib);

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
		Shader vs = new Shader, fs = new Shader, vsText = new Shader, fsText = new Shader;
		
		enforce(vs.compile(readText(AssetManager.translateToAbsoluteDir("content/moxane/shaders/sprite.vs.glsl")), GL_VERTEX_SHADER, log));
		enforce(fs.compile(readText(AssetManager.translateToAbsoluteDir("content/moxane/shaders/sprite.fs.glsl")), GL_FRAGMENT_SHADER, log));
		enforce(vsText.compile(readText(AssetManager.translateToAbsoluteDir("content/moxane/shaders/spriteText.vs.glsl")), GL_VERTEX_SHADER, log));
		enforce(fsText.compile(readText(AssetManager.translateToAbsoluteDir("content/moxane/shaders/spriteText.fs.glsl")), GL_FRAGMENT_SHADER, log));
		
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

		textEffect = new Effect(moxane, SpriteRenderer.stringof ~ "Text");
		textEffect.attachAndLink(vsText, fsText);
		textEffect.bind;
		textEffect.findUniform("Position");
		textEffect.findUniform("Dimensions");
		textEffect.findUniform("MVP");
		textEffect.findUniform("Texture");
		textEffect.findUniform("Colour");
		textEffect.unbind;
	}

	~this()
	{
		glDeleteVertexArrays(1, &vao);
		glDeleteBuffers(1, &vbo);
		FT_Done_Library(ftLib);
	}

	SpriteFont createFont(string dir, uint height, uint width = 0)
	{
		import std.string : toStringz;

		SpriteFont font = new SpriteFont;
		font.size = Vector2u(width, height);

		FT_Face face;
		const(char)* fi = toStringz(dir);
		FT_New_Face(ftLib, fi, 0, &face);
		FT_Set_Pixel_Sizes(face, width, height);
		font.face = face;
		font.newLineOffset = cast(uint)face.size.metrics.height;
		font.hasKerning = FT_HAS_KERNING(face);

		glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
		for(uint i = 0; i < 256; i++) {
			FT_Load_Char(face, i, FT_LOAD_RENDER);

			uint texture;
			glGenTextures(1, &texture);

			glBindTexture(GL_TEXTURE_2D, texture);
			glTexImage2D(GL_TEXTURE_2D, 0, GL_R8, face.glyph.bitmap.width, face.glyph.bitmap.rows, 0, GL_RED, GL_UNSIGNED_BYTE, face.glyph.bitmap.buffer);

			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

			CharacterDesc cd = {
				textureID : texture,
				size : Vector2i(face.glyph.bitmap.width, face.glyph.bitmap.rows),
				offset : Vector2i(face.glyph.bitmap_left, face.glyph.bitmap_top),
				advanceX : face.glyph.advance.x
			};

			font.tiles[cast(char)i] = cd;
		}

		return font;
	}

	private void renderSprites(ref LocalContext lc, out uint drawCalls, out uint numVerts)
	{
		effect.bind;
		scope(exit) effect.unbind;

		Matrix4f mvp = lc.projection;
		effect["MVP"].set(&mvp);

		scope(exit) spriteOrders.length = 0;
		foreach(ref SpriteOrder order; spriteOrders)
		{
			if(order.texture !is null) order.texture.bind;
			scope(exit) if(order.texture !is null) order.texture.unbind;

			effect["Position"].set(order.position);
			effect["Dimensions"].set(order.dimensions);
			if(order.texture !is null)
				effect["Texture"].set(0);
			effect["UseTexture"].set(order.texture !is null);
			effect["Colour"].set(Vector4f(order.colour.x, order.colour.y, order.colour.z, order.alpha));
			effect["MixAlpha"].set(order.mixAlpha);

			glDrawArrays(GL_TRIANGLES, 0, vertexCount);
			drawCalls++;
			numVerts += 6;
		}
	}

	private void renderText(ref LocalContext lc, out uint drawCalls, out uint numVerts)
	{
		enum divider = 6;

		textEffect.bind;
		scope(exit) textEffect.unbind;
		textEffect["MVP"].set(&lc.projection);
		scope(exit) glBindTexture(GL_TEXTURE_2D, 0);

		foreach(ref TextSpriteOrder order; textSpriteOrders)
		{
			int cx = order.position.x;
			int cy = order.position.y;
			uint prev = 0;
			foreach(size_t i; 0 .. order.text.length)
			{
				char c = order.text[i];
				uint glyphIndex = FT_Get_Char_Index(order.font.face, c);

				switch(c)
				{
					case '\n':
						cx = order.position.x;
						cy += order.font.newLineOffset >> divider;
						break;
					case '\t':
						cx += 2048 >> 6;
						break;
					case ' ':
						cx += order.font.tiles[c].advanceX >> divider;
						break;
					default:
						if(order.font.hasKerning && prev > 0 && glyphIndex > 0)
						{
							FT_Vector delta;
							FT_Get_Kerning(order.font.face, prev, glyphIndex, 0, &delta);
							cx += delta.x >> divider;
						}

						CharacterDesc cd = order.font.tiles[c];
						Vector2f pos = Vector2i(
							cx + cd.offset.x,
							cy - cd.offset.y + (order.font.newLineOffset / 96));
						Vector2f size;
						size.x = cd.size.x * order.scale;
						size.y = cd.size.y * order.scale;

						textEffect["Position"].set(pos);
						textEffect["Dimensions"].set(size);
						textEffect["Texture"].set(0);
						glBindTexture(GL_TEXTURE_2D, cd.textureID);
						textEffect["Colour"].set(Vector4f(order.colour.x, order.colour.y, order.colour.z, order.alpha));

						glDrawArrays(GL_TRIANGLES, 0, vertexCount);
						drawCalls++;
						numVerts += vertexCount;

						cx += cd.advanceX >> divider;
				}

				prev = glyphIndex;
			}
		}
	}

	void render(Renderer renderer, ref LocalContext lc, out uint drawCalls, out uint numVerts)
	{
		glBindVertexArray(vao);
		scope(exit) glBindVertexArray(0);
		glEnableVertexAttribArray(0);
		scope(exit) glDisableVertexAttribArray(0);

		glBindBuffer(GL_ARRAY_BUFFER, vbo);
		glVertexAttribPointer(0, 2, GL_FLOAT, false, 0, null);
		glBindBuffer(GL_ARRAY_BUFFER, 0);

		glActiveTexture(GL_TEXTURE0);

		renderer.gl.blend.push(true);
		scope(exit) renderer.gl.blend.pop;

		renderer.gl.blendFunc.push(Tuple!(GLenum, GLenum)(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA));
		scope(exit) renderer.gl.blendFunc.pop;

		uint dc, nv;
		renderSprites(lc, dc, nv);
		drawCalls += dc;
		numVerts += nv;

		renderText(lc, dc, nv);
		drawCalls += dc;
		numVerts += nv;
	}
}

struct CharacterDesc
{
	uint textureID;
	Vector2i size, offset;
	int advanceX;
}

final class SpriteFont
{
	private CharacterDesc[char] tiles;
	private FT_Face face;
	string file;
	Vector2u size;
	uint newLineOffset;
	bool hasKerning;

	~this()
	{
		foreach(char c, CharacterDesc cd; tiles)
			glDeleteTextures(1, &cd.textureID);
	}
}

shared static this()
{
	import derelict.util.exception;
	ShouldThrow missingFTSymbol(string symbol) {
		if(symbol == "FT_Stream_OpenBzip2")
			return ShouldThrow.No;
		else if(symbol == "FT_Get_CID_Registry_Ordering_Supplement")
			return ShouldThrow.No;
		else if(symbol == "FT_Get_CID_Is_Internally_CID_Keyed")
			return ShouldThrow.No;
		else if(symbol == "FT_Get_CID_From_Glyph_Index")
			return ShouldThrow.No;
		else
			return ShouldThrow.Yes;
	}
	DerelictFT.missingSymbolCallback = &missingFTSymbol;
	DerelictFT.load();
}