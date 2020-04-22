module moxane.network.log;

import moxane.core;

@safe:

class NetworkLog : Log 
{
	this() { super("networkLog", "Network"); }
}