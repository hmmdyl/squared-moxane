module moxane.utils.pool;

import std.container.array;

@safe:

struct Pool(T)
{
	T delegate() constructor;

	bool expands;
	private Array!T arr;
	private Object obj;

	this(T delegate() @safe constructor, int defaultAmount = 8, bool expands = true) @trusted
	{
		this.constructor = constructor;
		this.expands = expands;
		obj = new Object;

		arr.reserve(defaultAmount);
		foreach(i; 0 .. defaultAmount)
			arr.insertBack(constructor());
	}

	T get()
	{
		synchronized(obj)
		{
			if(arr.length == 0)
			{
				if(expands)
					return constructor();
				else return null;
			}

			T item = arr.back;
			arr.removeBack;
			return item;
		}
	}

	void give(T item) @trusted
	in { assert(item !is null); }
	do {
		synchronized(obj)
			arr.insertBack(item);
	}
}