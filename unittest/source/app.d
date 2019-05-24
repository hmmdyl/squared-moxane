import std.stdio;

import moxane.core.engine;
import moxane.core.log;
import moxane.graphics.renderer;
import moxane.io.window;
import moxane.core.asset;

import moxane.graphics.imgui;

import dlib.math;

import std.datetime.stopwatch;

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
//		import derelict.imgui.imgui;
		import cimgui.funcs;
		import cimgui.types;
		import cimgui.imgui;
		igShowAboutWindow();
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
		r.uiCamera.width = size.x;
		r.uiCamera.height = size.y;
		r.uiCamera.deduceOrtho;
		r.uiCamera.buildProjection;
		r.cameraUpdated;
	}());

	ImguiRenderer imgui = new ImguiRenderer(moxane);
	r.uiRenderables ~= imgui;

	BasicWin imguiWin = new BasicWin;
	RendererDebugAttachment rda = new RendererDebugAttachment(r);
	imgui.renderables ~= imguiWin;
	imgui.renderables ~= rda;

	StopWatch sw = StopWatch(AutoStart.yes);
	StopWatch oneSecond = StopWatch(AutoStart.yes);
	int frameCount = 0;

	while(!win.shouldClose)
	{
		sw.stop;
		moxane.deltaTime = sw.peek.total!"nsecs" / 1_000_000_000f;
	
		if(oneSecond.peek.total!"msecs" >= 1000)
		{
			oneSecond.reset;
			moxane.frames = frameCount;
			frameCount = 0;
		}

		frameCount++;

		sw.reset;
		sw.start;

		r.render;
	
		win.swapBuffers;
		win.pollEvents;
	}
}
