#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

int g_iPlayerTarget[MAXPLAYERS + 1];
char g_cInteraction[64] = "Give Item";

public Plugin myinfo = 
{
	name = "Item extension for Interact", 
	author = PLUGIN_AUTHOR, 
	description = "Adds the Option 'Give Item' to T-RP interact", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart()
{
	interact_registerInteract(g_cInteraction);
}

public void OnPlayerInteract(int client, int target, char interaction[64]) {
	if (!StrEqual(g_cInteraction, interaction))
		return;
	
	int moneyInBank = tConomy_getCurrency(client);
	Menu menu = CreateMenu(giveMoneyMenuHandler);
	char menuTitle[256];
	Format(menuTitle, sizeof(menuTitle), "Give %N an Item", g_iPlayerTarget[client]);
	
	DisplayMenu(menu, client, 60);
}

public int giveMoneyMenuHandler(Handle menu, MenuAction action, int client, int item) {
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
		char cValue[32];
		
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "???")) {
			// TODO
		} else {
			// TODO
		}
		
	}
}

public void OnClientPostAdminCheck(int client) {
	g_iPlayerTarget[client] = -1;
}

public void OnPlayerInteractionStarted(int client, int target) {
	g_iPlayerTarget[client] = target;
}

stock bool isValidClient(int client) {
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client))
		return false;
	
	return true;
}


