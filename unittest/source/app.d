import std.stdio;

import moxane.core.engine;
import moxane.core.log;
import moxane.graphics.renderer;
import moxane.io.window;
import moxane.core.asset;

import dlib.math;

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
	
	while(!win.shouldClose)
	{
		r.render;
	
		win.swapBuffers;
		win.pollEvents;
	}
}
