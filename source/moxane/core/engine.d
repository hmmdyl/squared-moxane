/// The core of Moxane
module moxane.core.engine;

import std.exception : enforce;
import std.traits;
import std.datetime.stopwatch : StopWatch, AutoStart;

import moxane.io.window;
import moxane.graphics.renderer;
import moxane.core.async;
import moxane.core.log;
import moxane.core.eventwaiter;
import moxane.core.asset;
import moxane.core.entity;
import moxane.core.scene;

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
		enforce(cast(TBase)inst !is null, T.stringof ~ " cannot be casted to " ~ TBase.stringof);
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

	private StopWatch deltaSw, oneSecondSw;
	float deltaTime;
	uint frames;
	private uint frameCount;

	bool exit = false;

	this(const MoxaneBootSettings settings) 
	{
		this.bootSettings = settings;
		services = new ServiceHandler;

		if(settings.logSystem) registerLog;
		else registerNullLog;
		if(settings.assetSystem) registerAsset;
		if(settings.windowSystem) registerWindow;
		if(settings.graphicsSystem) registerRenderer;
		if(settings.asyncSystem) registerAsync;
		if(settings.entitySystem) registerEntityManager;
		if(settings.sceneSystem) registerSceneManager;

		deltaTime = 0f;
		deltaSw = StopWatch(AutoStart.yes);
		oneSecondSw = StopWatch(AutoStart.yes);
	}

	void run()
	{
		while(!exit)
		{
			deltaSw.stop;
			enum oneBillionInv = 1f / 1_000_000_000f;
			deltaTime = deltaSw.peek.total!"nsecs" * oneBillionInv;

			if(oneSecondSw.peek.total!"msecs" >= 1000)
			{
				oneSecondSw.reset;
				frames = frameCount;
				frameCount = 0;
			}

			frameCount++;

			deltaSw.reset;
			deltaSw.start;

			update;
			render;

			Window win = services.get!Window;
			exit |= win !is null ? win.shouldClose : false;
		}
	}

	void update()
	{
		AsyncSystem asyncSystem = services.get!AsyncSystem;
		if(asyncSystem !is null)
		{
			asyncSystem.callAllNextFrame;
			asyncSystem.callAllWaitTime;
		}

		EntityManager entityManager = services.get!EntityManager;
		if(entityManager !is null)
		{
			entityManager.update;
		}
	}

	void render()
	{
		if(!bootSettings.graphicsSystem && !bootSettings.windowSystem) return;

		Window window = services.get!Window;
		Renderer renderer = services.get!Renderer;

		if(renderer !is null) 
			renderer.render;
		if(window !is null)
		{
			window.swapBuffers;
			window.pollEvents;
		}
	}
	
	protected SceneManager registerSceneManager()
	{
		SceneManager sm = new SceneManager(this);
		services.register!SceneManager(sm);
		return sm;
	}

	protected EntityManager registerEntityManager()
	{
		EntityManager em = new EntityManager(this);
		services.register!EntityManager(em);
		return em;
	}

	protected AssetManager registerAsset()
	{
		AssetManager am = new AssetManager(this);
		services.register!AssetManager(am);
		return am;
	}

	protected Log registerLog()
	{
		Log log = new Log;
		services.register!Log(log);
		return log;
	}

	protected Log registerNullLog()
	{
		NullLog log = new NullLog;
		services.registerBoth!(NullLog, Log)(log);
		return cast(Log)log;
	}

	protected Window registerWindow()
	{
		import derelict.glfw3;

		DerelictGLFW3.load;

		ApiBoot api = ApiBoot.createOpenGL43Core;
		WindowBoot winBoot = WindowBoot(1280, 720, "Moxane", false);
		Window win = new Window(this, winBoot, api);
		services.register!Window(win);
		return win;
	}

	protected Renderer registerRenderer()
	{
		import dlib.math;
		Renderer renderer = new Renderer(this, Vector2u(1280, 720), true);
		services.register!Renderer(renderer);
		return renderer;
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
	bool logSystem;
	bool windowSystem;
	bool graphicsSystem;
	bool assetSystem;
	bool physicsSystem;
	bool networkSystem;
	bool settingsSystem;
	bool asyncSystem;
	bool entitySystem;
	bool sceneSystem;

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