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

class Bitmap
{
	private FIBITMAP* fibitmap;

	this(string name)
	{
		auto filez = dir.toStringz;
		FREE_IMAGE_FORMAT fif = FreeImage_GetFileType(filez, 0);
		if(fif == FIF_UNKNOWN) fif = FreeImage_GetFIFFromFilename(filez);

		if((fif != FIF_UNKNOWN) && FreeImage_FIFSupportsReading(fif))
			fibitmap = FreeImage_Load(fif, filez, 0);
		if(fibitmap is null) throw new Exception("Could not load image " ~ dir);
	}

	~this() { FreeImage_Unload(fibitmap); fibitmap = null; }

	uint width() { return FreeImage_GetWidth(fibitmap); }
	uint height() { return FreeImage_GetHeight(fibitmap); }
	ImageMemoryType memoryType() { return cast(ImageMemoryType)FreeImage_GetImageType(fibitmap); }
	ImageColourType colourType() { return cast(ImageColourType)FreeImage_GetColorType(fibitmap); }

	void* data() { return FreeImage_GetBits(fibitmap); }

	void resize(int newWidth, int newHeight, ImageFilter filter) 
	{
		FIBITMAP* finew = FreeImage_Rescale(fibitmap, newWidth, newHeight, filter);
		FreeImage_Unload(fibitmap);
		fibitmap = finew;
	}

	void ensure32Bits() 
	{
		if(memoryType != ImageMemoryType.int32) 
		{
			FIBITMAP* finew = FreeImage_ConvertTo32Bits(fibitmap);
			FreeImage_Unload(fibitmap);
			fibitmap = finew;
		}
	}
}

enum ImageMemoryType {
	unknown = 0,
	bitmap,
	uint16,
	int16,
	uint32,
	int32,
	float_,
	double_,
	complex,
	rgb16,
	rgba16,
	rgbfloat,
	rgbafloat
}

enum ImageColourType {
	minIsWhite = 0,
	minIsBlack,
	rgb,
	palette,
	rgba,
	cmyk
}

enum ImageFilter {
	box = 0,
	bicubic,
	bilinear,
	bspline,
	catmullrom,
	lanczos3
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
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_BGRA, GL_UNSIGNED_BYTE, data);

		if(genMipMaps)
			glGenerateMipmap(GL_TEXTURE_2D);
	}

	this(string dir, Filter minification = Filter.linear, Filter magnification = Filter.linear, bool genMipMaps = false)
	{
		FIBITMAP* bitmap;
		//scope(exit) FreeImage_Unload(bitmap);

		auto filez = dir.toStringz;
		FREE_IMAGE_FORMAT fif = FreeImage_GetFileType(filez, 0);
		if(fif == FIF_UNKNOWN) fif = FreeImage_GetFIFFromFilename(filez);

		if((fif != FIF_UNKNOWN) && FreeImage_FIFSupportsReading(fif))
			bitmap = FreeImage_Load(fif, filez, 0);
		if(bitmap is null) throw new Exception("Could not load Texture2D " ~ dir);

		FIBITMAP* bitmap32 = FreeImage_ConvertTo32Bits(bitmap);
		FreeImage_Unload(bitmap);
		scope(exit) FreeImage_Unload(bitmap32);

		this(FreeImage_GetBits(bitmap32), FreeImage_GetWidth(bitmap32), FreeImage_GetHeight(bitmap32), minification, magnification, genMipMaps);
	}

	void bind() { glBindTexture(GL_TEXTURE_2D, handle); }
	void unbind() { glBindTexture(GL_TEXTURE_2D, 0); }
}

class Texture2DArray
{
	uint handle, width, height;
}