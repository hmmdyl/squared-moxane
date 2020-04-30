module moxane.utils.deps;

import derelict.util.exception;
import derelict.freetype.ft : DerelictFT;
import derelict.freeimage.freeimage : DerelictFI;
import derelict.glfw3 : DerelictGLFW3;
import derelict.assimp3.assimp : DerelictASSIMP3;
import derelict.enet.enet : DerelictENet;
import bindbc.newton;

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
		return ShouldThrow.No;
	}
	DerelictFI.missingSymbolCallback = &missingFISymbol;
	DerelictFI.load;
}

private void loadGLFW3()
{
	DerelictGLFW3.load();
}

private void loadASSIMP3()
{
	ShouldThrow missingASSIMP3Symbol(string symbol)
	{
		return ShouldThrow.No;
	}
	DerelictASSIMP3.missingSymbolCallback = &missingASSIMP3Symbol;
	DerelictASSIMP3.load();
}

private void loadENet()
{
	DerelictENet.load;
}

void loadDependencies()
{
	loadGLFW3;
	loadFT;
	loadFI;
	loadASSIMP3;
	loadNewton;
	loadENet;
}