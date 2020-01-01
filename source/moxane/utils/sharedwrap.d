module moxane.utils.sharedwrap;

import dlib.math.vector;
import std.conv : to;
import core.atomic;

private auto generateField(T, string name)()
{
	static if(is(T : Vector3f))
	{
		return "
			private shared float " ~ name ~ "_0; 
			private shared float " ~ name ~ "_1; 
			private shared float " ~ name ~ "_2; 
			@property " ~ T.stringof ~ " " ~ name ~ "() const {
			import core.atomic : atomicLoad;
			float r0 = atomicLoad(" ~ name ~ "_0); 
			float r1 = atomicLoad(" ~ name ~ "_1); 
			float r2 = atomicLoad(" ~ name ~ "_2); 
			return Vector3f(r0, r1, r2);
			}
			@property void " ~ name ~ "(" ~ T.stringof ~ " newVal) {
			import core.atomic : atomicStore;
			atomicStore(" ~ name ~ "_0, newVal[0]);
			atomicStore(" ~ name ~ "_1, newVal[1]);
			atomicStore(" ~ name ~ "_2, newVal[2]);
			updateField(FieldName." ~ name ~ "); }";
	}
	else 
	{
		return "
			private shared " ~ T.stringof ~ " " ~ name ~ "_; 
			@property " ~ T.stringof ~ " " ~ name ~ "() const {
			import core.atomic : atomicLoad;
			return atomicLoad(" ~ name ~ "_); }
			@property void " ~ name ~ "(" ~ T.stringof ~ " newVal) {
			import core.atomic : atomicStore;
			atomicStore(" ~ name ~ "_, newVal);
			updateField(FieldName." ~ name ~ "); }";
	}
}

string evaluateProperties(Specs ...)()
{
	string ret;

	static assert(Specs.length % 2 == 0);
	static assert(Specs.length <= 128, "only 64 properties maximum");

	ret ~= "private enum FieldName : ulong { \n";

	foreach(size_t i, sym; Specs)
	{
		static if(i % 2 == 0) continue;
		else ret ~= "\t" ~ sym ~ " = 1 << " ~ to!string(i / 2) ~ ",\n";
	}
	ret ~= "}\n";

	ret ~= "private shared ulong updatedFields_;
		@property bool isFieldUpdate(FieldName name) const {
		import core.atomic : atomicLoad;
		ulong f = atomicLoad(updatedFields_);
		return cast(bool)(f >> (cast(int)name));
		}
		private @property void updateField(FieldName name) {
		import core.atomic : atomicLoad, atomicStore;
		ulong f = atomicLoad(updatedFields_);
		f |= (1 << cast(int)name);
		atomicStore(updatedFields_, f);
		}
		private void resetFieldUpdates() { import core.atomic : atomicStore; atomicStore(updatedFields_, 0); }
		";

	static foreach(i, sym; Specs)
	{
		static if(i % 2) {}
		else
		{
			static assert(is(typeof(Specs[i + 1]) : string));
			ret ~= generateField!(Specs[i], Specs[i + 1]);
		}
	}

	return ret;
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

template SharedGetter(T, string propertyName)
{
	static if(is(T == Vector3f))
	{
		const char[] SharedGetter = "
		private shared float " ~ propertyName ~ "_0; 
		private shared float " ~ propertyName ~ "_1; 
		private shared float " ~ propertyName ~ "_2; 
		@property " ~ T.stringof ~ " " ~ propertyName ~ "() const {
			import core.atomic : atomicLoad;
			float r0 = atomicLoad(" ~ propertyName ~ "_0); 
			float r1 = atomicLoad(" ~ propertyName ~ "_1); 
			float r2 = atomicLoad(" ~ propertyName ~ "_2); 
			return Vector3f(r0, r1, r2);
		}
		private @property void " ~ propertyName ~ "(" ~ T.stringof ~ " newVal) {
			import core.atomic : atomicStore;
			atomicStore(" ~ propertyName ~ "_0, newVal[0]);
			atomicStore(" ~ propertyName ~ "_1, newVal[1]);
			atomicStore(" ~ propertyName ~ "_2, newVal[2]);";
	}
	else
	{
		const char[] SharedGetter = "private shared " ~ T.stringof ~ " " ~ propertyName ~ "_;" ~
			"@property " ~ T.stringof ~ " " ~ propertyName ~"() const { return atomicLoad(" ~ propertyName ~ "); }" ~
			"private @property void " ~ propertyName ~ "(" ~ T.stringof ~ " n) { atomicStore(" ~ propertyName ~ "_, n); }";
	}
}