#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <rpg_furniture>
#include <rpg_jobs_core>

#pragma newdecls required

bool g_bIsHealing[MAXPLAYERS + 1];
int g_iLastBedUsed[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Furniture: Bed for T-RP", 
	author = PLUGIN_AUTHOR, 
	description = "Adds an interaction for the Furniture Bed", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart() {  }

public void OnClientPostAdminCheck(int client) {
	g_bIsHealing[client] = false;
	g_iLastBedUsed[client] = -1;
}


public void furniture_OnFurnitureInteract(int entity, int client, char name[64], char lfBuf[64], char flags[8], char ownerId[20], int durability) {
	if (!StrEqual(name, "Double Bed") && !StrEqual(name, "Classic Bed"))
		return;
	
	g_bIsHealing[client] = true;
	jobs_startProgressBar(client, 200, "Resting (to 60hp)");
}

public void OnMapStart() {
	CreateTimer(2.0, refreshTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action refreshTimer(Handle Timer) {
	for (int i = 1; i < MAXPLAYERS; i++) {
		if (!isValidClient(i))
			continue;
		if (!g_bIsHealing[i])
			continue;
		int health;
		if ((health = GetClientHealth(i)) >= 60)
			continue;
		SetEntityHealth(i, health + 1);
	}
}

public void jobs_OnProgressBarInterrupted(int client, char info[64]) {
	g_bIsHealing[client] = false;
}

public void jobs_OnProgressBarFinished(int client, char info[64]) {
	g_bIsHealing[client] = false;
}

stock bool isValidClient(int client) {
	return (1 <= client <= MaxClients && IsClientInGame(client));
}
