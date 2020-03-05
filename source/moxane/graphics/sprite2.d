module moxane.graphics.spite;

import moxane.core;
import moxane.graphics;

import derelict.opengl3.gl3;
import derelict.freetype.ft;
import dlib.math.vector;

import std.exception : enforce;
import std.file : readText;
import std.typecons : Tuple;

@safe:

final class Sprites : IRenderable
{
    private uint vao, vbo, tbo;
    private Effect effect;
    private FT_Library ftLib;

    private enum divider = 6;
    private enum vertexCount = 6;

    Moxane moxane;
    Renderer renderer;

    this(Moxane moxane, Renderer renderer) @trusted
    in(moxane !is null)
    {
        this.moxane = moxane;
        this.renderer = renderer;

        FT_Init_FreeType(&ftLib);

        if(renderer is null) { return; }

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

        glGenBuffers(1, &tbo);
        glBufferData(GL_ARRAY_BUFFER, verts.length * Vector2f.sizeof, null, GL_STREAM_DRAW);
		glBindBuffer(GL_ARRAY_BUFFER, 0);

		Log log = moxane.services.getAOrB!(GraphicsLog, Log);
		Shader vs = new Shader, fs = new Shader;
		
		enforce(vs.compile(readText(AssetManager.translateToAbsoluteDir("content/moxane/shaders/sprite.vs.glsl")), GL_VERTEX_SHADER, log));
		enforce(fs.compile(readText(AssetManager.translateToAbsoluteDir("content/moxane/shaders/sprite.fs.glsl")), GL_FRAGMENT_SHADER, log));

		effect = new Effect(moxane, typeof(this).stringof);
		effect.attachAndLink(vs, fs);
		effect.bind;
		effect.findUniform("Position");
		effect.findUniform("Dimensions");
		effect.findUniform("MVP");
		effect.findUniform("Texture");
		effect.findUniform("Colour");
        effect.findUniform("Alpha");
		effect.unbind;
    }

    ~this() @trusted
    {
        glDeleteVertexArrays(1, &vao);
        glDeleteBuffers(1, &vbo);
        glDeleteBuffers(1, &tbo);
        FT_Done_Library(ftLib);
    }

    private struct Order
    {
        Vector2i position;
        Vector3f colour;
        float alpha;

        Texture2D texture;
        Vector2i size;
        Vector2f texLow, texHigh;

        SpriteFont font;
        string text;
        float scale;
    }

    private Order[] orders;

    void draw(Texture2D texture, Vector2i position, Vector2i size = Vector2i(0, 0), 
        Vector3f colour = Vector3f(1, 1, 1), float alpha = 1f)
    { draw(texture, position, Vector2f(0, 0), Vector2f(1, 1), size, colour, alpha); }

    void draw(Texture2D texture, Vector2i position, Vector2f texCoordLow, Vector2f texCoordHigh,
        Vector2i size = Vector2i(0, 0), Vector3f colour = Vector3f(1, 1, 1), float alpha = 1f)
    in(texture !is null, "texture must not be null!")
    {
        if(renderer is null) { return; }
        const auto properSize = (size.x == 0 && size.y == 0) ? 
            Vector2i(texture.width, texture.height) :
            size;
        Order o = {
            position : position,
            colour : colour,
            alpha : alpha,
            texture : texture,
            size : properSize,
            texLow : texCoordLow,
            texHigh : texCoordHigh,
            font : null,
            text : null,
            scale : 0f
        };
        orders ~= o;
    }

    void drawString(SpriteFont font, string text, Vector2i position, float scale = 1f,
        Vector3f colour = Vector3f(1, 1, 1), float alpha = 1f)
    in(text !is null, "text must not be null")
    in(font !is null, "font must not be null")
    {
        if(renderer is null) { return; }
        Order o = {
            position : position,
            colour : colour,
            alpha : alpha,
            texture : null,
            size : Vector2i.init,
            texLow : Vector2f.init,
            texHigh : Vector2f.init,
            font : font,
            text : text,
            scale : scale
        };
        orders ~= o;
    }

    SpriteFont createFont(string directory, uint height, uint width = 0) @trusted
    in(directory !is null, "directory must be null") in(height > 0, "height must be greater than 0")
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

        if(renderer !is null)
		    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
		for(uint i = 0; i < 256; i++) {
			FT_Load_Char(face, i, FT_LOAD_RENDER);

			uint texture;
            if(renderer !is null)
            {
                glGenTextures(1, &texture);

                glBindTexture(GL_TEXTURE_2D, texture);
                glTexImage2D(GL_TEXTURE_2D, 0, GL_R8, face.glyph.bitmap.width, face.glyph.bitmap.rows, 0, GL_RED, GL_UNSIGNED_BYTE, face.glyph.bitmap.buffer);

                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
            }

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

    Vector2i measureString(string text, SpriteFont font, float scale = 1f) @trusted
    in(text !is null, "text must not be null") in(font !is null, "font must not be null")
    {
        int cx;
        int maxCx, height = font.newLineOffset >> divider;
        uint prev = 0;
        foreach(size_t i; 0 .. text.length)
        {
            char c = text[i];
            uint glyphIndex = FT_Get_Char_Index(font.face, c);

            if(cx > maxCx) maxCx = cx;

            switch(c)
            {
                case '\n':
                    cx = 0;
                    height += font.newLineOffset >> divider;
                    break;
                case '\t':
                    cx += 2048 >> 6;
                    break;
                case ' ':
                    cx += font.tiles[c].advanceX >> divider;
                    break;
                default:
                    if(font.hasKerning && prev > 0 && glyphIndex > 0)
                    {
                        FT_Vector delta;
                        FT_Get_Kerning(font.face, prev, glyphIndex, 0, &delta);
                        cx += delta.x >> divider;
                    }

                    const CharacterDesc cd = font.tiles[c];
                    cx += cd.advanceX >> divider;
            }

            prev = glyphIndex;
        }

        return Vector2i(maxCx, height);
    }

    void render(Renderer renderer, ref LocalContext lc, 
        out uint drawCalls, out uint numVerts) @trusted
    in(this.renderer !is null)
    {
        glBindVertexArray(vao);
        scope(exit) glBindVertexArray(0);
        glEnableVertexAttribArray(0);
        scope(exit) glDisableVertexAttribArray(0);
        glEnableVertexAttribArray(1);
        scope(exit) glDisableVertexAttribArray(0);

        effect.bind;
        scope(exit) effect.unbind;
        effect["Texture"].set(0);

        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glVertexAttribPointer(0, 2, GL_FLOAT, false, 0, null);
        scope(exit) glBindBuffer(GL_ARRAY_BUFFER, 0);

        glActiveTexture(GL_TEXTURE0);

        renderer.gl.blend.push(true);
        scope(exit) renderer.gl.blend.pop;
        renderer.gl.blendEquation.push(GL_FUNC_ADD);
		scope(exit) renderer.gl.blendEquation.pop;
		renderer.gl.blendFunc.push(Tuple!(GLenum, GLenum)(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA));
		scope(exit) renderer.gl.blendFunc.pop;

        effect["MVP"].set(&lc.projection);

        scope(exit) orders.length = 0;
        foreach(ref Order order; orders)
        {
            if(order.texture !is null && order.text is null)
                renderSprite(order, drawCalls, numVerts);
            else if(order.texture is null && order.text !is null)
                renderText(order, drawCalls, numVerts);
            else throw new Exception("impossible");
        }
    }

    private void streamTexCoord(Vector2f low, Vector2f high) @trusted
    {
        const Vector2f[6] texCoords = [
            Vector2f(low.x, low.y),
			Vector2f(high.x, low.y),
			Vector2f(high.x, high.y),
			Vector2f(high.x, high.y),
			Vector2f(low.x, high.y),
			Vector2f(low.x, low.y)
        ];

        glBindBuffer(GL_ARRAY_BUFFER, tbo);
        glBufferData(GL_ARRAY_BUFFER, texCoords.length * Vector2f.sizeof, null, GL_STREAM_DRAW);
        glBufferSubData(GL_ARRAY_BUFFER, 0, texCoords.length * Vector2f.sizeof, texCoords.ptr);
        glVertexAttribPointer(1, 2, GL_FLOAT, false, 0, null);
    }

    private void renderSprite(ref Order order, ref uint drawCalls, ref uint numVerts) @trusted
    {
        order.texture.bind;
        scope(exit) order.texture.unbind;

        streamTexCoord(order.texLow, order.texHigh);

        effect["Position"].set(order.position);
        effect["Dimensions"].set(order.size);
        effect["Colour"].set(order.colour);
        effect["Alpha"].set(order.alpha);

        glDrawArrays(GL_TRIANGLES, 0, vertexCount);
		drawCalls++;
		numVerts += vertexCount;
    }

    private void renderText(ref Order order, ref uint drawCalls, ref uint numVerts) @trusted
    {
        streamTexCoord(Vector2f(0, 0), Vector2f(1, 1));

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

                    effect["Position"].set(pos);
                    effect["Dimensions"].set(size);
                    glBindTexture(GL_TEXTURE_2D, cd.textureID);
                    scope(exit) glBindTexture(GL_TEXTURE_2D, 0);
                    effect["Colour"].set(Vector4f(order.colour.x, order.colour.y, order.colour.z, order.alpha));
                    effect["Alpha"].set(1f);

                    glDrawArrays(GL_TRIANGLES, 0, vertexCount);
                    drawCalls++;
                    numVerts += vertexCount;

                    cx += cd.advanceX >> divider;
            }

            prev = glyphIndex;
        }
    }
}

private struct CharacterDesc
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

	~this() @trusted
	{
		foreach(char c, CharacterDesc cd; tiles)
			glDeleteTextures(1, &cd.textureID);
	}
}