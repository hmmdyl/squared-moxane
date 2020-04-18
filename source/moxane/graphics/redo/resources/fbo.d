module moxane.graphics.redo.resources.fbo;

import moxane.graphics.gl;

import std.conv : to;
import derelict.opengl3.gl3;

@safe:

class DepthTexture
{
	uint width, height;
	invariant {
		assert(width > 0);
		assert(height > 0);
	}
	GLuint depth;

	private Texture2D texture_;
	@property Texture2D texture() { return texture_; }

	this(uint width, uint height) @trusted
	{
		this.width = width;
		this.height = height;
		this.gl = gl;

		glGenTextures(1, &depth);

		auto ci = Texture2D.ConstructionInfo.standard;
		ci.bitDepth = TextureBitDepth.thirtyTwo;
		texture_ = new Texture2D(depth, width, height, ci);

		createTextures;
	}

	void createTextures(uint w, uint h)
	{
		this.width = w;
		this.height = h;
		texture_.width = w;
		texture_.height = h;
		createTextures;
	}

	void createTextures() @trusted
	{
		glBindTexture(GL_TEXTURE_2D, depth);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT, width, height, 0, GL_DEPTH_COMPONENT, GL_FLOAT, null);

		glBindTexture(GL_TEXTURE_2D, 0);
	}
}

@trusted interface IFramebuffer 
{
	@property uint width();
	@property uint height();
	@property uint handle();

	@property DepthTexture depthTexture();

	void update(uint width, uint height);

	void clear();
	void beginDraw();
	void endDraw();
	void read(GLenum[] textureUnits);
	final void endRead(GLenum[] textureUnits)
	{
		foreach(uint tu; textureUnits)
		{
			glActiveTexture(GL_TEXTURE0 + tu);
			glBindTexture(GL_TEXTURE_2D, 0);
		}
	}
}

@trusted final class DefaultFramebuffer : IFramebuffer
{
	private uint width_, height_, handle_;
	@property uint width() { return width_; }
	@property uint height() { return height_; }
	@property uint handle() { return handle_; }

	@property DepthTexture depthTexture() { return null; }

	this(uint w, uint h)
	{ update(w, h); }

	void update(uint w, uint h)
	{
		this.width_ = w;
		this.height_ = h;
	}

	void clear()
	{ glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT); }

	void beginDraw() { glBindFramebuffer(GL_FRAMEBUFFER, 0); }
	void endDraw() { glBindFramebuffer(GL_FRAMEBUFFER, 0); }
	void read(GLenum[] tu) { throw new Exception("Not available"); }
}

@trusted class SceneFramebuffer : IFramebuffer
{
	private uint width_, height_, handle_;
	@property uint width() { return width_; }
	@property uint height() { return height_; }
	@property uint handle() { return handle_; }

	invariant { assert(width > 0); assert(height > 0); }

	private DepthTexture depth_;
	@property DepthTexture depthTexture() { return depth_; }

	private uint[4] textures;
	@property uint diffuse() { return textures[0]; }
	@property uint worldPos() { return textures[1]; }
	@property uint normal() { return textures[2]; }
	@property uint specularity() { return textures[3]; }

	private static GLenum[] attachments = [
		GL_COLOR_ATTACHMENT0,
		GL_COLOR_ATTACHMENT1,
		GL_COLOR_ATTACHMENT2,
		GL_COLOR_ATTACHMENT3,
	];

	this(uint w, uint h, DepthTexture depth = null)
	{
		this.depth_ = depth;

		glGenTextures(4, textures.ptr);
		update(w, h);

		glGenFramebuffers(1, &handle_);
		glBindFramebuffer(GL_FRAMEBUFFER, handle_);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, diffuse, 0);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_2D, worldPos, 0);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT2, GL_TEXTURE_2D, normal, 0);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT3, GL_TEXTURE_2D, specularity, 0);
		if(depth_ !is null)
			glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, depth_.depth, 0);

		glDrawBuffers(cast(int)attachments.length, attachments.ptr);

		GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
		if(status != GL_FRAMEBUFFER_COMPLETE)
			throw new Exception("FBO " ~ to!string(fbo) ~ " could not be created. Status: " ~ to!string(status));

		glBindFramebuffer(GL_FRAMEBUFFER, 0);
	}

	~this()
	{
		glDeleteTextures(cast(int)textures.length, textures.ptr);
		glDeleteFramebuffers(1, &handle);
	}

	void update(uint w, uint h)
	{
		this.width_ = w;
		this.height_ = h;

		glBindTexture(GL_TEXTURE_2D, diffuse);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);

		glBindTexture(GL_TEXTURE_2D, worldPos);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB32F, width, height, 0, GL_RGB, GL_UNSIGNED_INT, null);

		glBindTexture(GL_TEXTURE_2D, normal);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB16F, width, height, 0, GL_RGB, GL_UNSIGNED_SHORT, null);

		glBindTexture(GL_TEXTURE_2D, specularity);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RG16F, width, height, 0, GL_RG, GL_UNSIGNED_SHORT, null);

		glBindTexture(GL_TEXTURE_2D, 0);
	}

	void clear()
	{ glClear(GL_COLOR_BUFFER_BIT | (depth !is null ? GL_DEPTH_BUFFER_BIT : GL_NONE)); }

	void beginDraw() 
	{
		glBindFramebuffer(GL_FRAMEBUFFER, fbo);
		glViewport(0, 0, width_, height);
	}

	void endDraw() { glFramebuffer(GL_FRAMEBUFFER, 0); }

	void read(GLenum[] textureUnits) 
	{ 
		foreach(i, textureUnit; textureUnits)
		{
			glActiveTexture(textureUnit);
			glBindTexture(GL_TEXTURE_2D, textures[i]);
		}
	}
}

@trusted class PostProcessFramebuffer : IFramebuffer
{
	private uint width_, height_, handle_;
	@property uint width() { return width_; }
	@property uint height() { return height_; }
	@property uint handle() { return handle_; }

	invariant { assert(width > 0); assert(height > 0); }

	@property DepthTexture depthTexture() { return null; }

	private uint texture;
	@property uint diffuse() { return texture; }

	private static GLenum[] attachments = [
		GL_COLOR_ATTACHMENT0,
	];

	this(uint w, uint h)
	{
		this.depth_ = depth;

		glGenTextures(1, &texture);
		update(w, h);

		glGenFramebuffers(1, &handle_);
		glBindFramebuffer(GL_FRAMEBUFFER, handle_);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture, 0);

		glDrawBuffers(cast(int)attachments.length, attachments.ptr);

		GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
		if(status != GL_FRAMEBUFFER_COMPLETE)
			throw new Exception("FBO " ~ to!string(fbo) ~ " could not be created. Status: " ~ to!string(status));

		glBindFramebuffer(GL_FRAMEBUFFER, 0);
	}

	~this()
	{
		glDeleteTextures(1, &texture);
		glDeleteFramebuffers(1, &handle);
	}

	void update(uint w, uint h)
	{
		this.width_ = w;
		this.height_ = h;

		glBindTexture(GL_TEXTURE_2D, texture);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);

		glBindTexture(GL_TEXTURE_2D, 0);
	}

	void clear()
	{ glClear(GL_COLOR_BUFFER_BIT); }

	void beginDraw() 
	{
		glBindFramebuffer(GL_FRAMEBUFFER, fbo);
		glViewport(0, 0, width_, height);
	}

	void endDraw() { glFramebuffer(GL_FRAMEBUFFER, 0); }

	void read(GLenum[] textureUnits) 
	{ 
		glActiveTexture(GL_TEXTURE0 + textureUnits[0]);
		glBindTexture(GL_TEXTURE_2D, texture);
	}
}