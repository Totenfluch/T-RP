#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <emitsoundany>

#pragma newdecls required

int g_iInternalCooldown[2048];

public Plugin myinfo = 
{
	name = "Piano for T-RP", 
	author = PLUGIN_AUTHOR, 
	description = "adds sound for the Piano", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart()
{
	AddFileToDownloadsTable("sound/rp/elise2.mp3");
	PrecacheSoundAny("rp/elise2.mp3", true);
}

public void OnMapStart() {
	AddFileToDownloadsTable("sound/rp/elise2.mp3");
	PrecacheSoundAny("rp/elise2.mp3", true);
	CreateTimer(5.0, refreshTimer, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

public void furniture_OnFurnitureInteract(int entity, int client, char name[64], char lfBuf[64], char flags[8], char ownerId[20], int durability) {
	if (!StrEqual(name, "Piano"))
		return;
	
	if (g_iInternalCooldown[entity] != 0)
		return;
	g_iInternalCooldown[entity] = 32;
	
	float ObjectOrigin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", ObjectOrigin);
	// https://forums.alliedmods.net/showthread.php?p=737647
	EmitAmbientSoundAny("rp/elise2.mp3", ObjectOrigin, _, _, 2, _, _, _); // 2 -> 2 - Small Radius - Sound range is about 800 units at max volume.
}

public Action refreshTimer(Handle Timer) {
	for (int i = 0; i < 2048; i++) {
		if (g_iInternalCooldown[i] == 0)
			continue;
		else
			g_iInternalCooldown[i]--;
	}
}




