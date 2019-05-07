module moxane.core.async;

import core.thread;
import std.datetime.stopwatch;

import containers;

class AsyncSystem
{
	private CyclicBuffer!Fiber nextFrames;

	void awaitNextFrame(Fiber fiber)
	{
		nextFrames.insertBack(fiber);
		fiber.yield;
	}

	void callAllNextFrame() 
	{
		size_t length = nextFrames.length;
		foreach(i; 0 .. length)
		{
			Fiber fiber = nextFrames.front;
			nextFrames.removeFront;
			fiber.call;
		}
	}

	private struct FiberWaitTime 
	{
		Duration dur;
		StopWatch sw;
		Fiber fiber;

		this(Fiber fiber, Duration dur)
		{
			this.fiber = fiber;
			this.dur = dur;
			this.sw = StopWatch(AutoStart.yes);
		}
	}

	private UnrolledList!FiberWaitTime fiberWaitTimes;

	void awaitTime(Fiber fiber, Duration dur)
	{
		fiberWaitTimes.insertBack(FiberWaitTime(fiber, dur));
		fiber.yield;
	}

	void callAllWaitTime()
	{
		foreach(FiberWaitTime fwt; fiberWaitTimes)
		{
			if(fwt.sw.peek >= fwt.dur)
			{
				fwt.fiber.call;
				fiberWaitTimes.remove(fwt);
			}
		}
	}
}