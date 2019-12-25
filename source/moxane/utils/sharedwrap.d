module moxane.utils.sharedwrap;

template SharedProperty(T, string propertyName)
{
	const char[] SharedProperty = "private shared " ~ T.stringof ~ " " ~ propertyName ~ "_;" ~
		"@property " ~ T.stringof ~ " " ~ propertyName ~"() const { return atomicLoad(" ~ propertyName ~ "); }" ~
		"@property void " ~ propertyName ~ "(" ~ T.stringof ~ " n) { atomicStore(" ~ propertyName ~ "_, n); }";
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