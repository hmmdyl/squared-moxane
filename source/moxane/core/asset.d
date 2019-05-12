module moxane.core.asset;

import moxane.core.engine;

import std.typecons;
import std.path;
import std.file;

interface IAssetLoader
{
	Object handle(AssetManager am, TypeInfo ti, string dir);
}

class AssetManager
{
	IAssetLoader[TypeInfo] loaders;
	private Object[Tuple!(TypeInfo, string)] instances;

	Moxane moxane;

	this(Moxane moxane)
	{
		this.moxane = moxane;
	}

	void registerLoader(T)(IAssetLoader loader)
	{
		loaders[typeid(T)] = loader;
	}

	static string translateToAbsoluteDir(string dir)
	{
		assert(dir[0] != '/' && dir[0] != '\\', "dir[0] must not be a slash");
		return buildPath(getcwd, dir);
	}

	T load(T)(string dir)
	{
		auto type = Tuple!(TypeInfo, string)(typeid(T), dir);
		Object* inst = type in instances;
		if(inst is null)
		{
			T item = uniqueLoad!T(dir);
			instances[type] = item;
			return item;
		}
		else
			return cast(T)(*inst);
	}

	T uniqueLoad(T)(string dir)
	{
		return cast(T)loaders[typeid(T)].handle(this, typeid(T), dir);
	}
}