module moxane.network.enet;

import derelict.enet.enet;
import derelict.enet.funcs;
import derelict.enet.types;

import core.thread;

import std.container.dlist;

import moxane.core.eventwaiter;

@safe:

struct Packet
{
	ubyte[] data;
}

struct User
{
	size_t id;
	string username;
}

class PrimitiveServer
{
	private ENetHost* host;
	private ENetAddress address;

	private Thread thread;
	bool shutdown;

	private size_t nextID;

	private DList!Packet recievedQueue;
	EventWaiter!Packet onPacketRecieved;

	this()
	{

	}

	void update()
	{
		synchronized(this)
		{
			foreach(ref Packet recievedPacket; recievedQueue)
				onPacketRecieved.emit(recievedPacket);
			recievedQueue.clear;
		}
	}

	private void enetUpdater() @trusted
	{
		while(!shutdown)
		{
			ENetEvent event;
			int eventStatus = enet_host_service(host, &event, 100);

			switch(event.type)
			{
				case ENET_EVENT_TYPE_RECEIVE:
					handlePacketRecieved(event);
					break;
				default: break;
			}
		}
	}

	private void handlePacketRecieved(ref ENetEvent event) @trusted
	{
		synchronized(this)
		{
			ubyte[] data = new ubyte[event.packet.dataLength];
			foreach(i; 0 .. event.packet.dataLength) data[i] = event.packet.data[i];
			void* userData = event.packet.userData;

			enet_packet_destroy(event.packet);
			event.packet = null;

			Packet packet;
			packet.data = data;

			recievedQueue.insertBack(packet);
		}
	}
}