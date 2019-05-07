/// The core of Moxane
module moxane.core.engine;

import std.exception : enforce;
import std.traits;

import moxane.io.window;
import moxane.core.async;
import moxane.core.eventwaiter;

/// Provides a singleton like system for systems, accessible by type.
class ServiceHandler
{
	private Object[TypeInfo] services;

	struct OnRegister
	{
		TypeInfo type;
		TypeInfo base;
		Object object;
		this(TypeInfo type, TypeInfo base, Object object)
		{
			this.type = type;
			this.base = base;
			this.object = object;
		}
	}
	EventWaiterSimple!OnRegister onRegister;

	private void enforceIsInherited(T, TBase)(T inst)
	{
		enforce(cast(TBase)t !is null, T.stringof ~ " cannot be casted to " ~ TBase.stringof);
		/*static if(is(TBase == class))
		{
			if(typeid(T).base == typeid(TBase)) return;
			else if(typeid(T) == typeid(TBase)) return;
			else
			{
				TypeInfo_Class tic = typeid(T);
				while(tic != null)
				{
					tic = tic.base;
					if(tic == typeid(TBase)) return;
				}
				throw new Exception(T.stringof ~ " does not inherit " ~ TBase.stringof);
			}
		}
		static if(is(TBase == interface))
		{
			if(typeid(TBase) in typeid(T).interfaces) return;
		}*/
	}

	/++ Sets an instance of T type to represent that service type.
		Params:
			obj = The instance of the service
			forceOverwrite = If an instance for this type already exists, force an override? 
		Throws: Exception if instance exists and forceOverwrite is false. +/
	void register(T)(T obj, bool forceOverwrite = false)
		if(is(T == class) || is(T == interface))
	{
		T i = get!T();
		if(i !is null && !forceOverwrite) throw new Exception("Service of " ~ T.stringof ~ " already exists and the overwrite flag is not set.");
		services[typeid(T)] = obj;
		onRegister.emit(OnRegister(typeid(T), null, cast(Object)obj));
	}
	
	/++ Takes an instance of type T and represents it as a service of type TBase.
		Params:
			obj = The instance of the service
			forceOverwrite = If an instance for TBase already exists, force an overwrite?
		Throws: Exception if instance exists and forceOverwrite is false or T does not inherit from TBase +/
	void registerAsBase(T, TBase)(T obj, bool forceOverwrite = false)
		if((is(T == class) || is(T == interface)) && (is(TBase == class) || is(TBase == interface)))
	{
		enforceIsInherited!(T, TBase)(obj);
		TBase i = get!TBase();
		if(i !is null && !forceOverwrite) throw new Exception("Service of " ~ TBase.stringof ~ " already exists and the overwrite flag is not set.");
		services[typeid(TBase)] = obj;
		onRegister.emit(OnRegister(typeid(T), null, cast(Object)obj));
	}

	void registerBoth(T, TBase)(T obj, bool forceOverwrite = false)
		if((is(T == class) || is(T == interface)) && (is(TBase == class) || is(TBase == interface)))
	{
		register!T(obj, forceOverwrite);
		registerAsBase!(T, TBase)(obj, forceOverwrite);
	}

	T get(T)() if(is(T == class) || is(T == interface))
	{
		Object* obj = typeid(T) in services;
		if(obj is null) return null;
		else return cast(T)*obj;
	}

	B getAOrB(A, B)() 
		if((is(A == class) || is(A == interface)) && (is(B == class) || is(B == interface)))
	{
		A a = get!A;
		if(a !is null) return cast(B)a;
		B b = get!B;
		return b;
	}
}

class Moxane 
{
	const MoxaneBootSettings bootSettings;
	ServiceHandler services;

	this(const MoxaneBootSettings settings) 
	{
		this.bootSettings = settings;
		services = new ServiceHandler;

		if(settings.windowSystem) registerWindow;
	}

	protected Window registerWindow()
	{
		ApiBoot api = ApiBoot.createOpenGL4Core;
		WindowBoot winBoot = WindowBoot(1280, 720, "Moxane", false);
		Window win = new Window(winBoot, api);
		services.register!Window(win);
		return win;
	}

	protected AsyncSystem registerAsync()
	{
		AsyncSystem async = new AsyncSystem();
		services.register!AsyncSystem(async);
		return async;
	}
}

struct MoxaneBootSettings 
{
	bool windowSystem;
	bool graphicsSystem;
	bool assetSystem;
	bool physicsSystem;
	bool networkSystem;
	bool settingsSystem;
	bool asyncSystem;

	static MoxaneBootSettings defaultBoot() 
	{
		MoxaneBootSettings mbs;
		foreach(fieldName; FieldNameTuple!MoxaneBootSettings)
			__traits(getMember, mbs, fieldName) = true;
		return mbs;
	}

	static MoxaneBootSettings serverBoot() 
	{
		MoxaneBootSettings mbs;
		foreach(fieldName; FieldNameTuple!MoxaneBootSettings) 
		{
			if(fieldName == "windowSystem" || fieldName == "graphicsSystem")
				__traits(getMember, mbs, fieldName) = false;
			else 
				__traits(getMember, mbs, fieldName) = true;
		}
		return mbs;
	}
}