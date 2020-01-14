module moxane.utils.math;

@safe:

pragma(inline, true)
size_t flattenIndex2D(size_t x, size_t y, size_t dim)
{
	return x + dim * y;
}