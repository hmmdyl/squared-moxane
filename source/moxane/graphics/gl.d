module moxane.graphics.gl;

import moxane.core.engine;
import moxane.core.log;

import moxane.graphics.log;

import std.typecons : Tuple;
import std.conv : to;
import derelict.opengl3.gl3;

enum stackDepth = 8;

private template Setting(T, string name, string customFunction)
{
	const char[] Setting = "struct " ~ name ~ "T {" ~
		"private " ~ T.stringof ~ "[" ~ stackDepth.stringof ~ "] stack;" ~
		"private ubyte next;" ~
		"@property " ~ T.stringof ~ " current() {" ~
		"return stack[next-1]; }" ~
		"void pop() {" ~ 
		"stack[next-1] = " ~ T.stringof ~ ".init;" ~
		"next--;" ~
		"if(next < 0) next = 0;" ~
		T.stringof ~ " par = stack[next]; " ~
		customFunction ~ 
		"}" ~
		"void push(" ~ T.stringof ~ " par) {" ~
		"stack[next] = par; next++;" ~
		customFunction ~ 
		"}} " ~ name ~ "T " ~ name ~ ";";
}

private static string enable(GLenum enumVal)()
{
	return "if(par) glEnable(" ~ enumVal.stringof ~ "); else glDisable(" ~ enumVal.stringof ~ ");";
}

private static extern(Windows) nothrow void debugCallback(GLenum source, GLenum type, GLuint id, GLenum severity, GLsizei length, in GLchar* message, GLvoid* userParam)
{
	try {
		GLState state = cast(GLState)userParam;
		//assert(userParam == cast(void*)this);
		Log log = state.moxane.services.getAOrB!(GraphicsLog, Log)();

		import std.format : format;
		import std.string : fromStringz;
		string msg = format("%s, %s, %s, %s", to!string(source), to!string(type), to!string(id), cast(string)fromStringz(message));
		Log.Severity s;
		final switch(severity) 
		{
			case GL_DEBUG_SEVERITY_HIGH: s = Log.Severity.error; break;
			case GL_DEBUG_SEVERITY_MEDIUM: s = Log.Severity.warning; break;
			case GL_DEBUG_SEVERITY_LOW: s = Log.Severity.warning; break;
			case GL_DEBUG_SEVERITY_NOTIFICATION: s = Log.Severity.info; break;
		}
		log.write(s, msg);
	}
	catch(Exception e)
	{}
}

class GLState
{
	Moxane moxane;

	this(Moxane moxane, bool bindDebugCallback = false)
	{
		this.moxane = moxane;
		if(bindDebugCallback)
		{
			glEnable(GL_DEBUG_OUTPUT);
			glDebugMessageCallback(&debugCallback, cast(void*)this);
		}
	}

	@nogc nothrow
	{
		mixin(Setting!(bool, "blend", enable!GL_BLEND));
		mixin(Setting!(GLenum, "blendEquation", "glBlendEquation(par);"));
		mixin(Setting!(Tuple!(GLenum, GLenum), "blendFunc", "glBlendFunc(par[0], par[1]);"));
		mixin(Setting!(bool, "depthTest", enable!GL_DEPTH_TEST));
		mixin(Setting!(bool, "depthMask", "glDepthMask(par);"));
		mixin(Setting!(GLenum, "depthTestExpr", "glDepthFunc(par);"));
		mixin(Setting!(GLenum, "polyMode", "glPolygonMode(GL_FRONT_AND_BACK, par);"));
		mixin(Setting!(bool, "scissorTest", enable!GL_SCISSOR_TEST));

		mixin(Setting!(bool, "texture2D", enable!GL_TEXTURE_2D));
		mixin(Setting!(bool, "texture2DArray", enable!GL_TEXTURE_2D_ARRAY));
	}
}