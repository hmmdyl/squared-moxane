module moxane.graphics.texture;

import moxane.core.asset;

import std.string : toStringz;

import derelict.freeimage.freeimage;
import derelict.opengl3.gl3;

/*class Texture2DLoader : IAssetLoader
{
	Object handle(AssetManager am, TypeInfo ti, string dir)
	{
		FIBITMAP* bitmap;
		auto filez = AssetManager.translateToAbsoluteDir(dir).toStringz;
		FREE_IMAGE_FORMAT fif = FreeImage_GetFileType(filez, 0);
		if(fif == FIF_UNKNOWN) fif = FreeImage_GetFIFFromFilename(filez);
		if((fif != FIF_UNKNOWN) && FreeImage_FIFSupportsReading(fif))
			bitmap = FreeImage_Load(fif, filez, 0);
		if(bitmap is null) throw new Exception("Could not load Texture2D " ~ dir);


	}
}*/

enum Filter
{
	nearest = GL_NEAREST,
	linear = GL_LINEAR
}

class Texture2D
{
	uint handle;
	uint width, height;

	this(void* data, uint width, uint height, Filter minification, Filter magnification, bool genMipMaps)
	{
		glGenTextures(1, &handle);
		bind;
		scope(exit) unbind;

		this.width = width;
		this.height = height;

		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, minification);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, magnification);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);

		if(genMipMaps)
			glGenerateMipmap(GL_TEXTURE_2D);
	}

	this(string dir, Filter minification = Filter.linear, Filter magnification = Filter.linear, bool genMipMaps = false)
	{
		FIBITMAP* bitmap;
		auto filez = dir.toStringz;
		FREE_IMAGE_FORMAT fif = FreeImage_GetFileType(filez, 0);
		if(fif == FIF_UNKNOWN) fif = FreeImage_GetFIFFromFilename(filez);
		if((fif != FIF_UNKNOWN) && FreeImage_FIFSupportsReading(fif))
			bitmap = FreeImage_Load(fif, filez, 0);
		if(bitmap is null) throw new Exception("Could not load Texture2D " ~ dir);

		scope(success) FreeImage_Unload(bitmap);

		this(FreeImage_GetBits(bitmap), FreeImage_GetWidth(bitmap), FreeImage_GetHeight(bitmap), minification, magnification, genMipMaps);
	}

	void bind() { glBindTexture(GL_TEXTURE_2D, handle); }
	void unbind() { glBindTexture(GL_TEXTURE_2D, 0); }
}