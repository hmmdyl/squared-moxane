module moxane.graphics.log;

import moxane.core.log;

@safe:

class GraphicsLog : Log
{
	this()
	{
		super("graphicsLog", "Graphics");
	}
}