module moxane.utils.sharedwrap;

import dlib.math.vector;
import std.conv;

mixin template SharedPropertyDirtyVector(T, int N, string propertyName)
{
	static foreach(i; 0 .. N)
		mixin("private shared " ~ T.stringof ~ " " ~ propertyName ~ "_" ~ to!string(i) ~ ";");
	mixin("@property Vector!(" ~ T.stringof ~ ", " ~ to!string(N) ~ ") " ~ propertyName ~ "const {
			Vector!(T" ~ T.stringof ~ ", " ~ to!string(N) ~ ") ret; ");
	static foreach(i; 0 .. N)
		mixin("ret[" ~ to!string(i) ~ "] = atomicLoad(" ~ propertyName ~ "_" ~ to!string(i) ~ "); ");
	mixin("return ret; }");
	mixin("private shared bool " ~ propertyName ~ "_dirty;");
	mixin("private @property bool " ~ propertyName ~ "Dirty(bool clear = true) { 
			if(clear) 
			{
				scope(exit) atomicStore(" ~ propertyName ~ "_dirty, false);
				return atomicLoad(" ~ propertyName ~ "_dirty); 
			} else return atomicLoad(" ~ propertyName ~ "_dirty); }");
	mixin("@property void " ~ propertyName ~ "(Vector!(" ~ T.stringof ~ ", " ~ to!string(N) ~ ") val) {");
	static foreach(i; 0 .. N)
		mixin("atomicStore(" ~ propertyName ~ "_" ~ to!string(i) ~ ", val.arrayof[" ~ to!string ~ "]); ");
	mixin("}");
}

template SharedProperty(T, string propertyName)
{
	static if(is(T == Vector3f))
	{
		const char[] SharedProperty = "private shared float " ~ propertyName ~ "_x;" ~
			"private shared float " ~ propertyName ~ "_y;" ~
			"private shared float " ~ propertyName ~ "_z;" ~
			"@property " ~ T.stringof ~ " " ~ propertyName ~"() const { 
			Vector3f r;
			r.x = atomicLoad(" ~ propertyName ~ "_x)
			r.y = atomicLoad(" ~ propertyName ~ "_y);
			r.z = atomicLoad(" ~ propertyName ~ "_z); 
			return r; }" ~
			"@property void " ~ propertyName ~ "(" ~ T.stringof ~ " n) { atomicStore(" ~ propertyName ~ "_, n); }";
	}
	else
	{
		const char[] SharedProperty = "private shared " ~ T.stringof ~ " " ~ propertyName ~ "_;" ~
			"@property " ~ T.stringof ~ " " ~ propertyName ~"() const { return atomicLoad(" ~ propertyName ~ "); }" ~
			"@property void " ~ propertyName ~ "(" ~ T.stringof ~ " n) { atomicStore(" ~ propertyName ~ "_, n); }";
	}
}

template SharedPropertyDirty(T, string propertyName) 
{
	const char[] SharedProperty = "private shared " ~ T.stringof ~ " " ~ propertyName ~ "_;" ~
		"@property " ~ T.stringof ~ " " ~ propertyName ~"() const { return atomicLoad(" ~ propertyName ~ "); }" ~
		"@property void " ~ propertyName ~ "(" ~ T.stringof ~ " n) { atomicStore(" ~ propertyName ~ "_, n); atomicStore(" ~ propertyName ~ "Dirty_, true); }" ~ 
		"private @property void" ~ propertyName ~ "Internal(" ~ T.stringof ~ " n) { " ~ propertyName ~ "_, n); }" ~
 		"private shared bool " ~ propertyName ~ "Dirty_;" ~
		"private @property bool " ~ propertyName ~ "Dirty() const { return atomicLoad(" ~ propertyName ~ "Dirty_); }" ~
		"private @property void " ~ propertyName ~ "Dirty(bool n) { atomicStore(" ~ propertyName ~ "Dirty_, n); }";
}

template SharedGetter(T, string propertyName)
{
	const char[] SharedProperty = "private shared " ~ T.stringof ~ " " ~ propertyName ~ "_;" ~
		"@property " ~ T.stringof ~ " " ~ propertyName ~"() const { return atomicLoad(" ~ propertyName ~ "); }" ~
		"private @property void " ~ propertyName ~ "(" ~ T.stringof ~ " n) { atomicStore(" ~ propertyName ~ "_, n); }";
}