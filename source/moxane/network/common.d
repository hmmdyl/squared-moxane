module moxane.network.common;

import moxane.core;
import moxane.utils.maybe;

import cerealed;

@safe:

abstract class PacketMap(TEvent)
{
	protected string[PacketID] idToName;
	protected PacketID[string] nameToID;
	protected EventWaiter!TEvent[string] distribution;
	@property ref EventWaiter!TEvent event(string name) { return distribution[name]; }

	this() @trusted
	{
		nameToID[LoginPacket.technicalName] = LoginPacket.id;
		idToName[LoginPacket.id] = LoginPacket.technicalName;
		distribution[LoginPacket.technicalName] = EventWaiter!TEvent();

		nameToID[LoginVerificationPacket.technicalName] = LoginVerificationPacket.id;
		idToName[LoginVerificationPacket.id] = LoginVerificationPacket.technicalName;
		distribution[LoginVerificationPacket.technicalName] = EventWaiter!TEvent();

		nameToID[AnnounceLoginPacket.technicalName] = AnnounceLoginPacket.id;
		idToName[AnnounceLoginPacket.id] = AnnounceLoginPacket.technicalName;
		distribution[AnnounceLoginPacket.technicalName] = EventWaiter!TEvent();
	}

	bool has(string packetName) { return (packetName in nameToID) !is null; }
	bool has(PacketID id) { return (id in idToName) !is null; }

	Maybe!PacketID get(string packetName) @trusted
	{
		PacketID* id = packetName in nameToID;
		if(id is null)return Maybe!PacketID();
		else return Maybe!PacketID(*id);
	}

	string get(PacketID id) @trusted
	{
		string* name = id in idToName;
		return *name;
	}
}

alias PacketID = ushort;
alias UserID = ushort;

enum PacketID availablePacketID = 3;

struct LoginPacket
{
	static string technicalName() { return typeid(LoginPacket).name; };
	static PacketID id() { return 0; }

	PacketID packetID;

	string username;
	this(string username) {this.username = username; this.packetID = id;}
}

struct LoginVerificationPacket
{
	static string technicalName() { return typeid(LoginVerificationPacket).name; };
	static PacketID id() { return 1; }

	PacketID packetID;

	bool accepted;
	UserID userID;

	string[] packetMap;
}

struct AnnounceLoginPacket
{
	static string technicalName() { return typeid(AnnounceLoginPacket).name; };
	static PacketID id() { return 2; }

	PacketID packetID;

	string username;
	UserID userID;
}

struct MessagePacket
{
	static string technicalName() { return typeid(MessagePacket).name; };

	PacketID packetID;

	string msg;
}