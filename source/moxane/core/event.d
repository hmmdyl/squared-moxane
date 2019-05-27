module moxane.core.event;

import containers.dynamicarray;

@safe:

struct Event(Args...) 
{
	alias EventSlot = void delegate(Args);

	private DynamicArray!EventSlot slots;

	void emit(Args a) 
	{
		foreach(slot; slots) slot(a);
	}

	void add(EventSlot slot) @trusted
	{
		slots ~= slot;
	}

	void remove(EventSlot slot) 
	{
		size_t index;
		bool found = false;
		foreach(size_t i, EventSlot slotiter; slots) 
		{
			if(slotiter == slot)
			{
				found = true;
				index = i;
			}
		}
		if(found) slots.remove(index);
		else throw new Exception("Slot not found.");
	}

	void opOpAssign(string op)(EventSlot slot) if(op == "~=") 
	{
		add(slot);
	}

	void opOpAssign(string op)(EventSlot slot) if(op == "-=")
	{
		remove(slot);
	}
}