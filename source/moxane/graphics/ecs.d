module moxane.graphics.ecs;

import moxane.core;
import moxane.graphics.standard;

import std.algorithm.searching : canFind, find;
import std.algorithm.mutation : remove;

@safe:
// TODO: Actually make this module and dependencies @safe

@Component
struct RenderComponent
{
	private StaticModel[] staticModels_;
	@property StaticModel[] staticModels() { return staticModels_; }
}

class EntityRenderSystem : System
{
	StandardRenderer renderer;

	this(Moxane moxane)
	{
		super(moxane, moxane.services.get!EntityManager());
		renderer = moxane.services.get!StandardRenderer;
		entityManager.add(this);
	}

	override void update() @trusted
	{
		foreach(Entity entity; entityManager.entitiesWith!(RenderComponent, Transform))
		{
			RenderComponent* renderComponent = entity.get!RenderComponent;
			Transform* transform = entity.get!Transform;

			foreach(ref StaticModel model; renderComponent.staticModels)
			{
				model.finalTransform.position = transform.position + model.localTransform.position;
				model.finalTransform.rotation = transform.rotation + model.localTransform.rotation;
				model.finalTransform.scale = transform.scale * model.localTransform.scale;
			}
		}
	}

	void addModel(StaticModel model, ref RenderComponent component) @trusted
	{
		component.staticModels_ ~= model;
		renderer.addStaticModel(model);
	}

	void removeModel(StaticModel model, ref RenderComponent component) @trusted
	in { 
		assert(canFind(component.staticModels_, model));
		assert(renderer.hasModel(model));
	}
	do {
		renderer.removeModel(model);
		component.staticModels_ = component.staticModels_.remove!(a => a == model);
	}
}