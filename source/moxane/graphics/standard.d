module moxane.graphics.standard;

import moxane.core.engine;
import moxane.graphics.effect;
import moxane.graphics.texture;
import moxane.graphics.renderer;

import dlib.math;
import std.variant;
import containers;

import derelict.opengl3.gl3;

final class MaterialGroup
{
	Effect effect;
}

abstract class MaterialBase
{
	MaterialGroup group;

	abstract void bindSettings();
	abstract void unbindSettings();
}

final class Material : MaterialBase
{
	Variant diffuse;
	Variant specular;
	Texture2D normal;
	bool depthWrite;
	bool hasLighting;
	bool castsShadow;

	override void bindSettings(Renderer r) 
	{
		switch(diffuse.type)
		{
			case typeid(Texture2D):
				glActiveTexture(GL_TEXTURE0);
				glBindTexture(GL_TEXTURE_2D, diffuse.peek!Texture2D().handle);
				group.effect["DiffuseTexture"].set(0);
				group.effect["UseDiffuseTexture"].set(true);
				break;
			case typeid(Vector3f):
				group.effect["Diffuse"].set(diffuse.peek!Vector3f);
				group.effect["UseDiffuseTexture"].set(false);
				break;
			default: throw new Exception("Error! Unsupported type");
		}
		switch(specular.type)
		{
			case typeid(Texture2D):
				glActiveTexture(GL_TEXTURE1);
				glBindTexture(GL_TEXTURE_2D, diffuse.peek!Texture2D().handle);
				group.effect["SpecularTexture"].set(1);
				group.effect["UseSpecularTexture"].set(true);
				break;
			case typeid(Vector3f):
				group.effect["Specular"].set(specular.peek!Vector3f);
				group.effect["UseSpecularTexture"].set(false);
				break;
			default: throw new Exception("Error! Unsupported type");
		}

		if(normal !is null)
		{
			glActiveTexture(GL_TEXTURE2);
			glBindTexture(GL_TEXTURE_2D, normal.peek!Texture2D().handle);
			group.effect["NormalTexture"].set(2);
			group.effect["UseNormalTexture"].set(true);
		}
		else group.effect["UseNormalTexture"].set(false);

		r.gl.depthMask.push(writeDepth);
	}

	override void unbindSettings() 
	{
		r.gl.depthMask.pop;
	}
}

enum VertexDataType
{
	bool_,
	ubyte_,
	byte_,
	short_,
	ushort_,
	int_,
	uint_,
	float_,
	double_
}

enum PrimitiveType
{
	triangles,
	triangleList
}

private template DetermineDataType(T)
{
	static if(is(T == bool))
		enum DetermineDataType = VertexDataType.bool_;
	else static if(is(T == ubyte))
		enum DetermineDataType = VertexDataType.ubyte_;
	else static if(is(T == byte))
		enum DetermineDataType = VertexDataType.byte_;
	else static if(is(T == short))
		enum DetermineDataType = VertexDataType.short_;
	else static if(is(T == ushort))
		enum DetermineDataType = VertexDataType.ushort_;
	else static if(is(T == int))
		enum DetermineDataType = VertexDataType.int_;
	else static if(is(T == uint))
		enum DetermineDataType = VertexDataType.uint_;
	else static if(is(T == float))
		enum DetermineDataType = VertexDataType.float_;
	else static if(is(T == double))
		enum DetermineDataType = VertexDataType.double_;
	else static if(is(T == Vector2f) || is(T == Vector3f) || is(T == Vector4f))
		enum DetermineDataType = VertexDataType.float_;
	else static if(is(T == Vector2d) || is(T == Vector3d) || is(T == Vector4d))
		enum DetermineDataType = VertexDataType.double_;
	else static assert(0, "Unsupported data type");
}

private template ElementSize(T)
{
	static if(is(T == Vector2f) || is(T == Vector2d))
		enum ElementSize = 2;
	else static if(is(T == Vector3f) || is(T == Vector3d))
		enum ElementSize = 3;
	else static if(is(T == Vector4f) || is(T == Vector4d))
		enum ElementSize = 4;
	else 
		enum ElementSize = 1;
}

private static GLenum ptToGL(PrimitiveType pt)
{
	switch(pt) with(PrimitiveType)
	{
		case triangles: return GL_TRIANGLES;
		case triangleList: return GL_TRIANGLE_STRIP;
		default: return GL_NONE;
	}
}

private static GLenum vdtToGL(VertexDataType vdt)
{
	switch(vdt) with(VertexDataType)
	{
		case bool_: return GL_BOOL;
		case ubyte_: return GL_UNSIGNED_BYTE;
		case byte_: return GL_BYTE;
		case short_: return GL_SHORT;
		case ushort_: return GL_UNSIGNED_SHORT;
		case int_: return GL_INT;
		case uint_: return GL_UNSIGNED_INT;
		case float_: return GL_FLOAT;
		case double_: return GL_DOUBLE;
		default: return GL_NONE;
	}
}

struct VertexChannel
{
	private Variant data_;
	private void* dataPtr;
	private uint bufferHandle;

	VertexDataType dataType;
	bool normalise;
	size_t vectorElemCount;
	size_t sizeInBytes;

	bool uploaded = false;

	@property void data(T)(T[] d)
	{
		data_ = d;
		dataPtr = d.ptr;
		dataType = DetermineDataType!T;
		sizeInBytes = T.sizeof * d.length;
	}

	@property T[] data(T)()
	{
		return data_.peek!(T[]);
	}

	this(T)(T[] dat, size_t vectorElemCount, bool normalise = false)
		if(!is(T == Vector))
	{
		data_ = dat;
		dataPtr = dat.ptr;
		dataType = DetermineDataType!T;
		this.normalise = normalise;
		this.vectorElemCount = vectorElemCount;
		sizeInBytes = dat.length * T.sizeof;
		glGenBuffers(1, &bufferHandle);
	}

	this(T, int N)(Vector!(T, N)[] dat, bool normalise = false)
	{
		data_ = dat;
		dataPtr = dat.ptr;
		dataType = DetermineDataType!T;
		this.normalise = normalise;
		vectorElemCount = N;
		sizeInBytes = dat.length * Vector!(T, N).sizeof;
		glGenBuffers(1, &bufferHandle);
	}

	void upload()
	{
		glBindBuffer(GL_ARRAY_BUFFER, bufferHandle);
		scope(exit) glBindBuffer(GL_ARRAY_BUFFER, 0);
		glBufferData(GL_ARRAY_BUFFER, sizeInBytes, dataPtr, GL_STATIC_DRAW);
		uploaded = true;
	}
}

class StaticModel
{
	private MaterialBase material_;
	@property MaterialBase material() { return material_; }
	@property void material(MaterialBase mb)
	{
		stdRenderer.modelMaterialChange(this, material_, mb);
		material_ = mb;
	}

	VertexChannel[] vertexChannels;
	int vertexCount;
	StandardRenderer stdRenderer;
	
	this(StandardRenderer r, Vector3f[] vertices, Vector3f[] normals, Vector2f[] texCoords = null)
	{
		stdRenderer = r;
		vertexCount = cast(int)vertices.length;
		vertexChannels ~= VertexChannel!(float, 3)(vertices, false);
		vertexChannels ~= VertexChannel!(float, 3)(normals, false);
		if(texCoords !is null)
			vertexChannels ~= VertexChannel!(float, 2)(texCoords, false);
	}
}

class LodModel
{
	StaticModel[] models;
	float[] distances;
}

class StandardRenderer : IRenderable
{
	private UnrolledList!StaticModel[][MaterialGroup] staticModels;

	void render(Renderer renderer, ref LocalContext lc, out uint drawCalls, out uint numVerts)
	{
		glBindVertexArray(vao);
		scope(exit) glBindVertexArray(0);

		foreach(i; 0 .. 3)
			glEnableVertexAttribArray(i);
		scope(exit)
			foreach_reverse(i; 0 .. 3)
				glEnableVertexAttribArray(i);

		foreach(MaterialGroup group, StaticModel[] models; staticModels)
		{
			group.effect.bind;
			scope(exit) group.effect.unbind;

			foreach(StaticModel model; models)
			{
				assert(model.vertexChannels.length >= 2);
				import std.algorithm.searching : any;
				assert(model.vertexChannels.any!(a => !a.uploaded));

				model.material_.bindSettings;
				scope(exit) model.material_.unbindSettings;

				group.effect["UseTextures"].set(model.vertexChannels.length == 3);

				foreach(uint i; 0 .. model.vertexChannels.length)
				{
					VertexChannel* c = &model.vertexChannels[i];
					glBindBuffer(GL_ARRAY_BUFFER, c.bufferHandle);
					glVertexAttribPointer(i, c.vectorElemCount, vdtToGL(c.dataType), c.normalise, 0, null);
				}
				glBindBuffer(GL_ARRAY_BUFFER, 0);

				glDrawArrays(GL_TRIANGLES, 0, model.vertexCount);

				drawCalls += 1;
				numVerts += model.vertexCount;
			}
		}
	}

	private void staticModelMaterialChange(StaticModel model, MaterialBase old, MaterialBase new_)
	{
		if(old !is null)
		{
			group = old.group;
			staticModels[group].remove(model);
		}
		staticModels[new_.group] ~= model;
	}
}