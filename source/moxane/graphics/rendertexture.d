module moxane.graphics.rendertexture;

import moxane.graphics.gl;

import derelict.opengl3.gl3;

import std.conv : to;

class RenderTexture
{
	uint width, height;

	GLuint fbo;
	GLuint diffuse, worldPos, normal, meta;
	DepthTexture depthTexture;

	GLState gl;

	this(uint width, uint height, GLState gl)
	{
		this.gl = gl;

		this.width = width;
		this.height = height;

		gl.texture2D.push(true);
		scope(exit) gl.texture2D.pop();

		glActiveTexture(GL_TEXTURE0);

		glGenTextures(1, &diffuse);
		glGenTextures(1, &worldPos);
		glGenTextures(1, &normal);
		//glGenTextures(1, &meta);
		createTextures;

		glGenFramebuffers(1, &fbo);
		glBindFramebuffer(GL_FRAMEBUFFER, fbo);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, diffuse, 0);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_2D, worldPos, 0);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT2, GL_TEXTURE_2D, normal, 0);

		GLenum[] drawBuffers = [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2];
		glDrawBuffers(cast(int)drawBuffers.length, drawBuffers.ptr);

		GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
		if(status != GL_FRAMEBUFFER_COMPLETE)
			throw new Exception("FBO " ~ to!string(fbo) ~ " could not be created. Status: " ~ to!string(status));

		glBindFramebuffer(GL_FRAMEBUFFER, 0);
	}

	void createTextures()
	{
		assert(width > 0 && height > 0);

		gl.texture2D.push(true);
		scope(exit) gl.texture2D.pop;

		glBindTexture(GL_TEXTURE_2D, diffuse);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height, 0, GL_RGBA, GL_UNSIGNED_INT, null);

		glBindTexture(GL_TEXTURE_2D, worldPos);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB16F, width, height, 0, GL_RGB, GL_UNSIGNED_SHORT, null);

		glBindTexture(GL_TEXTURE_2D, normal);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB16F, width, height, 0, GL_RGB, GL_UNSIGNED_SHORT, null);

		//glBindTexture(GL_TEXTURE_2D, meta);

		glBindTexture(GL_TEXTURE_2D, 0);
	}

	~this() 
	{
		glDeleteTextures(1, &diffuse);
		glDeleteTextures(1, &worldPos);
		glDeleteTextures(1, &normal);
		glDeleteFramebuffers(1, &fbo);
	}

	void bindDepth(DepthTexture dt)
	{
		depthTexture = dt;
		if(dt.width != width || dt.height != height)
			throw new Exception("Dimensions must be equal.");
		glBindFramebuffer(GL_FRAMEBUFFER, fbo);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_TEXTURE_2D, dt.depth, 0);
	}

	void unbindDepth()
	{
		assert(depthTexture !is null);
		glBindFramebuffer(GL_FRAMEBUFFER, fbo);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_TEXTURE_2D, 0, 0);
	}

	void bindAsTexture(uint[3] textureUnits)
	{
		glActiveTexture(GL_TEXTURE0 + textureUnits[0]);
		glBindTexture(GL_TEXTURE_2D, diffuse);
		glActiveTexture(GL_TEXTURE0 + textureUnits[1]);
		glBindTexture(GL_TEXTURE_2D, worldPos);
		glActiveTexture(GL_TEXTURE0 + textureUnits[2]);
		glBindTexture(GL_TEXTURE_2D, normal);
	}

	void unbindTextures(uint[3] textureUnits)
	{
		foreach(uint tu; textureUnits)
		{
			glActiveTexture(GL_TEXTURE0 + tu);
			glBindTexture(GL_TEXTURE_2D, 0);
		}
	}

	void blitTo(RenderTexture target)
	{
		glBindFramebuffer(GL_READ_FRAMEBUFFER, fbo);
		glBindFramebuffer(GL_DRAW_FRAMEBUFFER, target.fbo);


		glBlitFramebuffer(0, 0, width, height, 0, 0, target.width, target.height, GL_COLOR_BUFFER_BIT, GL_LINEAR);
	}
}

class DepthTexture
{
	uint width, height;
	GLuint depth;

	GLState gl;

	this(uint width, uint height, GLState gl)
	{
		this.width = width;
		this.height = height;
		this.gl = gl;

		gl.texture2D.push(true);
		scope(exit) gl.texture2D.pop();

		
	}
}