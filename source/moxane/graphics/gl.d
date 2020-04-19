module moxane.graphics.gl;

import moxane.core.engine;
import moxane.core.log;

import moxane.graphics.redo.resources.log;

import std.typecons : Tuple;
import std.conv : to;
import derelict.opengl3.gl3;
import std.string : fromStringz;

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
		if(s == Log.Severity.info) return;
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

		depthTest.push(false);
		depthTestExpr.push(GL_LEQUAL);
		depthMask.push(true);
		blend.push(false);
		blendEquation.push(GL_FUNC_ADD);
		blendFunc.push(Tuple!(GLenum, GLenum)(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA));
	}

	@property string rendererName() { return cast(string)fromStringz(glGetString(GL_RENDERER)); }
	@property string vendorName() { return cast(string)glGetString(GL_VENDOR).fromStringz; }
	@property string versionStr() { return cast(string)glGetString(GL_VERSION).fromStringz; }
	@property string glslVersion() { return cast(string)glGetString(GL_SHADING_LANGUAGE_VERSION).fromStringz; }

	private bool wireframe_;
	@property bool wireframe() const { return wireframe_; }
	@property void wireframe(bool w)
	{
		if(w)
			glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
		else
			glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
		wireframe_ = w;
	}

	struct blendT {
		private bool[8] stack;
		private ubyte next;
		@property bool current() {
			return stack[next-1]; }
		void pop() {
			stack[next-1] = bool.init;
			next--;
			if(next < 0) next = 0;
			bool par = stack[next]; 
			if(par) glEnable(cast(GLenum)3042);
			else glDisable(cast(GLenum)3042);	}
		void push(bool par) {
			stack[next] = par; next++;
			if(par) glEnable(cast(GLenum)3042);
			else glDisable(cast(GLenum)3042);
		}
	}
	blendT blend;


	struct blendEquationT {
		private GLenum[8] stack;
		private ubyte next;
		@property GLenum current() {
			return stack[next-1]; }
		void pop() {
			stack[next-1] = GLenum.init;
			next--;
			if(next < 0) next = 0;
			GLenum par = stack[next]; 
			glBlendEquation(par);	}
		void push(GLenum par) {
			stack[next] = par; next++;
			glBlendEquation(par);
		}
	}
	blendEquationT blendEquation;


	struct blendFuncT {
		private Tuple!(GLenum, GLenum)[8] stack;
		private ubyte next;
		@property Tuple!(GLenum, GLenum) current() {
			return stack[next-1]; }
		void pop() {
			stack[next-1] = Tuple!(GLenum, GLenum).init;
			next--;
			if(next < 0) next = 0;
			Tuple!(GLenum, GLenum) par = stack[next]; 
			glBlendFunc(par[0], par[1]);	}
		void push(Tuple!(GLenum, GLenum) par) {
			stack[next] = par; next++;
			glBlendFunc(par[0], par[1]);
		}
	}
	blendFuncT blendFunc;


	struct depthTestT {
		private bool[8] stack;
		private ubyte next;
		@property bool current() {
			return stack[next-1]; }
		void pop() {
			stack[next-1] = bool.init;
			next--;
			if(next < 0) next = 0;
			bool par = stack[next]; 
			if(par) glEnable(cast(GLenum)2929);
			else glDisable(cast(GLenum)2929);	}
		void push(bool par) {
			stack[next] = par; next++;
			if(par) glEnable(cast(GLenum)2929);
			else glDisable(cast(GLenum)2929);
		}
	}
	depthTestT depthTest;


	struct depthMaskT {
		private bool[8] stack;
		private ubyte next;
		@property bool current() {
			return stack[next-1]; }
		void pop() {
			stack[next-1] = bool.init;
			next--;
			if(next < 0) next = 0;
			bool par = stack[next]; 
			glDepthMask(par);	}
		void push(bool par) {
			stack[next] = par; next++;
			glDepthMask(par);
		}
	}
	depthMaskT depthMask;


	struct depthTestExprT {
		private GLenum[8] stack;
		private ubyte next;
		@property GLenum current() {
			return stack[next-1]; }
		void pop() {
			stack[next-1] = GLenum.init;
			next--;
			if(next < 0) next = 0;
			GLenum par = stack[next]; 
			glDepthFunc(par);	}
		void push(GLenum par) {
			stack[next] = par; next++;
			glDepthFunc(par);
		}
	}
	depthTestExprT depthTestExpr;


	struct polyModeT {
		private GLenum[8] stack;
		private ubyte next;
		@property GLenum current() {
			return stack[next-1]; }
		void pop() {
			stack[next-1] = GLenum.init;
			next--;
			if(next < 0) next = 0;
			GLenum par = stack[next]; 
			glPolygonMode(GL_FRONT_AND_BACK, par);	}
		void push(GLenum par) {
			stack[next] = par; next++;
			glPolygonMode(GL_FRONT_AND_BACK, par);
		}
	}
	polyModeT polyMode;


	/+@nogc nothrow
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
	}+/
}

/+enum GLenum {
GL_BLEND = 3042,
GL_DEPTH_TEST = 2929,
GL_SCISSOR_TEST = 3089

}

enum stackDepth = 8;

private template Setting(T, string name, string customFunction)
{
const char[] Setting = "struct " ~ name ~ "T {\n" ~
"\tprivate " ~ T.stringof ~ "[" ~ stackDepth.stringof ~ "] stack;\n" ~
"\tprivate ubyte next;\n" ~
"\t@property " ~ T.stringof ~ " current() {\n" ~
"\t\treturn stack[next-1]; }\n" ~
"\tvoid pop() {\n" ~ 
"\t\tstack[next-1] = " ~ T.stringof ~ ".init;\n" ~
"\t\tnext--;\n" ~
"\t\tif(next < 0) next = 0;\n\t\t" ~
T.stringof ~ " par = stack[next]; \n\t" ~
customFunction ~ 
"\t}\n" ~
"\tvoid push(" ~ T.stringof ~ " par) {\n" ~
"\t\tstack[next] = par; next++;\n\t" ~
customFunction ~ 
"\n\t}\n}\n" ~ name ~ "T " ~ name ~ ";\n";
}

private static string enable(GLenum enumVal)()
{
return "\tif(par) glEnable(" ~ enumVal.stringof ~ ");\n\t\telse glDisable(" ~ enumVal.stringof ~ ");";
}

void main(string[] args)
{
writeln(Setting!(bool, "blend", enable!(GLenum.GL_BLEND)));
writeln;
writeln(Setting!(GLenum, "blendEquation", "glBlendEquation(par);"));
writeln;
writeln(Setting!(Tuple!(GLenum, GLenum), "blendFunc", "glBlendFunc(par[0], par[1]);"));
writeln;
writeln(Setting!(bool, "depthTest", enable!(GLenum.GL_DEPTH_TEST)));
writeln;
writeln(Setting!(bool, "depthMask", "glDepthMask(par);"));
writeln;
writeln(Setting!(GLenum, "depthTestExpr", "glDepthFunc(par);"));
writeln;
writeln(Setting!(GLenum, "polyMode", "glPolygonMode(GL_FRONT_AND_BACK, par);"));
}+/