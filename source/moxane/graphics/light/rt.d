module moxane.graphics.light.rt;

import derelict.opengl3.gl3;
import moxane.graphics.gl;

package final class DirectionalTexture
{
	private uint width_, height_;
	@property uint width() const { return width_; }
	@property uint height() const { return height_; }

	private uint fbo;
	private uint depth_, diffuse_;
	@property uint depth() const { return depth_; }
	@property uint diffuse() const { return diffuse_; }

	GLState gl;

	this(uint width_, uint height_, GLState gl)
	in { 
		assert(width >= 0);
		assert(height >= 0);
		assert(gl !is null);
	} do {
		this.gl = gl;
		this.width_ = width_;
		this.height_ = height_;

		glGenTextures(1, &depth_);
		glGenTextures(1, &diffuse_);

	}

	void createTextures(uint width_, uint height_)
	in { assert(width_ > 0); assert(height_ > 0); }
	do {

	}
}