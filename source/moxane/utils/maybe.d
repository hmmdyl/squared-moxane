module moxane.utils.maybe;

import std.exception : enforce;
import std.traits;
import core.memory;

//@safe:

struct Maybe(T)
	if(is(T == struct) || isBasicType!T)
{
	private T payload;
	private bool notNull;

	this(T payload, bool isNull = false)
	{
		this.payload = payload;
		this.notNull = !isNull;
	}

	@property bool isNull() const { return !notNull; }

	void opAssign(T item)
	{
		payload = item;
		notNull = true;
	}

	T* unwrap()
	{
		enforce(notNull, "Payload is null.");
		return &payload;
	}

	T* unwrapOr()
	{
		if(!notNull) payload = T.init;
		return &payload;
	}

	T* unwrapOrElse(T def)
	{
		if(!notNull) payload = def;
		return &payload;
	}

	T* unwrapOrElse(T* def)
	{
		if(notNull) return &payload;
		else return def;
	}

	bool opEquals(ref const Maybe!T other) const
	{ return notNull == other.notNull && payload == other.payload; }
}

struct MaybePtr(T)
	if(is(PointerTarget!T* == struct) || isBasicType!(PointerTarget!T*))
{
	private T* ptr;
	private bool notNull;
	private bool safeAlloced;

	this(T* ptr)
	{
		this.ptr = ptr;
		notNull = ptr !is null;
	}

	~this()
	{
		if(safeAlloced)
		{
			GC.free(ptr);
			ptr = null;
			safeAlloced = false;
		}
	}

	T* get() { return ptr; }

	T* getSafe()
	{
		if(!notNull)
		{
			ptr = new T;
			safeAlloced = true;
		}
		return ptr;
	}

	bool opEquals(auto ref const MaybePtr!T other) const
	{ return ptr is other.ptr; }
}