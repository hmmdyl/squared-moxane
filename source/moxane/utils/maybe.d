module moxane.utils.maybe;

import std.exception : enforce;

struct Maybe(T)
{
	private T payload;
	private bool isNull;

	T* unwrap()
	{
		enforce(!isNull, "Payload is null.");
		return &payload;
	}

	T* unwrapOr(T nulled = T.init)
	{

	}
}