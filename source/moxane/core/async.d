module moxane.core.async;

import core.thread;
import std.datetime.stopwatch;
import core.sync.condition;
import core.sync.mutex;
import std.range.interfaces : InputRange;

import containers;

import moxane.utils.maybe;
import moxane.core.entity;

class AsyncSystem
{
	private CyclicBuffer!Fiber nextFrames;

	void awaitNextFrame(AsyncScript script) { awaitNextFrame(script.fiber); }

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

	void awaitTime(AsyncScript script, Duration dur) { awaitTime(script.fiber, dur); }

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

@trusted class Channel(T)
{
	private CyclicBuffer!T queue;
	private Condition condition;
	private Mutex mutex;
	private Object queueSyncObj;

	this()
	{
		queueSyncObj = new Object;
		mutex = new Mutex;
		condition = new Condition(mutex);
	}

	bool empty() { synchronized(queueSyncObj) return queue.empty; }

	Maybe!T tryGet()
	{
		synchronized(queueSyncObj)
		{
			if(queue.empty) return Maybe!T();

			T item = queue.front;
			queue.removeFront;
			return Maybe!T(item);
		}
	}

	Maybe!T await()
	{
		bool empty;
		synchronized(queueSyncObj)
			empty = queue.empty;

		if(empty)
			synchronized(mutex)
				condition.wait;
		synchronized(queueSyncObj)
		{
			if(queue.length == 0) return Maybe!T();

			T item = queue.front;
			queue.removeFront;
			return Maybe!T(item);
		}
	}

	void clearUnsafe() { synchronized(queueSyncObj) queue.clear; }

	void notifyUnsafe()
	{
		synchronized(mutex)
			condition.notify;
	}

	void send(T item)
	{
		synchronized(queueSyncObj)
		{
			queue.put(item);
			synchronized(mutex)
				condition.notify;
		}
	}
}