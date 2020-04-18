module moxane.graphics.redo.resources.texture2darray;

public import moxane.graphics.redo.resources.texture;

import derelict.opengl3.gl3;

@safe:

class Texture2DArray
{
	uint handle, width, height, depth;

	@trusted this(string[] files, bool shouldThrow = false, Filter minification = Filter.linear, Filter magnification = Filter.linear, bool genMipMaps = false)
	{
		Bitmap[] bitmaps = new Bitmap[](files.length);
		foreach(size_t i, string file; files)
			bitmaps[i] = new Bitmap(file);

		depth = cast(uint)files.length;

		foreach(Bitmap bitmap; bitmaps)
		{
			width = bitmap.width > width ? bitmap.width : width;
			height = bitmap.height > height ? bitmap.height : height;
		}

		foreach(size_t i, Bitmap bitmap; bitmaps) {
			if(!(bitmap.width == width && bitmap.height == height)) {
				if(shouldThrow) { 
					throw new Exception(files[i] ~ " is of [" ~ 
										to!string(bitmap.width) ~ ", " ~ to!string(bitmap.height) ~ "] not [" ~
										to!string(width) ~ ", " ~ to!string(height) ~ "] as required."); 
				} else {
					bitmap.resize(width, height, ImageFilter.bicubic);
				}
			}
		}

		glGenTextures(1, &handle);
		bind;

		glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, minification);
		glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, magnification);
		glTexImage3D(GL_TEXTURE_2D_ARRAY, 0, cast(int)GL_SRGB8_ALPHA8, cast(int)width, cast(int)height, cast(int)depth, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);

		foreach(size_t i, Bitmap bitmap; bitmaps) {
			bitmap.ensure32Bits();
			glTexSubImage3D(GL_TEXTURE_2D_ARRAY, 0, 0, 0, cast(int)i, width, height, 1, GL_BGRA, GL_UNSIGNED_BYTE, bitmap.data);
		}

		if(genMipMaps)
			glGenerateMipmap(GL_TEXTURE_2D_ARRAY);

		unbind();
	}

	@trusted void bind() { glBindTexture(GL_TEXTURE_2D_ARRAY, handle); }
	@trusted static void unbind() { glBindTexture(GL_TEXTURE_2D_ARRAY, 0); }
}