module moxane.core.transformation;

import moxane.core.entity : Component;
import dlib.math;
import core.atomic;

@safe @nogc nothrow:

@Component
struct Transform
{
	Vector3f position;
	Vector3f rotation;
	Vector3f scale;

	this(AtomicTransform at)
	{
		this.position = at.position;
		this.rotation = at.rotation;
		this.scale = at.scale;
	}

	this(Vector3f position, Vector3f rotation = Vector3f(0, 0 ,0), Vector3f scale = Vector3f(1, 1, 1))
	{
		this.position = position;
		this.rotation = rotation;
		this.scale = scale;
	}

	static Transform init()
	{
		Transform t;
		t.position = Vector3f(0f, 0f, 0f);
		t.rotation = Vector3f(0f, 0f, 0f);
		t.scale = Vector3f(1f, 1f, 1f);
		return t;
	}

	@property Matrix4f matrix() @trusted const
	{
		return makeMatrix(position, rotation, scale);
	}
}

@Component
struct AtomicTransform
{
	private shared float px_, py_, pz_;
	private shared float rx_, ry_, rz_;
	private shared float sx_, sy_, sz_;
	private shared bool set_;

	this(Transform t)
	{
		this.position = t.position;
		this.rotation = t.rotation;
		this.scale = t.scale;
	}

	/+static AtomicTransform init()
	{
		return AtomicTransform(Vector3f(0f, 0f, 0f), Vector3f(0f, 0f, 0f), Vector3f(1f, 1f, 1f));
	}+/

	this(Vector3f position, Vector3f rotation = Vector3f(0, 0, 0), Vector3f scale = Vector3f(1, 1, 1))
	{
		this.position = position;
		this.rotation = rotation;
		this.scale = scale;
	}

	@property Vector3f position() const
	{
		Vector3f p;
		p.x = atomicLoad(px_);
		p.y = atomicLoad(py_);
		p.z = atomicLoad(pz_);
		return p;
	}
	@property void position(Vector3f p)
	{
		atomicStore(px_, p.x);
		atomicStore(py_, p.y);
		atomicStore(pz_, p.z);
		atomicStore(set_, true);
	}

	@property Vector3f rotation() const
	{
		Vector3f r;
		r.x = atomicLoad(rx_);
		r.y = atomicLoad(ry_);
		r.z = atomicLoad(rz_);
		return r;
	}
	@property void rotation(Vector3f r)
	{
		atomicStore(rx_, r.x);
		atomicStore(ry_, r.y);
		atomicStore(rz_, r.z);
		atomicStore(set_, true);
	}

	@property Vector3f scale() const
	{
		Vector3f s;
		s.x = atomicLoad(sx_);
		s.y = atomicLoad(sy_);
		s.z = atomicLoad(sz_);
		return s;
	}
	@property void scale(Vector3f s)
	{
		atomicStore(sx_, s.x);
		atomicStore(sy_, s.y);
		atomicStore(sz_, s.z);
		atomicStore(set_, true);
	}

	static AtomicTransform init()
	{
		AtomicTransform t;
		t.position = Vector3f(0f, 0f, 0f);
		t.rotation = Vector3f(0f, 0f, 0f);
		t.scale = Vector3f(1f, 1f, 1f);
		return t;
	}

	@property Matrix4f matrix() @trusted const
	{
		return makeMatrix(position, rotation, scale);
	}

	@property bool set() const { return atomicLoad(set_); }
	@property void set(bool n) { atomicStore(set_, n); }
}

Matrix4f makeMatrix(Vector3f position, Vector3f rotation, Vector3f scale) @trusted
{
	Matrix4f m = translationMatrix(position);
	m *= rotationMatrix(Axis.x, degtorad(rotation.x));
	m *= rotationMatrix(Axis.y, degtorad(rotation.y));
	m *= rotationMatrix(Axis.z, degtorad(rotation.z));
	m *= scaleMatrix(scale);
	return m;
}