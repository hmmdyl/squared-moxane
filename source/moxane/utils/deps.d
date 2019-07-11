module moxane.utils.deps;

import derelict.util.exception;
import derelict.freetype.ft : DerelictFT;
import derelict.freeimage.freeimage : DerelictFI;
import derelict.glfw3 : DerelictGLFW3;

private void loadFT()
{
	ShouldThrow missingFTSymbol(string symbol) {
		if(symbol == "FT_Stream_OpenBzip2")
			return ShouldThrow.No;
		else if(symbol == "FT_Get_CID_Registry_Ordering_Supplement")
			return ShouldThrow.No;
		else if(symbol == "FT_Get_CID_Is_Internally_CID_Keyed")
			return ShouldThrow.No;
		else if(symbol == "FT_Get_CID_From_Glyph_Index")
			return ShouldThrow.No;
		else
			return ShouldThrow.Yes;
	}
	DerelictFT.missingSymbolCallback = &missingFTSymbol;
	DerelictFT.load;
}

private void loadFI()
{
	ShouldThrow missingFISymbol(string symbol)
	{
		import std.stdio;
		writeln(symbol);
		return ShouldThrow.No;
	}
	DerelictFI.missingSymbolCallback = &missingFISymbol;
	DerelictFI.load;
}

private void loadGLFW3()
{
	DerelictGLFW3.load();
}

void loadDependencies()
{
	loadGLFW3;
	loadFT;
	loadFI;
}