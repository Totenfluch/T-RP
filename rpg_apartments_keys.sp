#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <rpg_apartments>
#include <rpg_inventory_core>
#include <rpg_npc_core>
#include <tConomy>
#include <rpg_interact>

#pragma newdecls required
int g_iLastInteractedWith[MAXPLAYERS + 1];
char my_npcType[128] = "Key Vendor";
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
	inventory_addItemHandle("Apartment Key", 1);
	npc_registerNpcType(my_npcType);
}

public void OnNpcInteract(int client, char npcType[64], char UniqueId[128], int entIndex) {
	if (!StrEqual(my_npcType, npcType))
		return;
	g_iLastInteractedWith[client] = entIndex;
	showTopPanelToClient(client);
}

public void showTopPanelToClient(int client) {
	Menu KeyMenu = CreateMenu(KeyMenuHandler);
	SetMenuTitle(KeyMenu, "Apartment Key Vendor");
	char displayText[64];
	Format(displayText, sizeof(displayText), "Generic Apartment Key (500)");
	if (tConomy_getCurrency(client) >= 500) {
		AddMenuItem(KeyMenu, "generic", displayText);
	} else {
		AddMenuItem(KeyMenu, "x", displayText, ITEMDRAW_DISABLED);
	}
	DisplayMenu(KeyMenu, client, 60);
}

public int KeyMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		float playerPos[3];
		float entPos[3];
		if (!isValidClient(client))
			return;
		if (!IsValidEntity(g_iLastInteractedWith[client]))
			return;
		GetClientAbsOrigin(client, playerPos);
		GetEntPropVector(g_iLastInteractedWith[client], Prop_Data, "m_vecOrigin", entPos);
		if (GetVectorDistance(playerPos, entPos) > 100.0)
			return;
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "generic")) {
			if (tConomy_getCurrency(client) >= 500) {
				if (inventory_givePlayerItem(client, "Apartment Key", 1, "", "Key", "Apartment", 1, "Bought from Key Vendor"))
					tConomy_removeCurrency(client, 500, "Bought Generic Key");
			}
		}
	}
	if (action == MenuAction_End) { 
    	delete menu; 
	}
}

stock bool isValidClient(int client) {
	return (1 <= client <= MaxClients && IsClientInGame(client));
}

public void OnPlayerInteract(int client, int target, char interaction[64]) {
	if (!StrEqual(g_cInteraction, interaction))
		return;
	
	aparments_allowPlayer(client, target);
} 