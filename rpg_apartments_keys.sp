#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <rpg_apartments>
#include <rpg_inventory_core>
#include <tConomy>
#include <rpg_interact>

#pragma newdecls required
char g_cInteraction[64] = "Give Apartment Keys";

public Plugin myinfo = 
{
	name = "Keys for T-RP Apartments", 
	author = PLUGIN_AUTHOR, 
	description = "Adds Keys to the Apartments of T-RP", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart() {  }

public void OnMapStart() {
	interact_registerInteract(g_cInteraction);
}

stock bool isValidClient(int client) {
	return (1 <= client <= MaxClients && IsClientInGame(client));
}

public void OnPlayerInteract(int client, int target, char interaction[64]) {
	if (!StrEqual(g_cInteraction, interaction))
		return;
	
	aparments_allowPlayer(client, target);
} 