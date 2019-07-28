module moxane.io.input;

import moxane.core;
import moxane.io.kbm;
import moxane.io.window;
import moxane.utils.maybe;

import dlib.math.vector;
import containers.hashset;
import std.algorithm.searching : canFind;

@safe:

struct InputEvent
{
	string bindingName;
	int key;
	ButtonAction action;
}

struct InputEventText
{
	char c;
}

class InputManager
{
	/// name of binding -> EventWaiter
	EventWaiter!(InputEvent)[string] boundKeys;
	ButtonAction[string] boundKeyState;

	/// key name -> name[s] of binding
	HashSet!(string)[int] bindings;

	private Vector2d mouseMove_;
	@property Vector2d mouseMove() const { return mouseMove_; }
	private Vector2d mouseMoveRawPrevious;
	private Vector2d mouseMoveRaw_;
	@property Vector2d mouseMoveRaw() const { return mouseMoveRaw_; }
	bool invertY;

	@property bool hideCursor() { return window.hideCursor; }
	@property void hideCursor(bool n) { window.hideCursor = n; }
	@property Vector2d cursorPosition() { return window.cursorPos; }

	EventWaiter!InputEventText onText;

	private Window window;

	this(Window window)
	{
		this.window = window;
		window.onMouseButton.add(&onMouseButtonWin);
		window.onKey.add(&onKeyWin);
		window.onChar.add(&onTextWin);
		window.onMouseMove.add(&onMouseMoveWin);

		mouseMove_ = Vector2d(0, 0);
		mouseMoveRaw_ = Vector2d(0, 0);
		mouseMoveRawPrevious = window.cursorPos;
	}

	~this()
	{
		window.onMouseButton.remove(&onMouseButtonWin);
		window.onKey.remove(&onKeyWin);
		window.onChar.remove(&onTextWin);
		window.onMouseMove.remove(&onMouseMoveWin);
	}

	void update()
	{
		if(window.hideCursor)
		{
			Vector2d cursor = window.cursorPos;
			Vector2d c = cursor - mouseMoveRawPrevious;
			mouseMoveRawPrevious = cursor;

			mouseMoveRaw_ = c;
			mouseMove_.x = c.x;
			mouseMove_.y = invertY ? -c.y : c.y;
		}
		else
		{
			mouseMove_ = Vector2d(0, 0);
			mouseMoveRaw_ = Vector2d(0, 0);
		}
	}

	ButtonAction getBindingState(string bindingName)
	{
		ButtonAction* action = bindingName in boundKeyState;
		if(action is null) return ButtonAction.release;
		else return *action;
	}

	void setBinding(string name, int n) @trusted
	{
		foreach(int boundInputs, ref HashSet!string bindingNames; bindings)
		{
			if(bindingNames[].canFind!"a==b"(name))
			{
				bindingNames.remove(name);
				boundKeyState[name] = ButtonAction.release;
			}
		}
		
		HashSet!(string)* b = n in bindings;
		if(b !is null)
			b.insert(name);
		else 
		{
			bindings[n] = HashSet!string();
			bindings[n] ~= name;
			boundKeys[name] = EventWaiter!InputEvent();
			boundKeyState[name] = ButtonAction.release;
		}
	}

	void setBinding(string name, Keys key)
	{ setBinding(name, cast(int)key); }
	void setBinding(string name, MouseButton mb)
	{ setBinding(name, cast(int)mb); }

	Maybe!int getBindingValue(string bindingName) @trusted
	{
		foreach(int boundInputs, ref HashSet!string bindingNames; bindings)
			if(bindingNames.contains(bindingName))
				return Maybe!int(boundInputs);

		return Maybe!int();
	}

	private void handleCallback(int key, ButtonAction a) @trusted
	{
		HashSet!(string)* bindingNames = key in bindings;
		if(bindingNames !is null)
		{
			foreach(b; *bindingNames)
			{
				EventWaiter!(InputEvent)* waiter = b in boundKeys;
				if(waiter !is null)
				{
					InputEvent ie;
					ie.bindingName = b;
					ie.key = key;
					ie.action = a;
					waiter.emit(ie);
				}
				ButtonAction* state = b in boundKeyState;
				if(state !is null)
					*state = a;
			}
		}
	}

	private void onMouseMoveWin(Window win, Vector2d movement)
	{
		
	}

	private void onMouseButtonWin(Window win, MouseButton mb, ButtonAction a)
	{ handleCallback(cast(int)mb, a); }

	private void onKeyWin(Window win, Keys key, ButtonAction a)
	{ handleCallback(cast(int)key, a); }

	private void onTextWin(Window win, char c)
	{ onText.emit(InputEventText(c)); }
}