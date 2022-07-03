#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <dhooks>
#include <multicolors>
#include <loghelper>
#include <adminhelper>
#tryinclude <zombiereloaded>

#pragma newdecls required
#pragma tabsize 0

#define CHAT_PREFIX "{green}[SM]{default}"

ConVar g_cEnable;
ConVar g_cSpecLimit;
ConVar g_cSpecLimitMode;
ConVar g_cSuicidePlayer;
ConVar g_cSpecListAdminOnly;

ConVar g_cAuthorizedFlags;

int g_iSpecAmount[MAXPLAYERS + 1] = { 0, ... };
int g_iClientSpectate[MAXPLAYERS + 1] = { -1, ... };
int g_iClientSpectators[MAXPLAYERS + 1][MAXPLAYERS + 1];
int g_iClientSpectatorCount[MAXPLAYERS + 1] = { 0, ... };

Handle hIsValidObserverTarget;

bool g_bCheckNullPtr = false;

EngineVersion g_iEngineVersion;

bool g_bLate = false;

public Plugin myinfo =
{
	name		= "Spectate",
	description	= "Adds a command to spectate specific players and removes broken spectate mode.",
	author		= "Obus, BotoX, maxime1907, .Rushaway",
	version		= "1.3.1",
	url			= ""
}

// Spectator Movement modes
enum Obs_Mode
{
	OBS_MODE_NONE = 0,	// not in spectator mode
	OBS_MODE_DEATHCAM,	// special mode for death cam animation
	OBS_MODE_FREEZECAM,	// zooms to a target, and freeze-frames on them
	OBS_MODE_FIXED,		// view from a fixed camera position
	OBS_MODE_IN_EYE,	// follow a player in first person view
	OBS_MODE_CHASE,		// follow a player in third person view
	OBS_MODE_POI,		// PASSTIME point of interest - game objective, big fight, anything interesting; added in the middle of the enum due to tons of hard-coded "<ROAMING" enum compares
	OBS_MODE_ROAMING,	// free roaming

	NUM_OBSERVER_MODES
};

// Spectator Movement modes
enum Obs_Mode_CSGO
{
	OBS_MODE_CSGO_NONE = 0,	// not in spectator mode
	OBS_MODE_CSGO_DEATHCAM,	// special mode for death cam animation
	OBS_MODE_CSGO_FREEZECAM,	// zooms to a target, and freeze-frames on them
	OBS_MODE_CSGO_FIXED,		// view from a fixed camera position
	OBS_MODE_CSGO_IN_EYE,	// follow a player in first person view
	OBS_MODE_CSGO_CHASE,		// follow a player in third person view
	OBS_MODE_CSGO_ROAMING,	// free roaming

	NUM_OBSERVER_MODES_CSGO,
};

enum LimitMode
{
	LIMIT_MODE_ROUND = 0,
	LIMIT_MODE_MAP
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Spectate_GetClientSpectators", Native_GetClientSpectators);
	RegPluginLibrary("Spectate");
	g_iEngineVersion = GetEngineVersion();
	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	g_cEnable = CreateConVar("sm_spec_enable", "1", "Plugin should be enable ? [0 = Disable, 1 = Enable]");
	g_cSpecLimitMode = CreateConVar("sm_speclimitmode", "0", "When does the limit is going to be reset [0 = Round end, 1 = Map end]");
	g_cSuicidePlayer = CreateConVar("sm_specsuicideplayer", "0", "Suicide player when using spec command [0 = No, 1 = Yes]");
	g_cSpecLimit = CreateConVar("sm_speclimit", "-1", "How many times players are allowed to use spec [-1 = Disabled]");
	g_cSpecListAdminOnly = CreateConVar("sm_speclist_adminonly", "1", "Should regular players be able to list their spectators [-1 = Yes and others, 0 = Yes, 1 = No]");

	g_cAuthorizedFlags = CreateConVar("sm_spec_authorizedflags", "", "Who is able to use the spec command [\"\" = Everyone, \"b,o\" = Generic and Custom1]");
	AdminHelper_SetupAuthorizedFlags(g_cAuthorizedFlags);

	RegConsoleCmd("sm_speclist", Command_SpectateList, "List of players currently spectating someone");

	RegConsoleCmd("sm_spectate", Command_Spectate, "Spectate a player.");
	RegConsoleCmd("sm_spec", Command_Spectate, "Spectate a player.");

	AddCommandListener(Command_SpectateViaConsole, "spectate");
	AddCommandListener(Command_GoTo, "spec_goto");

	HookEvent("player_spawn", Event_PlayerSpawnPost, EventHookMode_Post);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);

	// Hook spectate
    Handle hGameConf = LoadGameConfigFile("spectate.games");
    
    if(!hGameConf)
        SetFailState("Failed to load spectate.games.txt");

    int offset = GameConfGetOffset(hGameConf, "IsValidObserverTarget");
    hIsValidObserverTarget = DHookCreate(offset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity, IsValidObserverTarget);
    DHookAddParam(hIsValidObserverTarget, HookParamType_CBaseEntity);
    CloseHandle(hGameConf);
    
    g_bCheckNullPtr = (GetFeatureStatus(FeatureType_Native, "DHookIsNullParam") == FeatureStatus_Available);

	AutoExecConfig(true);

	for (int i = 0; i < MAXPLAYERS+1; i++)
		for (int y = 0; y < MAXPLAYERS+1; y++)
			g_iClientSpectators[i][y] = -1;

	if (g_bLate)
	{
		for (int client = 1; client <= MaxClients; client++)
			OnClientPutInServer(client);
	}
}

public void OnPluginEnd()
{
	for (int i = 0; i <= MaxClients; i++)
	{
		RemoveLastClientSpectate(i);
	}
	CloseHandle(hIsValidObserverTarget);
}

public void OnMapStart()
{
	GetTeams();
	if (g_cSpecLimitMode.IntValue == view_as<int>(LIMIT_MODE_MAP))
		ResetSpecLimit();
}

public void OnMapEnd()
{
	for (int i = 0; i <= MaxClients; i++)
	{
		RemoveLastClientSpectate(i);
	}
}

public void OnClientPutInServer(int client)
{
	g_iSpecAmount[client] = 0;

	if (!IsClientConnected(client) || !IsClientInGame(client)
		|| IsFakeClient(client) || IsClientSourceTV(client))
		return;

    DHookEntity(hIsValidObserverTarget, true, client);
}

public void OnClientDisconnect(int client)
{
	g_iSpecAmount[client] = 0;
	RemoveLastClientSpectate(client);
}

public void OnClientSettingsChanged(int client)
{
	if (g_iEngineVersion != Engine_CSGO)
	{
		static char sSpecMode[8];
		GetClientInfo(client, "cl_spec_mode", sSpecMode, sizeof(sSpecMode));

		Obs_Mode iObserverMode = view_as<Obs_Mode>(StringToInt(sSpecMode));

		// Skip broken OBS_MODE_POI
		if (iObserverMode == OBS_MODE_POI)
		{
			ClientCommand(client, "cl_spec_mode %d", OBS_MODE_ROAMING);
			if(IsClientInGame(client) && !IsPlayerAlive(client))
				SetEntProp(client, Prop_Send, "m_iObserverMode", OBS_MODE_ROAMING);
		}
	}
}

//   .d8888b.   .d88888b.  888b     d888 888b     d888        d8888 888b    888 8888888b.   .d8888b.
//  d88P  Y88b d88P" "Y88b 8888b   d8888 8888b   d8888       d88888 8888b   888 888  "Y88b d88P  Y88b
//  888    888 888     888 88888b.d88888 88888b.d88888      d88P888 88888b  888 888    888 Y88b.
//  888        888     888 888Y88888P888 888Y88888P888     d88P 888 888Y88b 888 888    888  "Y888b.
//  888        888     888 888 Y888P 888 888 Y888P 888    d88P  888 888 Y88b888 888    888     "Y88b.
//  888    888 888     888 888  Y8P  888 888  Y8P  888   d88P   888 888  Y88888 888    888       "888
//  Y88b  d88P Y88b. .d88P 888   "   888 888   "   888  d8888888888 888   Y8888 888  .d88P Y88b  d88P
//   "Y8888P"   "Y88888P"  888       888 888       888 d88P     888 888    Y888 8888888P"   "Y8888P"

public Action Command_SpectateList(int client, int argc)
{
	if (GetConVarInt(g_cEnable) == 1)
	{
		if (!client)
		{
			PrintToServer("[SM] Cannot use command from server console.");
			return Plugin_Handled;
		}

		if (g_cSpecListAdminOnly.IntValue != -1 && CheckCommandAccess(client, "", ADMFLAG_GENERIC)
			|| g_cSpecListAdminOnly.IntValue == -1)
		{
			if (argc == 1)
			{
				char sTarget[MAX_TARGET_LENGTH];
				GetCmdArg(1, sTarget, sizeof(sTarget));

				int iTarget;
				if ((iTarget = FindTarget(client, sTarget, false, false)) <= 0)
				{
					CReplyToCommand(client, "%s Invalid target.", CHAT_PREFIX);
					return Plugin_Handled;
				}
				if (!IsPlayerAlive(iTarget))
				{
					CReplyToCommand(client, "%s %t", CHAT_PREFIX, "Target must be alive");
					return Plugin_Handled;
				}

				PrintSpectateList(client, iTarget);

				return Plugin_Handled;
			}
		}

		if (g_cSpecListAdminOnly.IntValue == 0 || g_cSpecListAdminOnly.IntValue == -1
			|| g_cSpecListAdminOnly.IntValue == 1 && CheckCommandAccess(client, "", ADMFLAG_GENERIC))
			PrintSpectateList(client, client);
		return Plugin_Handled;
	}

	CReplyToCommand(client, "%s This feature is currently disabled by the server host.", CHAT_PREFIX);
	return Plugin_Handled;
}

public Action Command_Spectate(int client, int argc)
{
	if (GetConVarInt(g_cEnable) == 1)
	{
		if (!client)
		{
			PrintToServer("[SM] Cannot use command from server console.");
			return Plugin_Handled;
		}

		if (!AdminHelper_IsClientAuthorized(client))
		{
			CPrintToChat(client, "%s You do not have access to this command.", CHAT_PREFIX);
			return Plugin_Handled;
		}

		if (g_cSpecLimit.IntValue >= 0)
		{
			if (g_iSpecAmount[client] >= g_cSpecLimit.IntValue)
			{
				CPrintToChat(client, "%s You have used the maximum amount of spec authorized (%d/%d).", CHAT_PREFIX, g_iSpecAmount[client], g_cSpecLimit.IntValue);
				return Plugin_Handled;
			}
		}

	#if defined _zr_included
		if (IsPlayerAlive(client) && ZR_IsClientZombie(client))
		{
			bool bOnlyZombie = true;
			for (int i = 1; i <= MaxClients; i++)
			{
				if (i != client && IsClientInGame(i) && IsPlayerAlive(i) && ZR_IsClientZombie(i))
				{
					bOnlyZombie = false;
					break;
				}
			}

			if (bOnlyZombie)
			{
				CPrintToChat(client, "%s Can not switch to spectate as the last zombie!", CHAT_PREFIX);
				return Plugin_Handled;
			}
		}
	#endif

		if (!argc)
		{
			if (GetClientTeam(client) != CS_TEAM_SPECTATOR)
			{
	#if defined _zr_included
				if ((IsPlayerAlive(client) && ZR_IsClientHuman(client)) && GetTeamClientCount(CS_TEAM_T) > 0 && GetTeamAliveClientCount(CS_TEAM_T) > 0)
	#else
				if (IsPlayerAlive(client) && GetTeamClientCount(CS_TEAM_T) > 0 && GetTeamAliveClientCount(CS_TEAM_T) > 0)
	#endif
					LogPlayerEvent(client, "triggered", "switch_to_spec");

				if(g_cSuicidePlayer.IntValue == 1)
				{
			    	ForcePlayerSuicide(client);
				}
			
				ChangeClientTeam(client, CS_TEAM_SPECTATOR);

				if (g_cSpecLimit.IntValue >= 0)	
				{
					g_iSpecAmount[client]++;
					CPrintToChat(client, "%s You have used %d/%d allowed spec.", CHAT_PREFIX, g_iSpecAmount[client], g_cSpecLimit.IntValue);
				}
			}

			return Plugin_Handled;
		}

		char sTarget[MAX_TARGET_LENGTH];
		GetCmdArg(1, sTarget, sizeof(sTarget));

		int iTarget;
		if ((iTarget = FindTarget(client, sTarget, false, false)) <= 0)
			return Plugin_Handled;

		if (!IsPlayerAlive(iTarget))
		{
			CReplyToCommand(client, "%s %t", CHAT_PREFIX, "Target must be alive");
			return Plugin_Handled;
		}

		if (GetClientTeam(client) != CS_TEAM_SPECTATOR)
		{
	#if defined _zr_included
			if ((IsPlayerAlive(client) && ZR_IsClientHuman(client)) && GetTeamClientCount(CS_TEAM_T) > 0 && GetTeamAliveClientCount(CS_TEAM_T) > 0)
	#else
			if (IsPlayerAlive(client) && GetTeamClientCount(CS_TEAM_T) > 0 && GetTeamAliveClientCount(CS_TEAM_T) > 0)
	#endif
				LogPlayerEvent(client, "triggered", "switch_to_spec");

			if(g_cSuicidePlayer.IntValue == 1)
			{
				ForcePlayerSuicide(client);
			}
		
			ChangeClientTeam(client, CS_TEAM_SPECTATOR);
		}

		SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", iTarget);

		if (g_iEngineVersion != Engine_CSGO)
		{
			Obs_Mode iObserverMode = view_as<Obs_Mode>(GetEntProp(client, Prop_Send, "m_iObserverMode"));
			// If the client is currently in free roaming then switch them to first person view
			if (iObserverMode == OBS_MODE_ROAMING)
			{
				SetEntProp(client, Prop_Send, "m_iObserverMode", OBS_MODE_IN_EYE);
				ClientCommand(client, "cl_spec_mode %d", OBS_MODE_ROAMING);
			}
		}
		else
		{
			Obs_Mode_CSGO iObserverMode = view_as<Obs_Mode_CSGO>(GetEntProp(client, Prop_Send, "m_iObserverMode"));
			// If the client is currently in free roaming then switch them to first person view
			if (iObserverMode == OBS_MODE_CSGO_ROAMING)
			{
				SetEntProp(client, Prop_Send, "m_iObserverMode", OBS_MODE_CSGO_IN_EYE);
				ClientCommand(client, "cl_spec_mode %d", OBS_MODE_CSGO_ROAMING);
			}
		}

		if (g_cSpecLimit.IntValue >= 0)	
		{
			g_iSpecAmount[client]++;
			CPrintToChat(client, "%s You have used %d/%d allowed spec.", CHAT_PREFIX, g_iSpecAmount[client], g_cSpecLimit.IntValue);
		}

		CPrintToChat(client, "%s Spectating {olive}%N{default}.", CHAT_PREFIX, iTarget);

		return Plugin_Handled;
	}

	CReplyToCommand(client, "%s This feature is currently disabled by the server host.", CHAT_PREFIX);
	return Plugin_Handled;
}

public Action Command_SpectateViaConsole(int client, char[] command, int args)
{
	if (GetConVarInt(g_cEnable) == 1)
	{
	#if defined _zr_included
		if ((IsPlayerAlive(client) && ZR_IsClientHuman(client)) && GetTeamClientCount(CS_TEAM_T) > 0 && GetTeamAliveClientCount(CS_TEAM_T) > 0)
	#else
		if (IsPlayerAlive(client) && GetTeamClientCount(CS_TEAM_T) > 0 && GetTeamAliveClientCount(CS_TEAM_T) > 0)
	#endif
			LogPlayerEvent(client, "triggered", "switch_to_spec");

		return Plugin_Continue;
	}
	CReplyToCommand(client, "%s This feature is currently disabled by the server host.", CHAT_PREFIX);
	return Plugin_Handled;
}

// Fix spec_goto crash exploit
public Action Command_GoTo(int client, const char[] command, int argc)
{
	if (GetConVarInt(g_cEnable) == 1)
	{
		if(argc == 5)
		{
			for(int i = 1; i <= 3; i++)
			{
				char sArg[64];
				GetCmdArg(i, sArg, 64);
				float fArg = StringToFloat(sArg);

				if(FloatAbs(fArg) > 5000000000.0)
				{
					PrintToServer("%d -> %f > %f", i, FloatAbs(fArg), 5000000000.0);
					return Plugin_Handled;
				}
			}
		}

		return Plugin_Continue;
	}
	CReplyToCommand(client, "%s This feature is currently disabled by the server host.", CHAT_PREFIX);
	return Plugin_Handled;
}

// ##     ##  #######   #######  ##    ##  ######  
// ##     ## ##     ## ##     ## ##   ##  ##    ## 
// ##     ## ##     ## ##     ## ##  ##   ##       
// ######### ##     ## ##     ## #####     ######  
// ##     ## ##     ## ##     ## ##  ##         ## 
// ##     ## ##     ## ##     ## ##   ##  ##    ## 
// ##     ##  #######   #######  ##    ##  ######  

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (g_cSpecLimitMode.IntValue == view_as<int>(LIMIT_MODE_ROUND))
		ResetSpecLimit();
	return Plugin_Continue;
}

public Action Event_PlayerSpawnPost(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsFakeClient(client))
	{
		RemoveLastClientSpectate(client);
	}
	return Plugin_Continue;
}

public MRESReturn IsValidObserverTarget(int pThis, Handle hReturn, Handle hParams)
{
	// As of DHooks 1.0.12 we must check for a null param.
	if (g_bCheckNullPtr && DHookIsNullParam(hParams, 1))
		return MRES_Ignored;

	int client = pThis;
	int target = DHookGetParam(hParams, 1);
	if (target <= 0 || target > MaxClients || !IsClientInGame(client) || !IsClientInGame(target) || !IsPlayerAlive(target) || IsPlayerAlive(client))
	{
		RemoveLastClientSpectate(client);
		return MRES_Ignored;
	}
	else
	{
		RemoveLastClientSpectate(client);
		g_iClientSpectate[client] = target;
		g_iClientSpectators[target][g_iClientSpectatorCount[target]] = client;
		g_iClientSpectatorCount[target]++;
		DHookSetReturn(hReturn, true);
		return MRES_Override;
	}
}

stock void RemoveLastClientSpectate(int client)
{
	if (g_iClientSpectate[client] != -1)
	{
		bool bFound = false;
		for (int i = 0; i < g_iClientSpectatorCount[g_iClientSpectate[client]]; i++)
		{
			if (!bFound && g_iClientSpectators[g_iClientSpectate[client]][i] == client)
				bFound = true;

			if (bFound)
			{
				if (i + 1 < g_iClientSpectatorCount[g_iClientSpectate[client]])
					g_iClientSpectators[g_iClientSpectate[client]][i] = g_iClientSpectators[g_iClientSpectate[client]][i + 1];
				else
					g_iClientSpectators[g_iClientSpectate[client]][i] = -1;
			}
		}

		g_iClientSpectatorCount[g_iClientSpectate[client]]--;
	}
	g_iClientSpectate[client] = -1;
}

// ######## ##     ## ##    ##  ######  ######## ####  #######  ##    ##  ######  
// ##       ##     ## ###   ## ##    ##    ##     ##  ##     ## ###   ## ##    ## 
// ##       ##     ## ####  ## ##          ##     ##  ##     ## ####  ## ##       
// ######   ##     ## ## ## ## ##          ##     ##  ##     ## ## ## ##  ######  
// ##       ##     ## ##  #### ##          ##     ##  ##     ## ##  ####       ## 
// ##       ##     ## ##   ### ##    ##    ##     ##  ##     ## ##   ### ##    ## 
// ##        #######  ##    ##  ######     ##    ####  #######  ##    ##  ######

stock void PrintSpectateList(int client, int iTarget)
{
	if (g_iClientSpectatorCount[iTarget] <= 0)
	{
		CPrintToChat(client, "%s Spectators of {green}%N{default}: {olive}none{default}.", CHAT_PREFIX, iTarget);
		return;
	}

	char sBuffer[1024] = "";
	char sBufferTmp[256] = "";

	for (int i = 0; i < g_iClientSpectatorCount[iTarget]; i++)
	{
		Format(sBufferTmp, sizeof(sBufferTmp), "%N%s", g_iClientSpectators[iTarget][i], i + 1 < g_iClientSpectatorCount[iTarget] ? "{default}, {olive}" : "");
		StrCat(sBuffer, sizeof(sBuffer), sBufferTmp);
	}

	if (sBuffer[0] != '\0')
		CPrintToChat(client, "%s Spectators of {green}%N{default}: {olive}%s", CHAT_PREFIX, iTarget, sBuffer);
}

stock int GetTeamAliveClientCount(int iTeam)
{
	int ret = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != iTeam)
			continue;

		if (!IsPlayerAlive(i))
			continue;

		ret++;
	}

	return ret;
}

stock void ResetSpecLimit()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		g_iSpecAmount[client] = 0;
	}
}

//  888b    888        d8888 88888888888 8888888 888     888 8888888888 .d8888b.
//  8888b   888       d88888     888       888   888     888 888       d88P  Y88b
//  88888b  888      d88P888     888       888   888     888 888       Y88b.
//  888Y88b 888     d88P 888     888       888   Y88b   d88P 8888888    "Y888b.
//  888 Y88b888    d88P  888     888       888    Y88b d88P  888           "Y88b.
//  888  Y88888   d88P   888     888       888     Y88o88P   888             "888
//  888   Y8888  d8888888888     888       888      Y888P    888       Y88b  d88P
//  888    Y888 d88P     888     888     8888888     Y8P     8888888888 "Y8888P"

public int Native_GetClientSpectators(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client <= 0 || client > MaxClients)
		return 0;

	SetNativeArray(2, g_iClientSpectators[client], MAXPLAYERS+1);
	SetNativeCellRef(3, g_iClientSpectatorCount[client]);

	return 1;
}
