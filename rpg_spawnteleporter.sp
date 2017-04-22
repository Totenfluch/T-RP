#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <devzones>
#include <tStocks>
#include <autoexecconfig>
#include <rpg_jobs_core>

#pragma newdecls required

float g_fSpawnX;
float g_fSpawnY;
float g_fSpawnZ;
int g_iTeleportDelay;

Handle g_hSpawnX;
Handle g_hSpawnY;
Handle g_hSpawnZ;
Handle g_hTeleportDelay;

int g_iPlayerDelay[MAXPLAYERS + 1];
bool g_bCanTeleport;


public Plugin myinfo = 
{
	name = "RP Spawn Teleporter", 
	author = PLUGIN_AUTHOR, 
	description = "Teleports players into the map", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart()
{
	AutoExecConfig_SetFile("rpg_spawnteleporter");
	AutoExecConfig_SetCreateFile(true);
	
	g_hSpawnX = AutoExecConfig_CreateConVar("spawn_teleportPositionX", "-2920.29", "X-Position where the spawn teleporter leads to");
	g_hSpawnY = AutoExecConfig_CreateConVar("spawn_teleportPositionY", "-276.88", "Y-Position where the spawn teleporter leads to");
	g_hSpawnZ = AutoExecConfig_CreateConVar("spawn_teleportPositionUz", "-50.79", "Z-Position where the spawn teleporter leads to");
	g_hTeleportDelay = AutoExecConfig_CreateConVar("spawn_delay", "300", "Delay in Seconds to block teleport for a Player");
	
	AutoExecConfig_CleanFile();
	AutoExecConfig_ExecuteFile();
	
	HookEvent("player_death", onPlayerDeath);
	RegConsoleCmd("sm_ttr", timetoRespawnCommand);
}

public Action onPlayerDeath(Handle event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (isValidClient(client)) {
		g_iPlayerDelay[client] = g_iTeleportDelay;
		PrintToChat(client, "[-T-] You can enter the game in %is again. Type !ttr to check the remaining time", g_iTeleportDelay);
	}
}

public Action timetoRespawnCommand(int client, int args) {
	PrintToChat(client, "Time to teleport: %is", g_iPlayerDelay[client]);
	return Plugin_Handled;
}

public void OnConfigsExecuted() {
	g_fSpawnX = GetConVarFloat(g_hSpawnX);
	g_fSpawnY = GetConVarFloat(g_hSpawnY);
	g_fSpawnZ = GetConVarFloat(g_hSpawnZ);
	
	g_iTeleportDelay = GetConVarInt(g_hTeleportDelay);
}

public void OnClientPostAdminCheck(int client) {
	g_iPlayerDelay[client] = 0;
}

public void OnMapStart() {
	g_bCanTeleport = false;
	CreateTimer(1.0, refreshTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(20.0, startTimer);
}

public Action startTimer(Handle Timer) {
	g_bCanTeleport = true;
}

public Action refreshTimer(Handle Timer) {
	for (int i = 0; i < MAXPLAYERS; i++) {
		if (!g_bCanTeleport)
			continue;
		if (!isValidClient(i))
			continue;
		if (g_iPlayerDelay[i] == 0)
			continue;
		if (g_iPlayerDelay[i] > 0) {
			g_iPlayerDelay[i]--;
			char info[128];
			Format(info, sizeof(info), "> Teleport in %is", g_iPlayerDelay[i]);
			if (Zone_IsClientInZone(i, "spawn_teleporter"))
				jobs_setCurrentInfo(i, info);
		}
		if (g_iPlayerDelay[i] == 0) {
			jobs_setCurrentInfo(i, "");
			if (Zone_IsClientInZone(i, "spawn_teleporter"))
				teleportPlayer(i);
		}
	}
}

public int Zone_OnClientEntry(int client, char[] zone) {
	if (StrEqual(zone, "spawn_teleporter", false)) {
		if (g_iPlayerDelay[client] == 0) {
			teleportPlayer(client);
		}
	}
}

public void teleportPlayer(int client) {
	if (!isValidClient(client))
		return;
	if (!g_bCanTeleport)
		return;
	g_iPlayerDelay[client] = g_iTeleportDelay;
	float pos[3];
	pos[0] = g_fSpawnX;
	pos[1] = g_fSpawnY;
	pos[2] = g_fSpawnZ;
	TeleportEntity(client, pos, NULL_VECTOR, NULL_VECTOR);
}
