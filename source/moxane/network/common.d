module moxane.network.common;

import cerealed;

alias PacketID = ushort;
alias UserID = ushort;

enum PacketID availablePacketID = 3;

struct LoginPacket
{
	@NoCereal enum technicalName = typeid(LoginPacket).name;
	@NoCereal enum id = 0;

	PacketID packetID;

	string username;
	this(string username) {this.username = username; this.packetID = id;}
}

struct LoginVerificationPacket
{
	@NoCereal enum technicalName = typeid(LoginVerificationPacket).name;
	@NoCereal enum id = 1;

	PacketID packetID;

	bool accepted;
	UserID id;

	string[] packetMap;
}

struct AnnounceLoginPacket
{
	@NoCereal enum technicalName = typeid(AnnounceLoginPacket).name;
	@NoCereal enum id = 2;

	PacketID packetID;

	string username;
	UserID id;
}

struct MessagePacket
{
	@NoCereal enum technicalName = typeid(MessagePacket).name;

	PacketID packetID;

	string msg;
}