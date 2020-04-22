module moxane.network.server;

import moxane.core;
import moxane.network.common;

import derelict.enet.enet;

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
}

class Server
{
	void send(T)(UserID id, string packetName, T data)
	{

	}

	void broadcast(T)(string packetName, T data)
	{

	}
}
