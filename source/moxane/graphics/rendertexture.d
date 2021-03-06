module moxane.graphics.rendertexture;

import moxane.graphics.gl;
import moxane.graphics.texture;

import derelict.opengl3.gl3;

import std.conv : to;

@safe:

class RenderTexture
{
	uint width, height;
	invariant {
		assert(width > 0);
		assert(height > 0);
	}

	GLuint fbo;
	//GLuint diffuse, worldPos, normal, spec;
	private GLuint[4] handles;
	@property ref GLuint diffuse() { return handles[0]; }
	@property ref GLuint worldPos() { return handles[1]; }
	@property ref GLuint normal() { return handles[2]; }
	@property ref GLuint spec() { return handles[3]; }
	//GLuint depth;
	DepthTexture depthTexture;

	GLState gl;

	private static GLenum[] allAttachments = [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2, GL_COLOR_ATTACHMENT3];

	private Texture2D[4] textures_;
	@property Texture2D[4] textures() { return textures_; }

	this(uint width, uint height, DepthTexture depthTexture, GLState gl) @trusted
	{
		this.gl = gl;

		this.width = width;
		this.height = height;
		this.depthTexture = depthTexture;

		glGenTextures(4, &handles[0]);

		textures_ = new Texture2D[](allAttachments.length);
		auto ci = Texture2D.ConstructionInfo.standard;
		ci.bitDepth = TextureBitDepth.thirtyTwo;
		foreach(i, ref texture; textures_)
			texture = new Texture2D(handles[i], width, height, ci);

		createTextures;

		glGenFramebuffers(1, &fbo);
		glBindFramebuffer(GL_FRAMEBUFFER, fbo);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, diffuse, 0);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_2D, worldPos, 0);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT2, GL_TEXTURE_2D, normal, 0);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT3, GL_TEXTURE_2D, spec, 0);
		if(depthTexture !is null)
			glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, depthTexture.depth, 0);

		GLenum[] drawBuffers = [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2, GL_COLOR_ATTACHMENT3];
		glDrawBuffers(cast(int)drawBuffers.length, drawBuffers.ptr);

		GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
		if(status != GL_FRAMEBUFFER_COMPLETE)
			throw new Exception("FBO " ~ to!string(fbo) ~ " could not be created. Status: " ~ to!string(status));

		glBindFramebuffer(GL_FRAMEBUFFER, 0);
	}

	void createTextures(uint w, uint h)
	{
		this.width = w;
		this.height = h;
		createTextures;
	}

	void createTextures() @trusted
	{
		foreach(texture; textures_)
		{
			texture.width = width;
			texture.height = height;
		}

		glBindTexture(GL_TEXTURE_2D, diffuse);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA16, width, height, 0, GL_RGBA, GL_UNSIGNED_SHORT, null);

		glBindTexture(GL_TEXTURE_2D, worldPos);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB32F, width, height, 0, GL_RGB, GL_UNSIGNED_INT, null);

		glBindTexture(GL_TEXTURE_2D, normal);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB16F, width, height, 0, GL_RGB, GL_UNSIGNED_SHORT, null);

		glBindTexture(GL_TEXTURE_2D, spec);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RG16F, width, height, 0, GL_RG, GL_UNSIGNED_SHORT, null);

		glBindTexture(GL_TEXTURE_2D, 0);
	}

	~this() @trusted
	{
		glDeleteTextures(4, &handles[0]);
		glDeleteFramebuffers(1, &fbo);
	}

	void bindDraw() @trusted
	{
		//glDrawBuffers(cast(int)allAttachments.length, allAttachments.ptr);
		glBindFramebuffer(GL_FRAMEBUFFER, fbo);
		glViewport(0, 0, width, height);
	}

	void unbindDraw() @trusted
	{
		glBindFramebuffer(GL_FRAMEBUFFER, 0);
	}

	void unbindDraw(uint w, uint h) @trusted
	{
		glBindFramebuffer(GL_FRAMEBUFFER, 0);
		glViewport(0, 0, w, h);
	}

	void clear() @trusted
	{
		glClearColor(0f, 0f, 0f, 0);
		if(depthTexture is null)
			glClear(GL_COLOR_BUFFER_BIT);
		else
			glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	}

	void bindAsTexture(uint[4] textureUnits) @trusted
	{
		glActiveTexture(GL_TEXTURE0 + textureUnits[0]);
		glBindTexture(GL_TEXTURE_2D, diffuse);
		glActiveTexture(GL_TEXTURE0 + textureUnits[1]);
		glBindTexture(GL_TEXTURE_2D, worldPos);
		glActiveTexture(GL_TEXTURE0 + textureUnits[2]);
		glBindTexture(GL_TEXTURE_2D, normal);
		glActiveTexture(GL_TEXTURE0 + textureUnits[3]);
		glBindTexture(GL_TEXTURE_2D, spec);
	}

	void unbindTextures(uint[4] textureUnits) @trusted
	{
		foreach(uint tu; textureUnits)
		{
			glActiveTexture(GL_TEXTURE0 + tu);
			glBindTexture(GL_TEXTURE_2D, 0);
		}
	}

	void blitTo(RenderTexture target) @trusted
	{
		glBindFramebuffer(GL_READ_FRAMEBUFFER, fbo);
		glBindFramebuffer(GL_DRAW_FRAMEBUFFER, target.fbo);
		//glDrawBuffer(GL_COLOR_ATTACHMENT0);
		scope(exit)
		{
			glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);
			glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
		}

		if(depthTexture is null)
			glBlitFramebuffer(0, 0, width, height, 0, 0, target.width, target.height, GL_COLOR_BUFFER_BIT, GL_LINEAR);
		else
			glBlitFramebuffer(0, 0, width, height, 0, 0, target.width, target.height, GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT, GL_NEAREST);
	}

	void blitToScreen(uint x, uint y, uint screenWidth, uint screenHeight) @trusted
	{
		glBindFramebuffer(GL_READ_FRAMEBUFFER, fbo);
		glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
		scope(exit) glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);

		glReadBuffer(GL_COLOR_ATTACHMENT0);
		//glDrawBuffer(GL_COLOR_ATTACHMENT0);
		//glBlitFramebuffer(0, 0, width, height, x, y, screenWidth, screenHeight, GL_COLOR_BUFFER_BIT, GL_LINEAR);
		//glDrawBuffer(GL_NONE);

		debug
		{
			glReadBuffer(GL_COLOR_ATTACHMENT0);
			glBlitFramebuffer(0, 0, width, height, x, y, screenWidth/4, screenHeight/4, GL_COLOR_BUFFER_BIT, GL_LINEAR);
			glReadBuffer(GL_COLOR_ATTACHMENT1);
			glBlitFramebuffer(0, 0, width, height, screenWidth/4, y, screenWidth/4*2, screenHeight/4, GL_COLOR_BUFFER_BIT, GL_LINEAR);
			glReadBuffer(GL_COLOR_ATTACHMENT2);
			glBlitFramebuffer(0, 0, width, height, screenWidth/4*2, y, screenWidth/4*3, screenHeight/4, GL_COLOR_BUFFER_BIT, GL_LINEAR);
		}
	}
}

class DepthTexture
{
	uint width, height;
	invariant {
		assert(width > 0);
		assert(height > 0);
	}
	GLuint depth;

	GLState gl;

	private Texture2D texture_;
	@property Texture2D texture() { return texture_; }

	this(uint width, uint height, GLState gl) @trusted
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

class PostProcessTexture
{
	uint width, height;
	invariant {
		assert(width > 0);
		assert(height > 0);
	}

	uint fbo;
	uint diffuse;

	this(uint width, uint height) @trusted
	{
		this.width = width;
		this.height = height;
		
		glGenTextures(1, &diffuse);
		createTextures;

		glGenFramebuffers(1, &fbo);
		glBindFramebuffer(GL_FRAMEBUFFER, fbo);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, diffuse, 0);
		glDrawBuffer(GL_COLOR_ATTACHMENT0);

		GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
		if(status != GL_FRAMEBUFFER_COMPLETE)
			throw new Exception("FBO " ~ to!string(fbo) ~ " could not be created. Status: " ~ to!string(status));

		glBindFramebuffer(GL_FRAMEBUFFER, 0);
	}

	void createTextures() @trusted
	{
		glBindTexture(GL_TEXTURE_2D, diffuse);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA16, width, height, 0, GL_RGBA, GL_UNSIGNED_SHORT, null);

		glBindTexture(GL_TEXTURE_2D, 0);
	}

	void bindDraw() @trusted
	{
		glBindFramebuffer(GL_FRAMEBUFFER, fbo);
		//glDrawBuffer(GL_COLOR_ATTACHMENT0);
		glViewport(0, 0, width, height);
	}

	void unbindDraw() @trusted { glBindFramebuffer(GL_FRAMEBUFFER, 0); }

	void clear() @trusted
	{
		glClear(GL_COLOR_BUFFER_BIT);
	}

	void blitTo(RenderTexture dest) @trusted
	{
		glBindFramebuffer(GL_READ_FRAMEBUFFER, fbo);
		glBindFramebuffer(GL_DRAW_FRAMEBUFFER, dest.fbo);
		scope(exit)
		{
			glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);
			glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
		}

		glReadBuffer(GL_COLOR_ATTACHMENT0);
		glDrawBuffer(GL_COLOR_ATTACHMENT0);
		glBlitFramebuffer(0, 0, width, height, 0, 0, dest.width, dest.height, GL_COLOR_BUFFER_BIT, GL_NEAREST);
	}
}