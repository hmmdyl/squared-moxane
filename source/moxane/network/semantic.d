module moxane.network.semantic;

enum SyncLifetime
{
	omnipresent,
	local
}

struct NetworkSemantic
{
	SyncLifetime syncLifetime;
}

immutable NetworkSemantic defaultSemantic = NetworkSemantic(SyncLifetime.local);