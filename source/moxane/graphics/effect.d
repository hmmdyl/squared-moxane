module moxane.graphics.effect;

import derelict.opengl3.gl3;
import dlib.math;

import moxane.core.engine;
import moxane.core.log;
import moxane.graphics.log;
import moxane.core.asset;

import std.string : toStringz, strip;

struct EffectUniform
{
	string name;
	GLint location;

	this(string name, GLint location)
	{
		this.name = name;
		this.location = location;
	}

	public void set(bool v) { glUniform1i(location, cast(int)v); }

	public void set(int v) { glUniform1i(location, v); }
	public void set(uint v) { glUniform1ui(location, v); }
	public void set(float v) { glUniform1f(location, v); }
	public void set(double v) { glUniform1d(location, v); }

	public void set(Vector2f v) { glUniform2f(location, v.x, v.y); }
	public void set(Vector2f* v) { glUniform2fv(location, 1, v.arrayof.ptr); }
	public void set(Vector2d v) { glUniform2d(location, v.x, v.y); }
	public void set(Vector2d* v) { glUniform2dv(location, 1, v.arrayof.ptr); }
	void set(Vector2i v) { glUniform2i(location, v.x, v.y); }

	public void set(Vector3f v) { glUniform3f(location, v.x, v.y, v.z); }
	public void set(Vector3f* v) { glUniform3fv(location, 1, v.arrayof.ptr); }
	public void set(Vector3d v) { glUniform3d(location, v.x, v.y, v.z); }
	public void set(Vector3d* v) { glUniform3dv(location, 1, v.arrayof.ptr); }

	public void set(Vector4f v) { glUniform4f(location, v.x, v.y, v.z, v.w); }
	public void set(Vector4f* v) { glUniform4fv(location, 1, v.arrayof.ptr); }
	public void set(Vector4d v) { glUniform4d(location, v.x, v.y, v.z, v.w); }
	public void set(Vector4d* v) { glUniform4dv(location, 1, v.arrayof.ptr); }

	public void set(Matrix4f* m, bool transpose = false) { glUniformMatrix4fv(location, 1, transpose, m.arrayof.ptr); }
}

GLenum strToShaderType(string shaderType)
{
	switch(shaderType)
	{
		case "GL_VERTEX_SHADER": return GL_VERTEX_SHADER;
		case "GL_FRAGMENT_SHADER": return GL_FRAGMENT_SHADER;
		default: return GL_NONE;
	}
}

class ShaderLoader : IAssetLoader
{
	Object handle(AssetManager am, TypeInfo ti, string dir)
	{
		assert(typeid(Shader) == ti);

		Log log = am.moxane.services.getAOrB!(GraphicsLog, Log);
		Shader shader = new Shader;
	
		import std.file : readText;
		import std.algorithm.searching : countUntil;

		string fullFile = readText(AssetManager.translateToAbsoluteDir(dir));
		auto firstBreakIndex = countUntil(fullFile, '\n');
		string type = fullFile[0 .. firstBreakIndex];
		string sourceCode = fullFile[firstBreakIndex .. $];
		//log.write(Log.Severity.debug_, sourceCode);

		GLenum shaderType = strToShaderType(strip(fullFile[0..firstBreakIndex]));

		shader.compile(sourceCode, shaderType, log);

		return shader;
	}
}

class Shader
{
	GLuint id;
	GLenum shaderType;
	private bool compiled_;
	@property bool compiled() const { return compiled_; }

	private bool disposed_;
	~this() { if(!disposed_) dispose; }
	void dispose() { if(compiled_) glDeleteShader(id); }

	bool compile(string sourceCode, GLenum shaderType, Log log = null)
	{
		assert(!compiled_);

		this.shaderType = shaderType;
		id = glCreateShader(shaderType);

		const immutable(char)* src = toStringz(sourceCode);
		glShaderSource(id, 1, &src, null);
		glCompileShader(id);

		GLint cs;
		glGetShaderiv(id, GL_COMPILE_STATUS, &cs);
		if(cs != GL_TRUE)
		{
			char[] logBuffer = new char[](1024);
			int len;
			glGetShaderInfoLog(id, 1024, &len, logBuffer.ptr);
			string strLog = cast(string)logBuffer[0 .. len];
			if(log !is null)
				log.write(Log.Severity.error, "Cannot compile OpenGL shader. " ~ strLog);
			return false;
		}
		compiled_ = true;
		return true;
	}
}

class Effect
{
	GLuint id;
	Moxane moxane;
	string effectName;

	private EffectUniform[string] uniforms;

	this(Moxane moxane, string effectName = null)
	{
		this.moxane = moxane;
		this.effectName = effectName;
		id = glCreateProgram();
	}

	~this()
	{
		glDeleteProgram(id);
	}

	void attachAndLink(Shader[] shader ...)
	{
		foreach(s; shader)
			attach(s);
		link;
	}

	void attach(Shader shader)
	{
		assert(shader.compiled);
		glAttachShader(id, shader.id);
	}

	bool link()
	{
		glLinkProgram(id);
		int result;
		glGetProgramiv(id, GL_LINK_STATUS, &result);
		if(result != GL_TRUE)
		{
			char[1024] logBuffer;
			int len;
			glGetProgramInfoLog(id, 1024, &len, logBuffer.ptr);
			string strLog = cast(string)logBuffer[0..len];

			Log log = moxane.services.getAOrB!(GraphicsLog, Log);
			log.write(Log.Severity.error, "Effect failed to link. " ~ strLog);
			return false;
		}
		return true;
	}

	void findUniform(string name)
	{
		int loc = glGetUniformLocation(id, toStringz(name));
		if(loc == -1)
			moxane.services.getAOrB!(GraphicsLog, Log)().write(Log.Severity.warning, "Could not get uniform " ~ name ~ " for effect " ~ effectName);
		uniforms[name] = EffectUniform(name, loc);
	}

	void bind() { glUseProgram(id); }
	void unbind() { glUseProgram(0); }

	public EffectUniform opIndex(string name)
	{
		return uniforms[name];	
	}

	/*public EffectUniform opDispatch(string name)()
	{
		return this[name];
	}*/
}