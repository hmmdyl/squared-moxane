module moxane.graphics.standard;

import moxane.core;
import moxane.graphics.effect;
import moxane.graphics.texture;
import moxane.graphics.renderer;
import moxane.graphics.log;

import dlib.math;
import std.variant;
import std.file : readText;
import std.exception;
import containers;

import derelict.opengl3.gl3;

final class MaterialGroup
{
	Effect effect;
}

abstract class MaterialBase
{
	MaterialGroup group;

	abstract void bindSettings(Renderer r, ref LocalContext lc, bool canUseTextures);
	abstract void unbindSettings(Renderer r, ref LocalContext lc, bool canUseTextures);
}

final class Material : MaterialBase
{
	Variant diffuse;
	Variant specular;
	Texture2D normal;
	bool depthWrite;
	bool hasLighting;
	bool castsShadow;

	this(MaterialGroup group)
	{
		super.group = group;
	}

	override void bindSettings(Renderer r, ref LocalContext lc, bool canUseTextures) 
	{
		if(diffuse.type == typeid(Texture2D) && canUseTextures)
		{
			glActiveTexture(GL_TEXTURE0);
			glBindTexture(GL_TEXTURE_2D, diffuse.peek!Texture2D().handle);
			group.effect["DiffuseTexture"].set(0);
			group.effect["UseDiffuseTexture"].set(true);
		}
		else if(diffuse.type == typeid(Vector3f))
		{
			group.effect["Diffuse"].set(diffuse.peek!Vector3f);
			group.effect["UseDiffuseTexture"].set(false);
		}
		else throw new Exception("Error! Unsupported type");

		if(diffuse.type == typeid(Texture2D) && canUseTextures)
		{
			glActiveTexture(GL_TEXTURE1);
			glBindTexture(GL_TEXTURE_2D, diffuse.peek!Texture2D().handle);
			group.effect["SpecularTexture"].set(1);
			group.effect["UseSpecularTexture"].set(true);
		}
		else if(diffuse.type == typeid(Vector3f))
		{
			group.effect["Specular"].set(specular.peek!Vector3f);
			group.effect["UseSpecularTexture"].set(false);
		}
		else throw new Exception("Error! Unsupported type");

		if(normal !is null)
		{
			glActiveTexture(GL_TEXTURE2);
			glBindTexture(GL_TEXTURE_2D, normal.handle);
			group.effect["NormalTexture"].set(2);
			group.effect["UseNormalTexture"].set(true);
		}
		else group.effect["UseNormalTexture"].set(false);

		Matrix4f mvp = lc.projection * lc.view * lc.model;
		group.effect["Model"].set(&lc.model);
		group.effect["MVP"].set(&mvp);

		//r.gl.depthMask.push(depthWrite);
	}

	override void unbindSettings(Renderer r, ref LocalContext lc, bool canUseTextures) 
	{
		//r.gl.depthMask.pop;
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
	triangles = GL_TRIANGLES,
	triangleList = GL_TRIANGLE_STRIP,
	lines = GL_LINES
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

struct LinesConfig
{
	float width;
}

struct VertexChannel
{
	private Variant data_;
	private void* dataPtr;
	private uint bufferHandle;

	VertexDataType dataType;
	bool normalise;
	int vectorElemCount;
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

	static void create(T)(T[] dat, int vectorElemCount, bool normalise = false)
		if(!is(T == Vector))
	{
		VertexChannel c;
		c.data_ = dat;
		c.dataPtr = dat.ptr;
		c.dataType = DetermineDataType!T;
		c.normalise = normalise;
		c.vectorElemCount = vectorElemCount;
		c.sizeInBytes = dat.length * T.sizeof;
		glGenBuffers(1, &c.bufferHandle);
		return c;
	}

	static VertexChannel create(T, int N)(Vector!(T, N)[] dat, bool normalise = false)
	{
		VertexChannel c;
		c.data_ = dat;
		c.dataPtr = dat.ptr;
		c.dataType = DetermineDataType!T;
		c.normalise = normalise;
		c.vectorElemCount = N;
		c.sizeInBytes = dat.length * Vector!(T, N).sizeof;
		glGenBuffers(1, &c.bufferHandle);
		return c;
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
		stdRenderer.staticModelMaterialChange(this, material_, mb);
		material_ = mb;
	}

	immutable PrimitiveType primitiveType;
	VertexChannel[] vertexChannels;
	int vertexCount;
	StandardRenderer stdRenderer;

	Variant renderConfig;

	Transform localTransform;
	Transform finalTransform;
	
	this(StandardRenderer r, Material material, Vector3f[] vertices, Vector3f[] normals, Vector2f[] texCoords = null, PrimitiveType primitiveType = PrimitiveType.triangles)
	{
		this.primitiveType = primitiveType;
		stdRenderer = r;
		this.material_ = material;
		vertexCount = cast(int)vertices.length;
		vertexChannels ~= VertexChannel.create!(float, 3)(vertices, false);
		vertexChannels ~= VertexChannel.create!(float, 3)(normals, false);
		if(texCoords !is null)
			vertexChannels ~= VertexChannel.create!(float, 2)(texCoords, false);
		foreach(c; vertexChannels) c.upload;
	}
}

class LodModel
{
	StaticModel[] models;
	float[] distances;
}

class StandardRenderer : IRenderable
{
	private uint vao;
	private UnrolledList!StaticModel[MaterialGroup] staticModels;

	Moxane moxane;
	this(Moxane moxane)
	{
		this.moxane = moxane;
		glGenVertexArrays(1, &vao);
	}
	
	private MaterialGroup standardMaterial_;
	private void createStandardMaterial()
	{
		Log log = moxane.services.getAOrB!(GraphicsLog, Log);
		Shader vs = new Shader, fs = new Shader;
		enforce(vs.compile(readText(AssetManager.translateToAbsoluteDir("content/moxane/shaders/standardMaterial.vs.glsl")), GL_VERTEX_SHADER, log));
		enforce(fs.compile(readText(AssetManager.translateToAbsoluteDir("content/moxane/shaders/standardMaterial.fs.glsl")), GL_FRAGMENT_SHADER, log));
		standardMaterial_ = new MaterialGroup;
		standardMaterial_.effect = new Effect(moxane, "StandardMaterialEffect");
		standardMaterial_.effect.attachAndLink(vs, fs);
		standardMaterial_.effect.bind;
		standardMaterial_.effect.findUniform("Model");
		standardMaterial_.effect.findUniform("MVP");
		standardMaterial_.effect.findUniform("DiffuseTexture");
		standardMaterial_.effect.findUniform("Diffuse");
		standardMaterial_.effect.findUniform("UseDiffuseTexture");
		standardMaterial_.effect.findUniform("SpecularTexture");
		standardMaterial_.effect.findUniform("Specular");
		standardMaterial_.effect.findUniform("UseSpecularTexture");
		standardMaterial_.effect.findUniform("NormalTexture");
		standardMaterial_.effect.findUniform("UseNormalTexture");
		standardMaterial_.effect.findUniform("Model");
		standardMaterial_.effect.findUniform("MVP");
		standardMaterial_.effect.unbind;
	}
	@property MaterialGroup standardMaterialGroup() { if(standardMaterial_ is null) createStandardMaterial(); return standardMaterial_; }

	void render(Renderer renderer, ref LocalContext lc, out uint drawCalls, out uint numVerts)
	{
		glBindVertexArray(vao);
		scope(exit) glBindVertexArray(0);

		foreach(i; 0 .. 2)
			glEnableVertexAttribArray(i);
		scope(exit)
			foreach_reverse(i; 0 .. 2)
				glDisableVertexAttribArray(i);

		foreach(MaterialGroup group, ref UnrolledList!StaticModel models; staticModels)
		{
			group.effect.bind;
			scope(exit) group.effect.unbind;

			foreach(StaticModel model; models)
			{
				assert(model.vertexChannels.length >= 2);
				import std.algorithm.searching : any;
				assert(model.vertexChannels.any!(a => !a.uploaded));

				LocalContext lc1 = lc;
				lc1.model *= model.finalTransform.matrix;
				model.material_.bindSettings(renderer, lc1, model.vertexChannels.length > 2);
				scope(exit) model.material_.unbindSettings(renderer, lc1, model.vertexChannels.length > 2);

				foreach(uint i; 0 .. cast(uint)model.vertexChannels.length)
				{
					VertexChannel* c = &model.vertexChannels[i];
					glBindBuffer(GL_ARRAY_BUFFER, c.bufferHandle);
					glVertexAttribPointer(i, c.vectorElemCount, vdtToGL(c.dataType), c.normalise, 0, null);
				}
				glBindBuffer(GL_ARRAY_BUFFER, 0);

				if(model.renderConfig.type == typeid(LinesConfig))
				{
					glLineWidth(model.renderConfig.peek!LinesConfig().width);
				}

				glDrawArrays(cast(GLenum)model.primitiveType, 0, model.vertexCount);

				drawCalls += 1;
				numVerts += model.vertexCount;
			}
		}
	}

	void addStaticModel(StaticModel model)
	{
		if((model.material.group in staticModels) is null) staticModels[model.material.group] = UnrolledList!StaticModel();
		staticModels[model.material.group].insertBack(model);
	}

	bool hasModel(StaticModel model)
	{
		foreach(StaticModel candidate; staticModels[model.material.group])
			if(candidate == model)
				return true;
		return false;
	}

	void removeModel(StaticModel model)
	{
		staticModels[model.material.group].remove(model);
	}

	private void staticModelMaterialChange(StaticModel model, MaterialBase old, MaterialBase new_)
	{
		if(old is new_) return;
		if(old !is null)
		{
			staticModels[old.group].remove(model);
		}
		staticModels[new_.group].insertBack(model);
	}
}