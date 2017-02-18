#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <emitsoundany>

#pragma newdecls required

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
}

public void furniture_OnFurnitureInteract(int entity, int client, char name[64], char lfBuf[64], char flags[8], char ownerId[20], int durability) {
	if (!StrEqual(name, "Piano"))
		return;
	
	float ObjectOrigin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", ObjectOrigin);
	EmitAmbientSoundAny("rp/elise2.mp3", ObjectOrigin, _, _, _, _, _, _);
}




