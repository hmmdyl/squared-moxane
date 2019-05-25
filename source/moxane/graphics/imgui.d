module moxane.graphics.imgui;

import moxane.core.engine;
import moxane.core.asset;
import moxane.graphics.gl;
import moxane.graphics.renderer;
import moxane.graphics.effect;
import moxane.io;

import containers.unrolledlist;
import derelict.opengl3.gl3;
//import derelict.imgui.imgui;
import dlib.math;
import cimgui.funcs;
import cimgui.types;
import cimgui.imgui;

import std.typecons;

interface IImguiRenderable
{
	void renderUI(ImguiRenderer, Renderer, ref LocalContext lc);
}

class ImguiRenderer : IRenderable
{
	private Effect effect;
	private GLuint vbo, ibo, vao;
	private GLuint fontTexture;

	IImguiRenderable[] renderables;

	private Window win_;
	@property Window win() { return win_; }
	@property void win(Window n) {
		win_ = n;
		//win_.onMouseButton.add(&onMouseButton);
	}

	private float mouseWheel;

	Moxane moxane;

	private ImGuiContext* imguiContext;

	this(Moxane moxane)
	{
		this.moxane = moxane;

		win = moxane.services.get!Window;

		AssetManager am = moxane.services.get!AssetManager;
		Shader vert = am.uniqueLoad!Shader("content/shaders/imgui.vs.glsl");
		Shader frag = am.uniqueLoad!Shader("content/shaders/imgui.fs.glsl");
		effect = new Effect(moxane, ImguiRenderer.stringof ~ "Effect");
		effect.attachAndLink(vert, frag);
		effect.bind;
		effect.findUniform("Projection");
		effect.findUniform("Texture");
		effect.unbind;

		imguiContext = igCreateContext(null);
		igSetCurrentContext(imguiContext);
		auto io = igGetIO();
		igStyleColorsClassic();
		io.KeyMap[ImGuiKey_Tab] = Keys.tab;
		io.KeyMap[ImGuiKey_LeftArrow] = Keys.left;
		io.KeyMap[ImGuiKey_RightArrow] = Keys.right;
		io.KeyMap[ImGuiKey_UpArrow] = Keys.up;
		io.KeyMap[ImGuiKey_DownArrow] = Keys.down;
		io.KeyMap[ImGuiKey_PageUp] = Keys.pageUp;
		io.KeyMap[ImGuiKey_PageDown] = Keys.pageDown;
		io.KeyMap[ImGuiKey_Home] = Keys.home;
		io.KeyMap[ImGuiKey_End] = Keys.pageUp;
		io.KeyMap[ImGuiKey_PageUp] = Keys.pageUp;
		io.KeyMap[ImGuiKey_Home] = Keys.home;
		io.KeyMap[ImGuiKey_End] = Keys.end;             
		io.KeyMap[ImGuiKey_Insert] = Keys.insert;
		io.KeyMap[ImGuiKey_Delete] = Keys.delete_;
		io.KeyMap[ImGuiKey_Backspace] = Keys.backspace;
		io.KeyMap[ImGuiKey_Space] = Keys.space;
		io.KeyMap[ImGuiKey_Enter] = Keys.enter;
		io.KeyMap[ImGuiKey_Escape] = Keys.escape;
		io.KeyMap[ImGuiKey_A] = Keys.a;
		io.KeyMap[ImGuiKey_C] = Keys.c;
		io.KeyMap[ImGuiKey_V] = Keys.v;
		io.KeyMap[ImGuiKey_X] = Keys.x;
		io.KeyMap[ImGuiKey_Y] = Keys.y;
		io.KeyMap[ImGuiKey_Z] = Keys.z;

		Vector2i size = win.size;
		Vector2i framebufferSize = win.framebufferSize;
		io.DisplaySize = ImVec2(cast(float)size.x, cast(float)size.y);
		io.DisplayFramebufferScale = ImVec2(size.x > 0 ? (cast(float)framebufferSize.x / size.x) : 0, size.y > 0 ? (cast(float)framebufferSize.y / size.y) : 0);

		win.onKey.add(&onKey);
		win.onChar.add(&onChar);

		glGenVertexArrays(1, &vao);
		glGenBuffers(1, &vbo);
		glGenBuffers(1, &ibo);
		
		ubyte* pixels;
		int w, h;
		//ImFontAtlas_GetTexDataAsRGBA32(io.Fonts, &pixels, &w, &h, null);
		ImFontAtlas_GetTexDataAsAlpha8(io.Fonts, &pixels, &w, &h, null);
		glGenTextures(1, &fontTexture);
		glBindTexture(GL_TEXTURE_2D, fontTexture);
		scope(exit) glBindTexture(GL_TEXTURE_2D, 0);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, w, h, 0, GL_RED, GL_UNSIGNED_BYTE, pixels);
		//ImFontAtlas_SetTexID(io.Fonts, cast(void*)fontTexture);
	}

	~this()
	{
		glDeleteVertexArrays(1, &vao);
		glDeleteBuffers(1, &vbo);
		glDeleteBuffers(1, &ibo);
		glDeleteTextures(1, &fontTexture);
		destroy(effect);
	}

	void render(Renderer renderer, ref LocalContext lc, out uint drawCalls, out uint numVerts)
	{
		import std.stdio;

		auto io = igGetIO();

		{
			//writeln("begin io");
			//scope(exit) writeln("end IO update");
			io.DeltaTime = 1f / 60f;

			Vector2i size = win.size;
			Vector2i framebufferSize = win.framebufferSize;
			io.DisplaySize = ImVec2(cast(float)size.x, cast(float)size.y);
			io.DisplayFramebufferScale = ImVec2(cast(float)framebufferSize.x / cast(float)size.x, cast(float)framebufferSize.y / cast(float)size.y);
			//io.DisplayFramebufferScale.x = io.DisplayFramebufferScale.y = 2f;

			if(win.isFocused)
			{
				Vector2d cursor = win.cursorPos;
				io.MousePos = ImVec2(cast(float)cursor.x, cast(float)cursor.y);

				foreach(i; 0 .. 3)
					io.MouseDown[i] = win.isMouseButtonDown(i);
			}
			//writeln("end io");
		}

		//writeln("Begin update");
		igNewFrame();
		foreach(IImguiRenderable r; renderables)
			r.renderUI(this, renderer, lc);
		igRender();
		//writeln("End update");

		/*with(renderer.gl)
		{
			blend.push(true);
			/*blendEquation.push(GL_FUNC_ADD);
			blendFunc.push(Tuple!(GLenum, GLenum)(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA));*
			//polyMode.push(GL_FILL);
			depthTest.push(false);
			scissorTest.push(true);

			scope(exit)
			{
				blend.pop;
				blendEquation.pop;
				blendFunc.pop;
				//polyMode.pop;
				scissorTest.pop;
				depthTest.pop;
			}
		}*/

		glEnable(GL_BLEND);
		glBlendEquation(GL_FUNC_ADD);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		scope(exit) glDisable(GL_BLEND);

		glDisable(GL_CULL_FACE);
		glDisable(GL_DEPTH_TEST);

		//glEnable(GL_SCISSOR_TEST);
		//scope(exit) glDisable(GL_SCISSOR_TEST);

		effect.bind;
		scope(exit) effect.unbind;
		effect["Projection"].set(&lc.projection);

		glBindVertexArray(vao);
		scope(exit) glBindVertexArray(0);

		foreach(n; 0 .. 3)
			glEnableVertexAttribArray(n);
		scope(exit)
			foreach(n; 0 .. 3)
				glDisableVertexAttribArray(n);

		ImDrawData* drawData = igGetDrawData();

		Vector2i framebufferSize = Vector2i(cast(int)(io.DisplaySize.x * io.DisplayFramebufferScale.x), cast(int)(io.DisplaySize.y * io.DisplayFramebufferScale.y));
		//drawData.ScaleClipRects(io.DisplayFramebufferScale);
		//ImDrawData_ScaleClipRects(drawData, io.DisplayFramebufferScale);

		glActiveTexture(GL_TEXTURE0);
		effect["Texture"].set(0);

		for(int i = 0; i < drawData.CmdListsCount; i++)
		{
			ImDrawList* cmdList = drawData.CmdLists[i];
			ImDrawIdx* indexOffset;

			//auto vertexCount = ImDrawList_GetVertexBufferSize(cmdList);
			//auto indexCount = ImDrawList_GetIndexBufferSize(cmdList);

			auto vertexCount = cmdList.VtxBuffer.size;
			auto indexCount = cmdList.IdxBuffer.size;
			numVerts += vertexCount;

			glBindBuffer(GL_ARRAY_BUFFER, vbo);
			//glBufferData(GL_ARRAY_BUFFER, vertexCount * ImDrawVert.sizeof, cast(GLvoid*)ImDrawList_GetVertexPtr(cmdList, 0), GL_STREAM_DRAW);
			glBufferData(GL_ARRAY_BUFFER, vertexCount * ImDrawVert.sizeof, cast(GLvoid*)cmdList.VtxBuffer.data, GL_STREAM_DRAW);
			glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo);
			//glBufferData(GL_ELEMENT_ARRAY_BUFFER, indexCount * ImDrawIdx.sizeof, cast(GLvoid*)ImDrawList_GetIndexPtr(cmdList, 0), GL_STREAM_DRAW);
			glBufferData(GL_ELEMENT_ARRAY_BUFFER, indexCount * ImDrawIdx.sizeof, cast(GLvoid*)cmdList.IdxBuffer.data, GL_STREAM_DRAW);

			//auto cmdCount = ImDrawList_GetCmdSize(cmdList);
			auto cmdCount = cmdList.CmdBuffer.size;

			foreach(j; 0 .. cmdCount)
			{
				//ImDrawCmd* cmd = ImDrawList_GetCmdPtr(cmdList, j);
				ImDrawCmd* cmd = &cmdList.CmdBuffer.data[j];

				/*glScissor(
						  cast(int)cmd.ClipRect.x,
						  cast(int)(framebufferSize.x - cmd.ClipRect.w),
						  cast(int)(cmd.ClipRect.z - cmd.ClipRect.x),
						  cast(int)(cmd.ClipRect.w - cmd.ClipRect.y));*/

				glBindBuffer(GL_ARRAY_BUFFER, vbo);
				glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, ImDrawVert.sizeof, cast(void*)ImDrawVert.pos.offsetof);
				glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, ImDrawVert.sizeof, cast(void*)ImDrawVert.uv.offsetof);
				glVertexAttribPointer(2, 4, GL_UNSIGNED_BYTE, GL_TRUE, ImDrawVert.sizeof, cast(void*)ImDrawVert.col.offsetof);
				glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo);

				glBindTexture(GL_TEXTURE_2D, fontTexture);
				glDrawElements(GL_TRIANGLES, cast(GLsizei)cmd.ElemCount, ImDrawIdx.sizeof == 2 ? GL_UNSIGNED_SHORT : GL_UNSIGNED_INT, cast(void*)indexOffset);
				drawCalls += 1;

				indexOffset += cmd.ElemCount;
			}
		}
	}

	private void onKey(Window win, Keys key, ButtonAction a)
	{
		ImGuiIO* io = igGetIO();
		if(a == ButtonAction.press)
			io.KeysDown[key] = true;
		if(a == ButtonAction.release)
			io.KeysDown[key] = false;

		io.KeyCtrl = io.KeysDown[Keys.leftControl] || io.KeysDown[Keys.rightControl];
		io.KeyShift = io.KeysDown[Keys.leftShift] || io.KeysDown[Keys.rightShift];
		io.KeyAlt = io.KeysDown[Keys.leftAlt] || io.KeysDown[Keys.rightAlt];
		io.KeySuper = io.KeysDown[Keys.leftSuper] || io.KeysDown[Keys.rightSuper];
	}

	private void onChar(Window win, char c)
	{
		ImGuiIO* io = igGetIO();
		ImGuiIO_AddInputCharacter(io, cast(ushort)c);
	}

	/*private void onMouseButton(Window win, MouseButton button, ButtonAction action)
	{
		if(cast(int)button >= 0 && cast(int)button < 3)
		{
			if(action == ButtonAction.press)
				mouseButtons[button] = true;
			else if(action == ButtonAction.release)
				mouseButtons[button] = false;
		}
	}

	private void onScroll(Window)*/
}

shared static this()
{
	import derelict.util.exception : ShouldThrow;
	ShouldThrow missing(string symbol)
	{
		import std.stdio;
		writeln(symbol);
		return ShouldThrow.No;
		switch(symbol)
		{
			case "igShowDemoWindow": return ShouldThrow.No;
			case "igShowStyleSelector": return ShouldThrow.No;
			case "igShowFontSelector": return ShouldThrow.No;
			case "igSetNextWindowSizeConstraints": return ShouldThrow.No;
			case "igPushStyleColorU32": return ShouldThrow.No;
			case "igGetStyleColorVec4": return ShouldThrow.No;
			case "igGetFont": return ShouldThrow.No;
			case "igGetFontSize": return ShouldThrow.No;
			case "igGetFontTexUvWhitePixel": return ShouldThrow.No;
			case "igGetColorU32": return ShouldThrow.No;
			case "igGetColorU32Vec": return ShouldThrow.No;
			case "igGetColorU32U32": return ShouldThrow.No;
			case "igNewLine": return ShouldThrow.No;
			case "igAlignTextToFramePadding": return ShouldThrow.No;
			default: return ShouldThrow.Yes;
		}
	}
	//DerelictCImgui.missingSymbolCallback = &missing;
	DerelictCImgui.load;
	import std.stdio;
	import std.string;
	writeln(fromStringz(igGetVersion()));
}