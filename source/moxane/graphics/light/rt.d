module moxane.graphics.light.rt;

import derelict.opengl3.gl3;
import moxane.graphics.gl;

import std.conv : to;

@trusted:

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

	this(uint width, uint height, GLState gl)
	in { 
		assert(width >= 0);
		assert(height >= 0);
		assert(gl !is null);
	} do {
		this.gl = gl;

		glGenTextures(1, &depth_);
		glGenTextures(1, &diffuse_);

		createTextures(width, height);

		glGenFramebuffers(1, &fbo);
		glBindFramebuffer(GL_FRAMEBUFFER, fbo);
		scope(exit) glBindFramebuffer(GL_FRAMEBUFFER, 0);

		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, depth_, 0);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, diffuse_, 0);

		GLenum[] drawBuffers = [GL_COLOR_ATTACHMENT0];
		glDrawBuffers(1, drawBuffers.ptr);

		GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
		if(status != GL_FRAMEBUFFER_COMPLETE)
			throw new Exception("FBO " ~ to!string(fbo) ~ " could not be created. Status: " ~ to!string(status));
	}

	void createTextures(uint width, uint height)
	in { assert(width > 0); assert(height > 0); }
	do {
		this.width_ = width;
		this.height_ = height;

		glBindTexture(GL_TEXTURE_2D, depth_);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT32F, width, height, 0, GL_DEPTH_COMPONENT, GL_FLOAT, null);

		glBindTexture(GL_TEXTURE_2D, diffuse_);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height, 0, GL_RGBA, GL_UNSIGNED_INT, null);

		glBindTexture(GL_TEXTURE_2D, 0);
	}

	~this()
	{
		glDeleteTextures(1, &depth_);
		glDeleteTextures(1, &diffuse_);
		glDeleteFramebuffers(1, &fbo);
	}

	void bindDraw()
	{
		glBindFramebuffer(GL_FRAMEBUFFER, fbo);
		glViewport(0, 0, width_, height_);
	}

	void unbindDraw()
	{
		glBindFramebuffer(GL_FRAMEBUFFER, 0);
	}

	void clear()
	{
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	}

	void bindAsTexture(uint[2] textureUnits)
	{
		glActiveTexture(GL_TEXTURE0 + textureUnits[0]);
		glBindTexture(GL_TEXTURE_2D, depth_);
		glActiveTexture(GL_TEXTURE0 + textureUnits[1]);
		glBindTexture(GL_TEXTURE_2D, diffuse_);
	}

	void unbindTextures(uint[2] textureUnits)
	{
		foreach(uint tu; textureUnits)
		{
			glActiveTexture(GL_TEXTURE0 + tu);
			glBindTexture(GL_TEXTURE_2D, 0);
		}
	}

	void blitToScreen(uint x, uint y, uint screenWidth, uint screenHeight)
	{
		glBindFramebuffer(GL_READ_FRAMEBUFFER, fbo);
		glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
		scope(exit) glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);

		glReadBuffer(GL_COLOR_ATTACHMENT0);
		debug
		{
			glReadBuffer(GL_COLOR_ATTACHMENT0);
			glBlitFramebuffer(0, 0, width, height, x, y, screenWidth/4, screenHeight/4, GL_COLOR_BUFFER_BIT, GL_LINEAR);
		}
	}
}