module moxane.network.semantic;

import moxane.core.entity : Component;

public import cerealed : NoCereal;
alias NoSerialise = NoCereal;

enum SyncLifetime
{
	omnipresent,
	local,
	none
}

@Component
struct NetworkSemantic
{
	SyncLifetime syncLifetime;
}

immutable NetworkSemantic defaultSemantic = NetworkSemantic(SyncLifetime.none);

// 0 client id means either server, or singleplayer
alias ClientID = ushort;