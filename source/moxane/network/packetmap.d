module moxane.network.packetmap;

import moxane.network.enet : BasicPacket = Packet;

struct SyncPacketMapPacket
{
	enum ushort id = 10;

	struct SyncSingle
	{
		string packetName;
		ushort id;
	}

	SyncSingle[] packetMaps;
}

struct Packet
{
	ushort id;
	ubyte[] data;
}

class PacketMap
{
	private void onHandleENetPacket(ref BasicPacket packet)
	{

	}
}