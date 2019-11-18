module moxane.network.semantic;

public import cerealed : NoCereal;
alias NoSerialise = NoCereal;

enum SyncLifetime
{
	omnipresent,
	local,
	none
}

struct NetworkSemantic
{
	SyncLifetime syncLifetime;
}

immutable NetworkSemantic defaultSemantic = NetworkSemantic(SyncLifetime.none);

// 0 client id means either server, or singleplayer
alias ClientID = ushort;