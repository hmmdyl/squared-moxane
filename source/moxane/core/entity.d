/// An implementation of an entity component sytem (ECS) for Moxane.
module moxane.core.entity;

import moxane.core.engine;
import moxane.core.eventwaiter;

import std.typecons;
import std.exception : enforce;
import std.algorithm.iteration;
import std.algorithm.mutation;
import std.algorithm.searching;
import core.memory;
import core.thread : Fiber;
import containers;

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

	/++ Checks if Entity has a component of type T. +/
	bool has(T)() nothrow
	{
		TypeInfo ti = typeid(T);
		void** t = typeid(T) in components; // do not cast here to increase perf
		return t !is null;
	}

	/++ Attempts to get a component for this entity of type T.
	 +	Returns: A pointer to component of type T if found, or null if not. +/
	T* get(T)() nothrow
	{
		TypeInfo ti = typeid(T);
		T** t = cast(T**)(typeid(T) in components);
		if(t is null) return null;
		else return *t;
	}

	private void assertUnattached(T)() { enforce(!has!T(), "Component of type " ~ T.stringof ~ " is already attached."); }

	/++ Allocates a component of type T and adds it to this Entity.
		Returns: A pointer to component of type T 
		Throws: Exception if component of type T is already attached. +/
	T* createComponent(T)()
	{
		assertUnattached!T();
		T* t = entityManager_.allocateComponent!T();
		components[typeid(T)] = cast(void*)t;
		return t;
	}

	/++ Attaches an already allocated component. 
		Throws: Exception if component type T is already attached. +/
	void attachComponent(T)(T* t) 
	{
		assertUnattached!T();
		components[typeid(T)] = cast(void*)t;
	}

	private void attemptDetach(T)() { enforce(components.remove(typeid(T)), "Could not remove component of type " ~ T.stringof ~ "from AA"); }

	/++ Deallocated the attached component of type T. 
		Throws: Exception if component type T could not be detached. +/
	void destroyComponent(T)()
	{
		T** t = cast(T**)(typeid(T) in components);
		if(t is null) return;
		entityManager_.deallocateComponent!T(*t);
		attemptDetach!T();
	}

	/++ Detaches component of type and returns pointer to it.
		Throws: Exception if type is not attached or could not be removed. +/
	T* detachComponent(T)()
	{
		T** t = cast(T**)(typeid(T) in components);
		enforce(t !is null, "Component of type " ~ T.stringof ~ " is not attached to current " ~ Entity.stringof);
		attemptDetach;
		return *t;
	}

	void attachScript(Script script)
	{
		enforce(!canFind(scripts, script), "This script is already present.");
		scripts ~= script;
		script.entity = this;
	}

	void attachScript(AsyncScript script)
	{
		enforce(!canFind(asyncScripts, script), "This script is already present.");
		asyncScripts ~= script;
		script.entity = this;
	}

	void removeScript(Script script)
	{
		enforce(canFind(scripts, script), "Script not present");
		scripts = remove!(a => a == script)(scripts);
		script.entity = null;
	}

	void removeScript(AsyncScript script)
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
	return false;
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
	this(void* ptr, TypeInfo typeInfo) 
	{ 
		this.ptr = ptr; 
		this.typeInfo = typeInfo; 
	}
}

class EntityManager
{
	private Entity[] entities;
	
	EventWaiter!OnEntityAdd onEntityAdd;
	EventWaiter!OnEntityAdd onEntityRemove;

	Moxane moxane;
	this(Moxane moxane)
	{
		this.moxane = moxane;
		add(new ScriptSystem(moxane, this));
	}

	void add(Entity entity)
	{
		enforce(entity !is null, "Entity must not be null.");
		entity.entityManager_ = this;
		entities ~= entity;
		onEntityAdd.emit(OnEntityAdd(entity, this));
	}

	private void entityRemoveEnforce(Entity entity, out size_t index) const
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

		enforce(found, "Could not find entity.");
		enforce(entity.components.length == 0, "Entity must not have any components.");
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
	{
		add(e);
	}

	void opOpAssign(string op)(Entity e) if(op == "-")
	{
		removeAndDealloc(e);
	}

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

	private ubyte[][TypeInfo] componentMemByType;
	private bool[][TypeInfo] cellsFree;

	/++ Allocates a component of type T
		Params:
			T = the type to allocate
			args = arguments to pass to type's constructor
		Returns: A pointer to the location of created component +/
	T* allocateComponent(T, Args...)(Args args)
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

		ubyte[T.sizeof] componentBytes = (*cast(ubyte[T.sizeof]*)&T(args));

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
	void deallocateComponent(TypeInfo type, void* t)
	{
		enforce(cast(ulong)t >= cast(ulong)componentMemByType[type].ptr, "This does not belong in the memory region. Invalid pointer");
		size_t l = componentMemByType[type].length;
		enforce(cast(ulong)t <= cast(ulong)&componentMemByType[type][l-1], "This does not belong in the memory region. Invalid pointer");
		enforce(cast(ulong)t % type.tsize == 0, "Pointer does not align to memory region. Invalid pointer");

		onComponentAllocated.emit(OnComponentAllocation(cast(void*)t, type));

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

	void add(System system)
	{
		systems.insertBack(system);
		onSystemAdded.emit(OnSystemAdded(system, this));
	}

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
	Moxane moxane;

	this(Moxane moxane, EntityManager manager)
	{
		this.moxane = moxane;
		this.entityManager = manager;
	}

	abstract void update();
}

abstract class AsyncScript
{
	package Fiber fiber;
	private bool cancellationFlag;
	private bool running;

	Entity entity;
	Moxane moxane;

	this(Moxane moxane, bool runByDefault = true)
	{
		this.moxane = moxane;
		fiber = new Fiber(&execute);
		if(runByDefault)
			run;
	}

	void run()
	{
		enforce(!running, "Cannot run an already executing " ~ AsyncScript.stringof);
		fiber.call;
		running = true;
	}

	void cancel()
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
	Moxane moxane;

	this(Moxane moxane)
	{
		this.moxane = moxane;
	}

	abstract void execute()
	{}
}

class ScriptSystem : System
{
	this(Moxane moxane, EntityManager em)
	{
		super(moxane, em);
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