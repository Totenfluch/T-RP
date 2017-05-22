/*
							T-RP
   			Copyright (C) 2017 Christian Ziegler
   				 
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    
    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <rpg_inventory_core>
#include <tCrime>
#include <tConomy>
#include <rpg_jobs_core>
#include <rpg_lootdrop>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[T-RP] Deathpenalty", 
	author = PLUGIN_AUTHOR, 
	description = "Adds a penalty on player death", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
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
	
	float pos[3];
	GetClientAbsOrigin(client, pos);
	rpg_spawnMoneyLoot(pos[0], pos[1], pos[2], tConomy_getCurrency(client));
	
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