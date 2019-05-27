module moxane.core.scene;

import moxane.core.engine;

@safe:

abstract class Scene
{
	Moxane moxane;
	this(Moxane moxane, Scene parent = null) 
	{
		this.moxane = moxane; 
		this.parent = parent; 
	}

	Scene parent;
	Scene[] children;
	mixin template PropagateChildren(string name)
	{ mixin("foreach(child; children) child." ~ name ~ "();"); }

	abstract void setToCurrent(Scene overwrote);
	abstract void removedCurrent(Scene overwroteBy);

	abstract void onUpdateBegin();
	abstract void onUpdateEnd();
	abstract void onUpdate();

	abstract void onRenderBegin();
	abstract void onRenderEnd();
	abstract void onRender();
}

class SceneManager
{
	private Scene current_;
	@property Scene current(){ return current_; }
	@property void current(Scene curr) 
	{
		if(current_ !is null) current_.removedCurrent(curr);
		curr.setToCurrent(current_);
		current_ = curr;
	}
	
	Moxane moxane;
	this(Moxane moxane) { this.moxane = moxane; }

	void onUpdateBegin() { if(current_ !is null) current_.onUpdateBegin; }
	void onUpdateEnd() { if(current_ !is null) current_.onUpdateEnd; }
	void onUpdate() { if(current_ !is null) current_.onUpdate; }
	
	void onRenderBegin() { if(current_ !is null) current_.onRenderBegin; }
	void onRenderEnd() { if(current_ !is null) current_.onRenderEnd; }
	void onRender() { if(current_ !is null) current_.onRender; }
}