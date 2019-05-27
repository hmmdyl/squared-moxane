module moxane.core.eventwaiter;

import moxane.core.entity : AsyncScript;

import core.thread : Fiber;

import containers;

@safe:

@trusted struct EventWaiterSimple(T)
{
	private UnrolledList!Fiber waits;
	private alias EventSlot = void delegate(ref T);
	private DynamicArray!EventSlot slots;

	T data;

	void await(Fiber fiber)
	{
		waits ~= fiber;
		fiber.yield;
	}

	private void fireWaits()
	{
		foreach(Fiber f; waits)
			f.call;
		waits.clear;
	}

	void addCallback(EventSlot callback)
	{
		slots ~= callback;
	}

	void removeCallback(EventSlot callback)
	{
		size_t index;
		bool found = false;
		foreach(size_t i, EventSlot c; slots)
		{
			if(c == callback)
			{
				found = true;
				index = i;
				break;
			}
		}
		if(found) slots.remove(index);
		else throw new Exception("Callback has not been added. Cannot remove.");
	}

	private void fireCallbacks(ref T t)
	{
		foreach(c; slots) c(t);
	}

	void emit(ref T t)
	{
		data = t;
		fireCallbacks(t);
		fireWaits;
	}

	void emit(T t) // apparently r-values cannot be passed by ref.
	{
		emit(t);
	}

	void opOpAssign(string op)(EventSlot c) if(op == "~")
	{
		addCallback(c);
	}

	void opOpAssign(string op)(Fiber f) if(op == "~")
	{
		await(f);
	}

	void opOpAssign(string op)(EventSlot c) if(op == "-")
	{
		removeCallback(c);
	}
}

struct EventWaiter(T)
{
	EventWaiterSimple!T evs;
	alias evs this;

	void addAsyncScript(AsyncScript p)
	{
		await(p.fiber);
	}
}