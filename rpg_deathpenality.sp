#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <rpg_inventory_core>
#include <tCrime>
#include <tConomy>
#include <rpg_jobs_core>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "T-RP Deathpenalty", 
	author = PLUGIN_AUTHOR, 
	description = "Adds a penalty on player death", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart() {
	HookEvent("player_death", onPlayerDeath);
}

public Action onPlayerDeath(Handle event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	char reason[256];
	if (isValidClient(attacker) && isValidClient(client)) {
		Format(reason, sizeof(reason), "You died (Killed by %N)", attacker);
		if (jobs_getActiveJob(attacker, "Police"))
			tCrime_setCrime(client, 0);
	} else
		Format(reason, sizeof(reason), "You died (Suicide)");
	
	if (!isValidClient(client))
		return;
	
	tConomy_setCurrency(client, 0, "You died...");
	int maxItems = inventory_getClientItemsAmount(client);
	for (int i = 0; i <= maxItems; i++) {
		if (inventory_isValidItem(client, i)) {
			char itemName[128];
			if (inventory_getItemNameBySlotAndClient(client, i, itemName, "")) {
				inventory_deleteItemBySlot(client, i, reason);
			}
		}
	}
	
}

stock bool isValidClient(int client) {
	return (1 <= client <= MaxClients && IsClientInGame(client));
} 