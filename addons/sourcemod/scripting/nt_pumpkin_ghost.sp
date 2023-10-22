#include <sourcemod>
#include <sdktools>

#include <neotokyo>

#define PLUGIN_VERSION "0.1.0"

#define COLLISION_NONE 0
#define ATTACH_POINT "eyes"
// Attach the pumpkin below client eyes, so it doesn't block their vision
#define ATTACH_Z_OFFSET -32.0
#define EF_NODRAW 0x020

static int _pumpkins[NEO_MAXPLAYERS + 1] = { INVALID_ENT_REFERENCE, ... };
static int _trails[NEO_MAXPLAYERS + 1] = { INVALID_ENT_REFERENCE, ... };

public Plugin myinfo = {
	name = "NT Pumpkin Ghosts",
	description = "Halloween plugin for Neotokyo. Allow the dead players to \
float around as spooky ghosts.",
	author = "Rain",
	version = PLUGIN_VERSION,
	url = "https://github.com/Rainyan/sourcemod-nt-pumpkin-ghost"
};

public void OnPluginStart()
{
	if (!HookEventEx("player_death", OnPlayerDeath) ||
		!HookEventEx("player_spawn", OnPlayerSpawn) ||
		!HookEventEx("game_round_end", OnGameRoundEnd, EventHookMode_PostNoCopy))
	{
		SetFailState("Failed to hook event");
	}
}

public void OnClientDisconnect(int client)
{
	ClearGhost(client);
}

void ClearGhost(int client)
{
	int ent = EntRefToEntIndex(_pumpkins[client]);
	int trail = EntRefToEntIndex(_trails[client]);
	if (ent != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(ent, "Kill");
	}
	if (trail != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(trail, "Kill");
	}
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client == 0)
	{
		return;
	}

	ClearGhost(client);

	int ent = CreateEntityByName("prop_dynamic");
	if (ent == INVALID_ENT_REFERENCE)
	{
		ThrowError("Failed to create entity");
	}
	if (!DispatchKeyValue(ent, "model", "models/pumpkin/pumpkin.mdl"))
	{
		ThrowError("Failed to dispatch KeyValue");
	}
	if (!DispatchSpawn(ent))
	{
		ThrowError("Failed to dispatch spawn");
	}

	SetEntityRenderMode(ent, RENDER_TRANSCOLOR);
	int color[4];
	GetPumpkinColor(color);
	SetEntityRenderColor(ent, color[0], color[1], color[2], color[3]);

	AttachPropToClient(client, ATTACH_POINT, ent, ATTACH_Z_OFFSET);

	int st = CreateEntityByName("env_spritetrail");
	if (st == INVALID_ENT_REFERENCE)
	{
		ThrowError("Failed to create entity");
	}
	if (!DispatchKeyValue(st, "spritename", "materials/sprites/smoke.vmt"))
	{
		ThrowError("Failed to dispatch KeyValue");
	}
	if (!DispatchKeyValueInt(st, "solid", COLLISION_NONE))
	{
		ThrowError("Failed to dispatch KeyValue");
	}
	if (!DispatchKeyValueFloat(st, "lifetime", 0.25))
	{
		ThrowError("Failed to dispatch KeyValue");
	}
	if (!DispatchKeyValueFloat(st, "startwidth", 16.0))
	{
		ThrowError("Failed to dispatch KeyValue");
	}
	if (!DispatchKeyValueFloat(st, "endwidth", 1.0))
	{
		ThrowError("Failed to dispatch KeyValue");
	}
	if (!DispatchSpawn(st))
	{
		ThrowError("Failed to dispatch spawn");
	}
	SetEntityRenderMode(st, RENDER_TRANSADD);
	GetTrailColor(client, color);
	SetEntityRenderColor(st, color[0], color[1], color[2], color[3]);
	AttachPropToClient(client, ATTACH_POINT, st, ATTACH_Z_OFFSET);

	_pumpkins[client] = EntIndexToEntRef(ent);
	_trails[client] = EntIndexToEntRef(st);
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client != 0)
	{
		ClearGhost(client);
	}
}

public void OnGameRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for (int client = 1; client <= MaxClients; ++client)
	{
		ClearGhost(client);
	}
}

public void OnMapStart()
{
	char model[] = "models/pumpkin/pumpkin";
	decl String:ext_path[PLATFORM_MAX_PATH];
	char exts[][] = { "dx80.vtx", "dx90.vtx", "mdl", "phy", "sw.vtx", "vvd", "xbox.vtx" };
	for (int i = 0; i < sizeof(exts); ++i) {
		Format(ext_path, sizeof(ext_path), "%s.%s", model, exts[i]);
		if (StrEqual(exts[i], "mdl")) {
			if (PrecacheModel(ext_path) == 0)
			{
				SetFailState("Failed to precache: \"%s\"", ext_path);
			}
		}
		AddFileToDownloadsTable(ext_path);
	}
	AddFileToDownloadsTable("materials/models/pumpkin/black.vmt");
	AddFileToDownloadsTable("materials/models/pumpkin/green.vmt");
	AddFileToDownloadsTable("materials/models/pumpkin/pumpkin.vmt");
	AddFileToDownloadsTable("materials/models/pumpkin/pumpkin.vtf");
	AddFileToDownloadsTable("materials/models/pumpkin/pumpkin_illum.vtf");

	PrecacheGeneric("materials/sprites/smoke.vmt");
}

void GetPumpkinColor(int color[4])
{
	// RENDER_TRANSCOLOR: c*a+dest*(1-a)
	color = { 0, 255, 212, 24 };
}

void GetTrailColor(int client, int color[4])
{
#define ALPHA 32
	switch (GetClientTeam(client))
	{
		case TEAM_JINRAI:
			color = { 158, 255, 117, ALPHA };
		case TEAM_NSF:
			color = { 0, 148, 255, ALPHA };
		default:
			color = { 255, 106, 0, ALPHA };
	}
}

void AttachPropToClient(int client, const char[] attachment_name, int prop,
	float z_offset=0.0)
{
	if (client <= 0 || client > MaxClients)
	{
		ThrowError("Client index out of range: %d", client);
	}
	else if (!IsClientInGame(client))
	{
		ThrowError("Client is not in game");
	}
	else if (!IsPlayerAlive(client))
	{
		ThrowError("Client is not alive");
	}

	int attachment = LookupEntityAttachment(client, attachment_name);
	if (attachment == 0)
	{
		ThrowError("Attachment \"%s\" not found for client %d",
			attachment_name, client);
	}

	float pos[3]; float ang[3];
	if (!GetEntityAttachment(client, attachment, pos, ang))
	{
		ThrowError("Failed to get pos/ang for \"%s\" (%d)",
			attachment_name, attachment);
	}
	pos[2] += z_offset;

	TeleportEntity(prop, pos, ang, NULL_VECTOR);

	SetParent(prop, client, attachment);
}

void SetParent(int this_ent, int parent_ent, int attachment=-1)
{
	static Handle call = INVALID_HANDLE;
	if (call == INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetSignature(SDKLibrary_Server,
			"\x81\xEC\xDC\x00\x00\x00\x83\xBC\x24\xE4\x00\x00\x00\xFF", 14);
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		call = EndPrepSDKCall();
		if (call == INVALID_HANDLE)
		{
			ThrowError("Failed to prepare SDK call");
		}
	}
	SDKCall(call, this_ent, parent_ent, attachment);
}

public Action OnPlayerRunCmd(int client)
{
	int pumpkin = EntRefToEntIndex(_pumpkins[client]);
	if (pumpkin == INVALID_ENT_REFERENCE)
	{
		return Plugin_Continue;
	}

	int trail = EntRefToEntIndex(_trails[client]);

	int obs_mode = GetEntProp(client, Prop_Send, "m_iObserverMode");
	if (obs_mode != 5) // if not in free fly
	{
		if (AddEffects(pumpkin, EF_NODRAW) && trail != INVALID_ENT_REFERENCE)
		{
			SetEntityRenderMode(trail, RENDER_NONE);
		}
	}
	else
	{
		if (RemoveEffects(pumpkin, EF_NODRAW) && trail != INVALID_ENT_REFERENCE)
		{
			SetEntityRenderMode(trail, RENDER_TRANSADD);
		}
	}

	float ang[3];
	GetClientEyeAngles(client, ang);
	TeleportEntity(pumpkin, NULL_VECTOR, ang, NULL_VECTOR);

	return Plugin_Continue;
}

bool AddEffects(int ent, int effects)
{
	if (GetEntProp(ent, Prop_Send, "m_fEffects") & effects)
	{
		return false;
	}

	Handle call = INVALID_HANDLE;
	if (!call)
	{
		StartPrepSDKCall(SDKCall_Entity);
		char sig[] = "\x53\x8B\x5C\x24\x08\x55\x56\x8B\xE9\x8B\x45\x6C\x57\x8D\x7D\x6C\x8B\xF0";
		PrepSDKCall_SetSignature(SDKLibrary_Server, sig, sizeof(sig) - 1);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		call = EndPrepSDKCall();
		if (call == INVALID_HANDLE)
		{
			ThrowError("Failed to prepare SDK call");
		}
	}
	SDKCall(call, ent, effects);
	return true;
}

bool RemoveEffects(int ent, int effects)
{
	if (!(GetEntProp(ent, Prop_Send, "m_fEffects") & effects))
	{
		return false;
	}

	Handle call = INVALID_HANDLE;
	if (!call)
	{
		StartPrepSDKCall(SDKCall_Entity);
		char sig[] = "\x53\x8B\x5C\x24\x08\x55\x56\x8B\xE9\x8B\x45\x6C\x57\x8D\x7D\x6C\x8B\xF3";
		PrepSDKCall_SetSignature(SDKLibrary_Server, sig, sizeof(sig) - 1);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		call = EndPrepSDKCall();
		if (call == INVALID_HANDLE)
		{
			ThrowError("Failed to prepare SDK call");
		}
	}
	SDKCall(call, ent, effects);
	return true;
}