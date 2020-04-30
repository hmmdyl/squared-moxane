/// An implementation of an entity component sytem (ECS) for Moxane.
module moxane.core.entity;

import moxane.core.engine;
import moxane.core.scene;
import moxane.core.eventwaiter;
import moxane.network.semantic;

import std.typecons;
import std.exception : enforce;
import std.algorithm.iteration;
import std.algorithm.mutation;
import std.algorithm.searching;
import core.memory;
import core.thread : Fiber;
import containers;
import std.traits : hasUDA;

@safe:

enum Component;

/++ This is an Entity. Its functionality is represented by the components it encapsulates. +/
class Entity
{
	private void*[TypeInfo] components;

	private EntityManager entityManager_;
	private @property void entityManager(EntityManager e) { entityManager_ = e; }
	/// Get the EntityManager responsible for this Entity.
	@property EntityManager entityManager() { return entityManager_; }

	private Script[] scripts;
	private AsyncScript[] asyncScripts;

	this(EntityManager em)
	{
		entityManager = em;
	}

	invariant { assert(entityManager_ !is null); }

	~this()
	{
		foreach(TypeInfo t, void* p; components)
			entityManager_.deallocateComponent(t, p);
	}

	/++ Checks if Entity has a component of type T. +/
	bool has(T)() nothrow @trusted
	{
		TypeInfo ti = typeid(T);
		void** t = typeid(T) in components; // do not cast here to increase perf
		return t !is null;
	}

	/++ Attempts to get a component for this entity of type T.
	 +	Returns: A pointer to component of type T if found, or null if not. +/
	T* get(T)() nothrow @trusted
	{
		TypeInfo ti = typeid(T);
		T** t = cast(T**)(typeid(T) in components);
		if(t is null) return null;
		else return *t;
	}

	/*bool opBinaryRight(string op)(T* t) if(op == "in")
	{ return get!T == t; }*/
	bool opBinaryRight(string op)(TypeInfo ti) if(op == "in")
	{ return (ti in components) !is null; }

	private void assertUnattached(T)() @trusted { enforce(!has!T(), "Component of type " ~ T.stringof ~ " is already attached."); }

	/++ Allocates a component of type T and adds it to this Entity.
		Returns: A pointer to component of type T 
		Throws: Exception if component of type T is already attached. +/
	T* createComponent(T)() @trusted
	{
		static assert(hasUDA!(T, Component));

		assertUnattached!T();
		T* t = entityManager_.allocateComponent!T();
		components[typeid(T)] = cast(void*)t;
		return t;
	}

	T* createComponent(T, Args...)(Args args) @trusted
	{
		static assert(hasUDA!(T, Component));

		assertUnattached!T();
		T* t = entityManager_.allocateComponent!T(args);
		components[typeid(T)] = cast(void*)t;
		return t;
	}

	/++ Attaches an already allocated component. 
		Throws: Exception if component type T is already attached. +/
	void attachComponent(T)(T* t) @trusted
	{
		static assert(hasUDA!(T, Component));

		assertUnattached!T();
		components[typeid(T)] = cast(void*)t;
		entityManager_.onComponentAttached(OnComponentAttach(*t, this, typeid(T), false));
	}

	private void attemptDetach(T)() @trusted { enforce(components.remove(typeid(T)), "Could not remove component of type " ~ T.stringof ~ "from AA"); }

	/++ Deallocated the attached component of type T. 
		Throws: Exception if component type T could not be detached. +/
	void destroyComponent(T)() @trusted
	{
		T** t = cast(T**)(typeid(T) in components);
		if(t is null) return;
		entityManager_.deallocateComponent!T(*t);
		attemptDetach!T();
	}

	/++ Detaches component of type and returns pointer to it.
		Throws: Exception if type is not attached or could not be removed. +/
	T* detachComponent(T)() @trusted
	{
		T** t = cast(T**)(typeid(T) in components);
		enforce(t !is null, "Component of type " ~ T.stringof ~ " is not attached to current " ~ Entity.stringof);
		entityManager_.onComponentAttached(OnComponentAttach(*t, this, typeid(T), false));
		attemptDetach;
		return *t;
	}

	void attachScript(Script script) @trusted
	{
		enforce(!canFind(scripts, script), "This script is already present.");
		scripts ~= script;
		script.entity = this;
	}

	void attachScript(AsyncScript script) @trusted
	{
		enforce(!canFind(asyncScripts, script), "This script is already present.");
		asyncScripts ~= script;
		script.entity = this;
	}

	void removeScript(Script script) @trusted
	{
		enforce(canFind(scripts, script), "Script not present");
		scripts = remove!(a => a == script)(scripts);
		script.onDetach;
		script.entity = null;
	}

	void removeScript(AsyncScript script) @trusted
	{
		enforce(canFind(scripts, script), "Script not present.");
		asyncScripts = remove!(a => a == script)(asyncScripts);
		script.cancel();
		script.entity = null;
	}
}

/// Determines if entity has all component types specified.
bool hasComponents(Components...)(Entity entity)
{
	foreach(comp; Components)
	{
		auto type = typeid(comp);
		if((type in entity.components) is null)
			return false;
	}
	return true;
}

struct OnEntityAdd 
{ 
	Entity entity; 
	EntityManager manager; 
	this(Entity entity, EntityManager manager) 
	{ 
		this.entity = entity; 
		this.manager = manager; 
	}
}

struct OnComponentAllocation
{
	void* ptr;
	TypeInfo typeInfo;
	bool allocated;
	this(void* ptr, TypeInfo typeInfo, bool allocated) 
	{ 
		this.ptr = ptr; 
		this.typeInfo = typeInfo; 
		this.allocated = allocated;
	}
}

struct OnComponentAttach
{
	void* ptr;
	Entity entity;
	TypeInfo typeInfo;
	bool attach;
	this(void* ptr, Entity entity, TypeInfo typeInfo, bool attach)
	{
		this.ptr = ptr;
		this.entity = entity;
		this.typeInfo = typeInfo;
		this.attach = attach;
	}
}

class EntityManager
{
	private Entity[] entities;
	
	EventWaiter!OnEntityAdd onEntityAdd;
	EventWaiter!OnEntityAdd onEntityRemove;

	ClientID clientID = 0;

	Moxane moxane;
	Scene scene;
	this(Moxane moxane, Scene scene)
	in(moxane !is null)
	{
		this.moxane = moxane;
		this.scene = scene;
		add(new ScriptSystem(this));
	}

	void add(Entity entity)
	{
		enforce(entity !is null, "Entity must not be null.");
		entity.entityManager_ = this;
		entities ~= entity;
		onEntityAdd.emit(OnEntityAdd(entity, this));
	}

	private void entityRemoveEnforce(Entity entity, out size_t index, bool shouldEnforce = true) const @trusted
	{
		bool found = false;
		foreach(size_t i, const Entity e; entities)
		{
			if(e == entity)
			{
				index = i;
				found = true;
			}
		}

		if(!shouldEnforce) return;

		enforce(found, "Could not find entity.");
		enforce(entity.components.length == 0, "Entity must not have any components.");
	}

	void removeSoftAndDealloc(Entity entity)
	{
		size_t index;
		entityRemoveEnforce(entity, index, false);

		foreach(type, comp; entity.components)
			deallocateComponent(type, comp);

		onEntityRemove.emit(OnEntityAdd(entity, this));
		entity.entityManager_ = null;

		entities = std.algorithm.mutation.remove(entities, index);
	}

	void removeAndDealloc(Entity entity)
	{
		size_t index;
		entityRemoveEnforce(entity, index);

		foreach(type, comp; entity.components)
			deallocateComponent(type, comp);

		onEntityRemove.emit(OnEntityAdd(entity, this));
		entity.entityManager_ = null;

		entities = std.algorithm.mutation.remove(entities, index);
	}

	void remove(Entity entity)
	{
		size_t index;
		entityRemoveEnforce(entity, index);

		onEntityRemove.emit(OnEntityAdd(entity, this));
		entity.entityManager_ = null;

		entities = std.algorithm.mutation.remove(entities, index);
	}

	void opOpAssign(string op)(Entity e) if(op == "~")
	{ add(e); }
	void opOpAssign(string op)(Entity e) if(op == "-")
	{ removeAndDealloc(e); }
	bool opBinaryRight(string op)(Entity e) if(op == "in")
	{ return canFind!(a => a is e)(entities); }

	/++ Gets a range over entites that contain all specified components +/
	auto entitiesWith(C...)()
	{
		return filter!(hasComponents!C)(entities);
	}

	Entity[] allEntities() { return entities; }

	/************************
	 * COMPONENT ALLOCATION *
	 ************************/
	
	EventWaiter!OnComponentAllocation onComponentAllocated;
	EventWaiter!OnComponentAttach onComponentAttached;
	EventWaiter!OnComponentAttach onComponentDetached;

	private ubyte[][TypeInfo] componentMemByType;
	private bool[][TypeInfo] cellsFree;

	/++ Allocates a component of type T
		Params:
			T = the type to allocate
			args = arguments to pass to type's constructor
		Returns: A pointer to the location of created component +/
	T* allocateComponent(T, Args...)(Args args) @trusted
	{
		static assert(is(T == struct));

		T* result;
		scope(exit) onComponentAllocated.emit(OnComponentAllocation(result, typeid(T), true));

		GC.disable();
		scope(exit) GC.enable();

		ubyte[]* memArr = typeid(T) in componentMemByType;
		if(memArr is null)
		{
			componentMemByType[typeid(T)] = new ubyte[](0);
			cellsFree[typeid(T)] = new bool[](0);
			memArr = typeid(T) in componentMemByType;
		}

		T temp = T(args);
		ubyte[T.sizeof] componentBytes = (*cast(ubyte[T.sizeof]*)&temp);

		size_t cellFreeIndex = -1;
		foreach(size_t i, bool free; cellsFree[typeid(T)])
			if(free) cellFreeIndex = i;
		
		if(cellFreeIndex > -1)
		{
			size_t memStart = cellFreeIndex * T.sizeof;
			size_t memEnd = (cellFreeIndex + 1) * T.sizeof;
			(*memArr)[memStart .. memEnd] = componentBytes[0 .. T.sizeof];
			cellsFree[typeid(T)][cellFreeIndex] = false;
			result = cast(T*)(memArr.ptr + memStart);
			GC.addRange(result, T.sizeof, typeid(T));
			return result;
		}
		else
		{
			size_t memStart = cellsFree[typeid(T)].length;
			*memArr ~= componentBytes[0 .. T.sizeof];
			cellsFree[typeid(T)] ~= false;
			result = cast(T*)(memArr.ptr + (memStart * T.sizeof));
			GC.addRange(result, T.sizeof, typeid(T));
			return result;
		}
	}

	/++ Deallocate component at pointer of type T +/
	void deallocateComponent(T)(T* t) { deallocateComponent(typeid(T), cast(void*)t); }

	/// ditto
	void deallocateComponent(TypeInfo type, void* t) @trusted
	{
		enforce(cast(ulong)t >= cast(ulong)componentMemByType[type].ptr, "This does not belong in the memory region. Invalid pointer");
		size_t l = componentMemByType[type].length;
		enforce(cast(ulong)t <= cast(ulong)&componentMemByType[type][l-1], "This does not belong in the memory region. Invalid pointer");
		enforce(cast(ulong)t % type.tsize == 0, "Pointer does not align to memory region. Invalid pointer");

		onComponentAllocated.emit(OnComponentAllocation(cast(void*)t, type, false));

		ulong indexStart = cast(ulong)t - cast(ulong)componentMemByType[type].ptr;
		foreach(b; 0 .. type.tsize)
		{
			ulong index = indexStart + b;
			componentMemByType[type][index] = ubyte.init;
		}
		GC.removeRange(cast(void*)(componentMemByType[type].ptr + indexStart));
		ulong freeIndex = indexStart / type.tsize;
		cellsFree[type][freeIndex] = true;
	}

	private UnrolledList!System systems;
	struct OnSystemAdded 
	{
		System system;
		EntityManager manager;
		this(System system, EntityManager manager) { this.system = system; this.manager = manager; }
	}
	EventWaiter!OnSystemAdded onSystemAdded;

	void add(System system) @trusted
	{
		systems.insertBack(system);
		onSystemAdded.emit(OnSystemAdded(system, this));
	}

	void hasSystem(T)()
	{
		return canFind!((target, needle) => target == typeid(needle))(systems, typeid(T));
	}

	void opOpAssign(string op)(System system) if(op == "~")
	{ add(system); }

	void update()
	{
		foreach(System system; systems)
		{
			system.update();
		}
	}
}

abstract class System
{
	EntityManager entityManager;

	this(EntityManager manager) in(manager !is null)
	{
		this.entityManager = manager;
	}
	
	abstract void update();
}

abstract class AsyncScript
{
	package Fiber fiber;
	protected bool cancellationFlag;
	private bool running;
	private bool runOnAttach;

	private Entity entity_;
	@property Entity entity() { return entity_; }
	@property void entity(Entity e) { entity_ = e; if(!running && runOnAttach) run; }

	EntityManager entityManager;

	this(EntityManager entityManager, bool runOnAttach = true, bool runByDefault = false) @trusted
		in(entityManager !is null)
	{
		this.entityManager = entityManager;
		fiber = new Fiber(&execute);
		if(runByDefault)
			run;
	}

	void run() @trusted
	{
		enforce(!running, "Cannot run an already executing " ~ AsyncScript.stringof);
		fiber.call;
		running = true;
	}

	void cancel() @trusted
	{
		if(!running || cancellationFlag) return;

		assert(fiber.state == Fiber.State.HOLD);
		cancellationFlag = true;
		fiber.call;
		deinit;
	}

	enum string checkCancel = "if(cancellationFlag == true) return;";

	protected abstract void deinit()
	{}

	protected abstract void execute()
	{}
}

abstract class Script
{
	Entity entity;
	final @property EntityManager entityManager() { return entity is null ? null : entity.entityManager_; }

	this(Entity entity)
	{
		this.entity = entity;
	}

	void onDetach() {}

	abstract void execute()
	{}
}

class ScriptSystem : System
{
	this(EntityManager em)
	{
		super(em);
	}

	override void update()
	{
		Entity[] entities = entityManager.allEntities;
		foreach(Entity entity; entities)
		{
			foreach_reverse(Script script; entity.scripts)
				script.execute();
			foreach_reverse(AsyncScript script; entity.asyncScripts)
			{
				if(!script.running && !script.cancellationFlag)
					script.run();
			}
		}
	}
}