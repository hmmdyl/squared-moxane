module moxane.network.client;

import moxane.core;
import moxane.network.common;

import derelict.enet.enet;
import cerealed;

import std.typecons;

@safe:

class Client
{
	private string[PacketID] idToName;
	private PacketID[string] nameToID;
	private EventWaiter!(Tuple!(string, ubyte[]))[string] distribution;
	@property ref EventWaiter!(Tuple!(string, ubyte[])) event(string name) { return distribution[name]; }

	private UserID id_;
	@property UserID id() const { return id_; }

	private string address_;
	immutable ushort port;
	private string username_;

	@property string address() { return address_; }
	@property string username() { return username_; }

	private ENetHost* host;
	private ENetAddress address;
	private ENetPeer* server;

	private bool isConfigured_;
	@property bool isConfigured() const { return isConfigured_; }

	this(string address, ushort port, string username)
	{
		this.address_ = address;
		this.port = port;
		this.username_ = username;

		enet_address_set_host(&address, cast(char*)address);
		address.port = port;

		host = enet_host_create(null, 1, 2, 0, 0);
		if(host is null) throw new Exception("host is null");

		server = enet_host_connect(host, &address, 2, 0);
		if(server is null) throw new Exception("server is null");

		nameToID[LoginPacket.technicalName] = LoginPacket.id;
		idToName[LoginPacket.id] = LoginPacket.technicalName;
		nameToID[LoginVerificationPacket.technicalName] = LoginVerificationPacket.id;
		idToName[LoginVerificationPacket.id] = LoginVerificationPacket.technicalName;
		nameToID[AnnounceLoginPacket.technicalName] = AnnounceLoginPacket.id;
		idToName[AnnounceLoginPacket.id] = AnnounceLoginPacket.technicalName;

		distribution[LoginVerificationPacket.technicalName].addCallback(&onLoginVerify);
	}

	private void onLoginVerify(string name, ubyte[] packet)
	{
		LoginVerificationPacket loginVerification = decerealize!LoginVerificationPacket(packet);
		if(!loginVerification.accepted) throw new Exception("Login not allowed");

		id_ = loginVerification.id;

		foreach(id, packet; loginVerification.packetMap)
		{
			nameToID[packet] = id + availablePacketID;
			idToName[id + availablePacketID] = packet;
		}

		isConfigured_ = true;
	}

	private void onConnect(ref ENetEvent event)
	{
		LoginPacket packet = LoginPacket(username_);
		send!LoginPacket(LoginPacket.technicalName, packet);
	}

	private void onDisconnect(ref ENetEvent event)
	{

	}

	private void onReceived(ref ENetEvent event)
	{
		ubyte[] data = event.packet.data[0 .. event.packet.dataLength];

		PacketID id;
		ubyte[] idArr = (*cast(ubyte[PacketID.sizeof]*)&id);
		idArr[0..$] = data[0..PacketID.sizeof];

		string* name = id in idToName;
		if(name is null) throw new Exception("lel");

		distribution[*name].emit(tuple(*name, data));
	}

	void send(T)(string name, T data)
	{
		PacketID* id = name in nameToID;
		if(id is null) throw new Exception("Packet not mapped");

		ubyte[] data = cerealize!T(data);
		ENetPacket* packet = enet_packet_create(data.ptr, data.length, 
			ENET_PACKET_FLAG_RELIABLE);
		enet_peer_send(server, 0, packet);
	}

	void update()
	{
		ENetEvent event;
		int status = enet_host_service(host, &event, 0);
		if(status == 0) return;

		final switch(event.type)
		{
			case ENET_EVENT_TYPE_NONE: break;
			case ENET_EVENT_TYPE_CONNECT: onConnect(event); break;
			case ENET_EVENT_TYPE_DISCONNECT: onDisconnect(event); break;
			case ENET_EVENT_TYPE_RECEIVE: onReceived(event); break;
		}
	}
}