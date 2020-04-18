module moxane.graphics.redo.resources.texture;

import derelict.freeimage.freeimage;

enum Filter
{
	nearest = GL_NEAREST,
	linear = GL_LINEAR,
	nearestMipMapLinear = GL_NEAREST_MIPMAP_LINEAR,
}

class Bitmap
{
	private FIBITMAP* fibitmap;

	this(string dir)
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

enum TextureBitDepth
{
	eight,
	sixteen,
	thirtyTwo
}