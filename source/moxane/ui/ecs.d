module moxane.ui.ecs;

import moxane.graphics.renderer;
import moxane.graphics.texture;
import moxane.graphics.transformation;
import moxane.graphics.sprite;
import moxane.io;
import moxane.core;
import moxane.core.asset;

import dlib.math : Vector2i, Vector4f;

struct UIPicture
{
	Texture2D texture;
	Vector2i offset;
	Vector2i dimensions;

	this(Texture2D texture, Vector2i offset, Vector2i dimensions)
	{
		this.texture = texture;
		this.offset = offset;
		this.dimensions = dimensions;
	}
}

enum UIButtonState
{
	nothing,
	hover,
	click,
	rightClick
}

struct UIButtonEvent
{
	UIButtonState previousState;
	UIButtonState state;
	Vector2i cursorPosition;
}

struct UIButton
{
	EventWaiter!(UIButtonEvent) event;

	UIButtonState state, previous;
	Vector2i offset;
	Vector2i dimensions;
	Vector4f inactiveColour;
	Vector4f hoverColour;
	Vector4f clickColour;

	this(Vector2i offset, Vector2i dimensions, Vector4f inactiveColour, Vector4f hoverColour, Vector4f clickColour)
	{
		state = UIButtonState.nothing;
		previous = state;
		this.offset = offset;
		this.dimensions = dimensions;
		this.inactiveColour = inactiveColour;
		this.hoverColour = hoverColour;
		this.clickColour = clickColour;
	}
}

final class UISystem : System
{
	this(Moxane moxane, EntityManager em)
	{
		super(moxane, em);
	}

	override void update()
	{
		updateButtons;
	}

	private void updateButtons() @trusted
	{
		SpriteRenderer sprites = moxane.services.get!SpriteRenderer;
		if(sprites is null) return;

		auto entities = entityManager.entitiesWith!(Transform, UIButton);
		Window window = moxane.services.get!Window;

		Vector2i cursorPos = cast(Vector2i)window.cursorPos;
		bool leftMB = window.isMouseButtonDown(MouseButton.left);
		bool rightMB = window.isMouseButtonDown(MouseButton.right);

		foreach(Entity entity; entities)
		{
			Transform* transform = entity.get!Transform;
			UIButton* button = entity.get!UIButton;
			Vector2i buttonBegin = cast(Vector2i)transform.position.xy + button.offset;
			Vector2i buttonEnd = buttonBegin + button.dimensions;

			button.previous = button.state;

			if(cursorPos.x >= buttonBegin.x && cursorPos.y >= buttonBegin.y && cursorPos.x <= buttonEnd.x && cursorPos.y <= buttonEnd.y)
			{
				if(leftMB)
					button.state = UIButtonState.click;
				else if(rightMB)
					button.state = UIButtonState.rightClick;
				else
					button.state = UIButtonState.hover;
			}
			else
				button.state = UIButtonState.nothing;

			if(button.previous != button.state)
			{
				UIButtonEvent event = {
					previousState : button.previous,
					state : button.state,
					cursorPosition : cursorPos
				};
				button.event.emit(event);
			}

			Vector4f colour = button.state == UIButtonState.click ? button.clickColour : button.state == UIButtonState.hover ? button.hoverColour : button.inactiveColour;
			sprites.drawSprite(buttonBegin, button.dimensions, colour.xyz, colour.w);
		}
	}
}