module moxane.graphics.redo.resources.texture2d;

public import moxane.graphics.redo.resources.texture;

import derelict.opengl3.gl3;
import derelict.freeimage.freeimage;

import std.string : toStringz;

@safe:

class Texture2D
{
	uint handle;
	uint width, height;

	TextureBitDepth bitDepth;
	Filter min, mag;
	bool mipMaps, clamp;

	package this(uint handle, uint width, uint height, TextureBitDepth depth, 
				 Filter minification = Filter.linear, Filter magnification = Filter.linear, 
				 bool mipMaps = true, bool clamp = false)
	{
		this.handle = handle;
		this.width = width;
		this.height = height;
		this.bitDepth = depth;
		this.min = minification;
		this.mag = magnification;
		this.mipMaps = mipMaps;
		this.clamp = false;
	}

	this(void* data, uint width, uint height, TextureBitDepth depth, 
		 Filter minification = Filter.linear, Filter magnification = Filter.linear, bool mipMaps = true,
		 bool clamp = false) @trusted
	{
		glGenTextures(1, &handle);
		upload(data, width, height, depth, minification, magnification, mipMaps, clamp);
	}

	this(string dir, Filter minification = Filter.linear, Filter magnification = Filter.linear, 
		 bool mipMaps = true, bool clamp = false) @trusted
	{
		glGenTextures(1, &handle);

		FIBITMAP* bitmap;

		auto filez = dir.toStringz;
		FREE_IMAGE_FORMAT fif = FreeImage_GetFileType(filez, 0);
		if(fif == FIF_UNKNOWN) fif = FreeImage_GetFIFFromFilename(filez);

		if((fif != FIF_UNKNOWN) && FreeImage_FIFSupportsReading(fif))
			bitmap = FreeImage_Load(fif, filez, 0);
		if(bitmap is null) throw new Exception("Could not load Texture2D " ~ dir);

		FIBITMAP* bitmap32 = FreeImage_ConvertTo32Bits(bitmap);
		FreeImage_Unload(bitmap);
		scope(exit) FreeImage_Unload(bitmap32);

		upload(FreeImage_GetBits(bitmap32), FreeImage_GetWidth(bitmap32), FreeImage_GetHeight(bitmap32), 
			   TextureBitDepth.eight, minification, magnification, mipMaps, clamp);
	}

	void upload(void* data, uint width, uint height, TextureBitDepth depth, Filter minification = Filter.linear, 
				Filter magnification = Filter.linear, bool mipMaps = true, bool clamp = false) @trusted
	{
		this.bitDepth = depth;
		this.min = minification;
		this.mag = magnification;
		this.mipMaps = mipMaps;
		this.width = width;
		this.height = height;
		this.clamp = clamp;

		bind;
		scope(exit) unbind;

		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, minification);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, magnification);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, clamp ? GL_CLAMP_TO_EDGE : GL_REPEAT);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, clamp ? GL_CLAMP_TO_EDGE : GL_REPEAT);

		GLenum internalFormat;
		if(meta_.bitDepth == TextureBitDepth.eight)
			internalFormat = GL_RGBA;
		else if(meta_.bitDepth == TextureBitDepth.sixteen)
			internalFormat = GL_RGBA16;

		GLenum bitDepth;
		if(depth == TextureBitDepth.eight)
			bitDepth = GL_UNSIGNED_BYTE;
		else if(depth == TextureBitDepth.sixteen)
			bitDepth = GL_UNSIGNED_SHORT;

		glTexImage2D(GL_TEXTURE_2D, 0, internalFormat, width, height, 0, GL_BGRA, bitDepth, data);

		if(mipMaps)
			glGenerateMipmap(GL_TEXTURE_2D);
	}

	void bind() @trusted { glBindTexture(GL_TEXTURE_2D, handle); } 
	static void unbind() @trusted { glBindTexture(GL_TEXTURE_2D, 0); }
}