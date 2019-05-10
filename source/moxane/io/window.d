module moxane.io.window;

import moxane.io.kbm;
import moxane.core.engine;
import moxane.core.log;
import moxane.core.event;

import derelict.glfw3;
import derelict.opengl3.gl3;
import dlib.math;
import std.string;
import std.conv;

struct ApiBoot 
{
	uint openGLMinor;
	uint openGLMajor;
	bool createOpenGL;
	bool openGLUseCoreProfile;

	static ApiBoot createOpenGL4Core() 
	{
		ApiBoot a;
		a.openGLMajor = 4;
		a.openGLMinor = 0;
		a.createOpenGL = true;
		a.openGLUseCoreProfile = true;
		return a;
	}

	static ApiBoot createOpenGL43Core() 
	{
		ApiBoot a = createOpenGL4Core;
		a.openGLMinor = 3;
		return a;
	}

	static ApiBoot createOpenGL46Core()
	{
		ApiBoot a =createOpenGL4Core;
		a.openGLMinor = 6;
		return a;
	}
}

struct WindowBoot 
{
	int width;
	int height;
	string title;
	bool fullscreen;

	this(int width, int height, string title, bool fullscreen = false) 
	{
		this.width = width;
		this.height = height;
		this.title = title;
		this.fullscreen = fullscreen;
	}
}


final class Window 
{
	private GLFWwindow* ptr;

	Event!(Window, Vector2i) onResize;
	Event!(Window, Vector2i) onMove;
	Event!(Window, bool) onIconify;
	Event!(Window, Vector2i) onFramebufferResize;
	Event!(Window, bool) onFocus;
	Event!(Window, Vector2d) onMouseMove;
	Event!(Window, MouseButton, ButtonAction) onMouseButton;
	Event!(Window, Keys, ButtonAction) onKey;

	private int windowedWidth, windowedHeight;
	private int windowedX, windowedY;

	Moxane moxane;

	this(Moxane moxane, WindowBoot windowBoot, ApiBoot apiBoot) 
	{
		this.moxane = moxane;
		Log log = moxane.services.get!Log;
		log.write(Log.Severity.info, "Loading windowing lib");
		if(glfwInit() != GLFW_TRUE)
		{
			log.write(Log.Severity.panic, "Nein");

			throw new Exception("Could not initialise GLFW3!");
		}

		log.write(Log.Severity.info, "Loaded windowing lib. Creating window");

		windowedWidth = windowBoot.width;
		windowedHeight = windowBoot.height;

		if(apiBoot.createOpenGL)
		{
			glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, apiBoot.openGLMajor);
			glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, apiBoot.openGLMinor);
			glfwWindowHint(GLFW_OPENGL_PROFILE, apiBoot.openGLUseCoreProfile ? GLFW_OPENGL_CORE_PROFILE : GLFW_OPENGL_COMPAT_PROFILE);
		}
		else throw new Exception("Error not implemented!");

		ptr = glfwCreateWindow(windowedWidth, windowedHeight, toStringz(windowBoot.title), null, null);
		glfwMakeContextCurrent(ptr);
		glfwShowWindow(ptr);

		if(apiBoot.createOpenGL)
			DerelictGL3.reload;
		glfwMakeContextCurrent(ptr);

		glfwSetWindowUserPointer(ptr, cast(void*)this);
		glfwSetWindowSizeCallback(ptr, &onResizeCallback);
		glfwSetFramebufferSizeCallback(ptr, &onFramebufferResizeCallback);
		glfwSetWindowPosCallback(ptr, &onMoveCallback);
		glfwSetWindowFocusCallback(ptr, &onFocusCallback);
		glfwSetWindowIconifyCallback(ptr, &onIconifyCallback);
		glfwSetCursorPosCallback(ptr, &onMouseMoveCallback);
		glfwSetMouseButtonCallback(ptr, &onMouseButtonCallback);
		glfwSetKeyCallback(ptr, &onKeyCallback);

		windowedX = position.x;
		windowedY = position.y;

		//glfwSwapInterval(16);

		log.write(Log.Severity.info, "Created window");
	}

	~this() 
	{
		glfwDestroyWindow(ptr);
	}

	bool isFullscreen = false;

	void fullscreen(bool full, int width = 0, int height = 0) 
	{
		if(!((width > 0 && height > 0) || (width == 0 && height == 0)))
			throw new Exception("[window.fullscreen] Both width and height must be 0, 0 or both greater than zero.");

		if(full) 
		{
			{
				windowedWidth = size.x;
				windowedHeight = size.y;
				Vector2i pos = position;
				windowedX = pos.x;
				windowedY = pos.y;
			}

			if(width > 0 && height > 0) 
			{
				int vc;
				const GLFWvidmode* modes = glfwGetVideoModes(glfwGetPrimaryMonitor(), &vc);

				foreach(int i; 0 .. vc) 
				{
					if(modes[i].width == width && modes[i].height == height) 
					{
						glfwSetWindowMonitor(ptr, glfwGetPrimaryMonitor(), 0, 0, modes[i].width, modes[i].height, modes[i].refreshRate);
						isFullscreen = true;
						return;
					}
				}

				throw new Exception("[window.fullscren] Could not set to fullscreen because size " ~ to!string(width) ~ "," ~ to!string(height) ~ " does not match a video mode.");
			}
			else 
			{
				const GLFWvidmode* mode = glfwGetVideoMode(glfwGetPrimaryMonitor());
				glfwSetWindowMonitor(ptr, glfwGetPrimaryMonitor(), 0, 0, mode.width, mode.height, mode.refreshRate);
				isFullscreen = true;
				return;
			}
		}
		else 
		{
			glfwSetWindowMonitor(ptr, null, windowedX, windowedY, windowedWidth, windowedHeight, 0);
			isFullscreen = false;
		}
	}

	void swapBuffers() { glfwSwapBuffers(ptr); }

	@property Vector2i position()  {
		int x, y;
		glfwGetWindowPos(ptr, &x, &y);
		return Vector2i(x, y);
	}

	@property Vector2i size() {
		int w, h;
		glfwGetWindowSize(ptr, &w, &h);
		return Vector2i(w, h);
	}

	@property void size(Vector2i s) {
		glfwSetWindowSize(ptr, s.x, s.y);
	}

	@property Vector2i framebufferSize() { 
		int w, h;
		glfwGetFramebufferSize(ptr, &w, &h);
		return Vector2i(w, h);
	}

	@property bool isFocused() {
		return cast(bool)glfwGetWindowAttrib(ptr, GLFW_FOCUSED);
	}

	@property bool isIconified() {
		return cast(bool)glfwGetWindowAttrib(ptr, GLFW_ICONIFIED);
	}

	@property bool shouldClose() { return glfwWindowShouldClose(ptr) == GLFW_TRUE; }

	void pollEvents() { glfwPollEvents(); }

	@property Vector2d cursorPos() {
		Vector2d c;
		glfwGetCursorPos(ptr, &c.x, &c.y);
		return c;
	}

	@property void cursorPos(Vector2d c) {
		glfwSetCursorPos(ptr, c.x, c.y);
	}

	@property Vector2d centrePos() {
		Vector2d c;
		c.x = position.x + (size.x / 2.0);
		c.y = position.y + (size.y / 2.0);

		import std.stdio;
		writeln("Position: ", position);
		writeln("Size: ", size);
		writeln("Centre: ", c);

		return c;
	}

	@property bool isKeyDown(int key) { return glfwGetKey(ptr, key) == GLFW_PRESS; }
	@property bool isKeyDown(Keys key) { return isKeyDown(cast(int)key); }

	@property bool isMouseButtonDown(int mb) { return glfwGetMouseButton(ptr, mb) == GLFW_PRESS; }
	@property bool isMouseButtonDown(MouseButton mb) { return isMouseButtonDown(cast(int)mb); }

	private bool hideCursor_ = false;
	@property bool hideCursor() { return hideCursor_; }
	@property void hideCursor(bool v) { 
		hideCursor_ = v;
		if(v)
			glfwSetInputMode(ptr, GLFW_CURSOR, GLFW_CURSOR_HIDDEN);
		else
			glfwSetInputMode(ptr, GLFW_CURSOR, GLFW_CURSOR_NORMAL);
	}
}

private:

Window getWindowFromPtr(GLFWwindow* ptr) nothrow 
{
	return cast(Window)glfwGetWindowUserPointer(ptr);
}

extern(C) nothrow 
{
	void onResizeCallback(GLFWwindow* win, int x, int y) 
	{
		try 
		{
			Window winclass = getWindowFromPtr(win);
			winclass.onResize.emit(winclass, Vector2i(x, y));
		}
		catch(Exception) { }
	}

	void onMoveCallback(GLFWwindow* win, int x, int y) 
	{
		try 
		{
			Window winclass = getWindowFromPtr(win);
			winclass.onMove.emit(winclass, Vector2i(x, y));
		}
		catch(Exception) {}
	}

	void onIconifyCallback(GLFWwindow* win, int inconified) 
	{
		try 
		{
			Window winclass = getWindowFromPtr(win);
			winclass.onIconify.emit(winclass, cast(bool)inconified);
		}
		catch(Exception) {}
	}

	void onFramebufferResizeCallback(GLFWwindow* win, int w, int h) 
	{
		try
		{
			Window winclass = getWindowFromPtr(win);
			winclass.onFramebufferResize.emit(winclass, Vector2i(w, h));
		}
		catch(Exception) {}
	}

	void onFocusCallback(GLFWwindow* win, int state) 
	{
		try 
		{
			Window winclass = getWindowFromPtr(win);
			winclass.onFocus.emit(winclass, cast(bool)state);
		}
		catch(Exception) {}
	}

	void onMouseMoveCallback(GLFWwindow* win, double x, double y) 
	{
		try 
		{
			Window winclass = getWindowFromPtr(win);
			winclass.onMouseMove.emit(winclass, Vector2d(x, y));
		}
		catch(Exception) {}
	}

	void onMouseButtonCallback(GLFWwindow* win, int button, int action, int mods) 
	{
		try 
		{
			Window winclass = getWindowFromPtr(win);
			winclass.onMouseButton.emit(winclass, cast(MouseButton)button, cast(ButtonAction)action);
		}
		catch(Exception) {}
	}

	void onKeyCallback(GLFWwindow* win, int key, int scancode, int action, int mods) 
	{
		try 
		{
			Window winclass = getWindowFromPtr(win);
			winclass.onKey.emit(winclass, cast(Keys)key, cast(ButtonAction)action);
		}
		catch(Exception) {}
	}
}