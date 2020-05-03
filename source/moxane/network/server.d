module moxane.network.server;

import moxane.core;
import moxane.network.common;

import derelict.enet.enet;
import cerealed;

import std.typecons;
import std.range;

@safe:

struct User
{
	string name;
	UserID id;
	ENetPeer* peer;
}

struct Users
{
	private User*[UserID] users;
	private UserID nextID_;
	@property UserID nextID() { return nextID_++; }

	UserID addUser(ENetPeer* peer)
	{
		auto id = nextID;
		User* user = new User;
		user.id = id;
		user.peer = peer;
		users[id] = user;
		return id;
	}

	void removeUser(UserID id)
	{
		users.remove(id);
	}

	User* fromID(UserID id)
	{
		User** user = id in users;
		assert(*user !is null);
		return *user;
	}
}

alias IncomingPacket = Tuple!(User*, "user", string, "packetName", ubyte[], "data");

class Server : PacketMap!IncomingPacket
{	
	private Users users;

	immutable ushort port;

	private ENetAddress serverAddress;
	private ENetHost* host;

	this(string[] packetNames, ushort port) @trusted
	{
		assert(packetNames.length < ushort.max - availablePacketID);
		this.port = port;

		super();

		enet_initialize();

		foreach(i, packetname; packetNames)
		{
			PacketID id = cast(PacketID)(i + availablePacketID);
			idToName[id] = packetname;
			nameToID[packetname] = id;
			distribution[packetname] = EventWaiter!IncomingPacket();
		}

		serverAddress.host = ENET_HOST_ANY;
		serverAddress.port = port;
		host = enet_host_create(&serverAddress, 32, 2, 0, 0);
	
		//distribution[LoginPacket.technicalName].addCallback(&onLogin);
		EventWaiter!IncomingPacket* e = LoginPacket.technicalName in distribution;
		e.addCallback(&onLogin);
	}

	void send(T)(User* user, string packetName, ref T data) @trusted
	{
		data.packetID = nameToID[packetName];
		ubyte[] bytes = cerealize(data);
		ENetPacket* packet = enet_packet_create(bytes.ptr, bytes.length, ENET_PACKET_FLAG_RELIABLE);
		enet_peer_send(user.peer, 0, packet);
	}

	void broadcast(T)(string packetName, ref T data) @trusted
	{
		data.packetID = nameToID[packetName];
		ubyte[] bytes = cerealize(data);
		ENetPacket* packet = enet_packet_create(bytes.ptr, bytes.length, ENET_PACKET_FLAG_RELIABLE);
		enet_host_broadcast(host, 0, packet);
	}

	private void onLogin(ref IncomingPacket packet)
	{
		LoginPacket login = decerealize!LoginPacket(packet.data);
		packet.user.name = login.username;
		LoginVerificationPacket verification;
		verification.accepted = true;
		verification.userID = packet.user.id;
		foreach(PacketID i; availablePacketID .. cast(PacketID)idToName.length)
		{
			verification.packetMap ~= idToName[i];
		}
		send(packet.user, verification.technicalName, verification);

		import std.stdio;
		writeln("User ", login.username, " signed in");
	}

	private void onConnect(ref ENetEvent event) @trusted
	{
		event.peer.data = cast(void*)users.addUser(event.peer);
		enet_peer_timeout(event.peer, 0, 0, 2000);
	}

	private void onDisconnect(ref ENetEvent event) @trusted
	{

	}

	private void onReceived(ref ENetEvent event) @trusted
	{
		ubyte[] data = event.packet.data[0 .. event.packet.dataLength];

		PacketID id = decerealize!ushort(data[0..PacketID.sizeof]);

		string* name = id in idToName;
		if(name is null) throw new Exception("lel");

		distribution[*name].emit(IncomingPacket(users.fromID(cast(UserID)event.peer.data), *name, data));
	}

	void update() @trusted
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
