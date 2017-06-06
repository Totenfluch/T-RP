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
#include <rpg_interact>
#include <tStocks>
#include <rpg_jobs_core>

#pragma newdecls required

int g_iPlayerTarget[MAXPLAYERS + 1];
char g_cInteraction[64] = "Give Item";

public Plugin myinfo = 
{
	name = "[T-RP] Interact: Give Item", 
	author = PLUGIN_AUTHOR, 
	description = "Adds the Option 'Give Item' to T-RP interact", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart() {  }

public void OnMapStart() {
	interact_registerInteract(g_cInteraction);
}

public void OnPlayerInteract(int client, int target, char interaction[64]) {
	if (!StrEqual(g_cInteraction, interaction))
		return;
	
	Menu menu = CreateMenu(giveItemMenuHandler);
	char menuTitle[256];
	Format(menuTitle, sizeof(menuTitle), "Give %N an Item", g_iPlayerTarget[client]);
	SetMenuTitle(menu, menuTitle);
	int maxItems = inventory_getClientItemsAmount(client);
	for (int i = 0; i <= maxItems; i++) {
		if (inventory_isValidItem(client, i)) {
			char itemName[128];
			if (inventory_getItemNameBySlotAndClient(client, i, itemName, "")) {
				char cId[8];
				IntToString(i, cId, sizeof(cId));
				AddMenuItem(menu, cId, itemName);
			}
		}
	}
	DisplayMenu(menu, client, 60);
}

public int giveItemMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		float playerPos[3];
		float entPos[3];
		if (!isValidClient(client))
			return;
		if (!isValidClient(g_iPlayerTarget[client]))
			return;
		GetClientAbsOrigin(client, playerPos);
		GetClientAbsOrigin(g_iPlayerTarget[client], entPos);
		if (GetVectorDistance(playerPos, entPos) > 100.0)
			return;
		char cId[8];
		GetMenuItem(menu, item, cId, sizeof(cId));
		int theId = StringToInt(cId);
		char reason[256];
		Format(reason, sizeof(reason), "Transfered from %N to %N", client, g_iPlayerTarget[client]);
		
		char categoryBuffer[128];
		inventory_getItemCategoryBySlotAndClient(client, theId, categoryBuffer, "");
		if (StrEqual(categoryBuffer, "Police Weapon") && !jobs_isActiveJob(client, "Police")) {
			PrintToChat(client, "[-T-] Cannot transfer this Item");
			return;
		}
		
		char flags[8];
		inventory_getItemFlagsBySlot(client, theId, flags);
		if (StrContains(flags, "v") != -1 && !isVipRank2(g_iPlayerTarget[client])) {
			PrintToChat(client, "[-T-] Cannot transfer this Item (VIP Only)");
			return;
		}
		
		if (inventory_isValidItem(client, theId)) {
			inventory_transferItemToPlayerBySlot(client, g_iPlayerTarget[client], theId, reason);
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void OnClientPostAdminCheck(int client) {
	g_iPlayerTarget[client] = -1;
}

public void OnPlayerInteractionStarted(int client, int target) {
	g_iPlayerTarget[client] = target;
} 