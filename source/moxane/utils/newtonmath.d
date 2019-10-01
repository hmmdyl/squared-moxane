module moxane.utils.newtonmath;

import dlib.math;
import core.stdc.stdlib : alloca;
import std.algorithm : max;

Vector3f rotateVector(Matrix4f m, Vector3f v)
{
	Vector3f r;
	r.x = v.x * m.forward.x + v.y * m.up.x + v.z * m.right.x;
	r.y = v.x * m.forward.y + v.y * m.up.y + v.z * m.right.y;
	r.z = v.x * m.forward.z + v.y * m.up.z + v.z * m.right.z;
	return r;
}

void dGaussSeidelLcpSor(T)(const int size, const int stride, const T* matrix, T* x, const T* b, const int* normalIndex, const T* low, const T* high, T tol2, int maxIterCount, T sor)
{
	const T* me = matrix;
	T* invDiag1 = cast(T*)alloca(T.sizeof * size);
	T* u = cast(T*)alloca(T.sizeof * (size + 1));
	int* index = cast(int*)alloca(int.sizeof * size);

	u[size] = (1.0f);
	int rowStart = 0;
	for (int j = 0; j < size; j++) {
		u[j] = x[j];
		index[j] = normalIndex[j] ? j + normalIndex[j] : size;
	}

	for (int j = 0; j < size; j++) {
		const T val = u[index[j]];
		const T l = low[j] * val;
		const T h = high[j] * val;
		u[j] = clamp(u[j], l, h);
		invDiag1[j] = (1.0f) / me[rowStart + j];
		rowStart += stride;
	}

	T tolerance = (tol2 * 2.0f);
	const T* invDiag = invDiag1;
	const int maxCount = max(8, size);
	//	for (int i = 0; (i < maxCount) && (tolerance > T(1.0e-8f)); i++) {
	for (int i = 0; (i < maxCount) && (tolerance > tol2); i++) {
		int base = 0;
		tolerance = (0.0f);
		for (int j = 0; j < size; j++) {
			const T* row = &me[base];
			T r = (b[j] - dot(Vector3f(row[0..size]), Vector3f(u[0..size])));
			T f = ((r + row[j] * u[j]) * invDiag[j]);

			const T val = u[index[j]];
			const T l = low[j] * val;
			const T h = high[j] * val;
			if (f > h) {
				u[j] = h;
			} else if (f < l) {
				u[j] = l;
			} else {
				tolerance += r * r;
				u[j] = f;
			}
			base += stride;
		}
	}

	for (int i = 0; (i < maxIterCount) && (tolerance > tol2); i++) {
		int base = 0;
		tolerance = (0.0f);
		for (int j = 0; j < size; j++) {
			const T* row = &me[base];
			T r = (b[j] - dot(Vector3f(row[0..size]), Vector3f(u[0..size])));
			T f = ((r + row[j] * u[j]) * invDiag[j]);
			f = u[j] + (f - u[j]) * sor;

			const T val = u[index[j]];
			const T l = low[j] * val;
			const T h = high[j] * val;
			if (f > h) {
				u[j] = h;
			} else if (f < l) {
				u[j] = l;
			} else {
				tolerance += r * r;
				u[j] = f;
			}
			base += stride;
		}
	}

	for (int j = 0; j < size; j++) {
		x[j] = u[j];
	}
}