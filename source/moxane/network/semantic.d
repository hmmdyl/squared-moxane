module moxane.network.semantic;

import cerealed;
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