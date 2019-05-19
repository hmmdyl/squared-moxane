import std.stdio;

import moxane.core.engine;
import moxane.core.log;
import moxane.graphics.renderer;
import moxane.io.window;
import moxane.core.asset;

import moxane.graphics.imgui;

import dlib.math;

class BasicWin : IImguiRenderable
{
	float dummy = 0.5f;
	float[4] col;

	this()
	{
		col[] = 1f;
	}

	void renderUI(ImguiRenderer r0, Renderer r1, ref LocalContext lc)
	{
		import derelict.imgui.imgui;
		igBegin("THE HELLO");
		igText("HELLO WORLD");
		igButton("Test");
		igSameLine();
		igSliderFloat("Yeetus", &dummy, 0f, 1f);
		igColorEdit4("Color", col);
		igTextColored(ImVec4(col[0], col[1], col[2], 1f), "Stuff");
		igEnd();
	}
}

void main()
{
	const MoxaneBootSettings settings = 
	{
		logSystem : true,
		windowSystem : true,
		graphicsSystem : true,
		assetSystem : true,
		physicsSystem : false,
		networkSystem : false,
		settingsSystem : false,
		asyncSystem : false
	};
	Moxane moxane = new Moxane(settings);
	
	Log log = moxane.services.get!Log;
	log.write(Log.Severity.debug_, "Hello");

	Window win = moxane.services.get!Window;
	Renderer r = moxane.services.get!Renderer;

	win.onFramebufferResize.add((win, size) => {
		r.primaryCamera.width = size.x;
		r.primaryCamera.height = size.y;
		r.cameraUpdated;
	}());

	ImguiRenderer imgui = new ImguiRenderer(moxane);
	r.uiRenderables ~= imgui;

	BasicWin imguiWin = new BasicWin;
	imgui.renderables ~= imguiWin;
	
	while(!win.shouldClose)
	{
		r.render;
	
		win.swapBuffers;
		win.pollEvents;
	}
}
