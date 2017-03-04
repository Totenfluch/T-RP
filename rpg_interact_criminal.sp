#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <rpg_inventory_core>
#include <rpg_jobs_core>
#include <rpg_interact>
#include <tConomy>
#include <tCrime>

#pragma newdecls required

bool g_bIsZiptied[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Criminal Interact for T-RP", 
	author = PLUGIN_AUTHOR, 
	description = "Adds Criminal Interactions for T-RP", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart()
{
	
}

public void OnClientPostAdminCheck(int client) {
	g_bIsZiptied[client] = false;
}

public void OnMapStart() {
	interact_registerInteract("Criminal Actions");
	interact_registerInteract("Try to free");
}

int g_iPlayerTarget[MAXPLAYERS + 1];
public void OnPlayerInteract(int client, int target, char interact[64]) {
	if (StrEqual(interact, "Criminal Actions")) {
		Menu m = CreateMenu(criminalInteractionsMenuHandler);
		SetMenuTitle(m, "Do something Criminal...");
		AddMenuItem(m, "steal", "Steal Money", ITEMDRAW_DISABLED);
		AddMenuItem(m, "ziptie", "Ziptie Player", inventory_hasPlayerItem(client, "ziptie") ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
		DisplayMenu(m, client, 30);
		g_iPlayerTarget[client] = target;
	} else if (StrEqual(interact, "Try to free")) {
		if (g_bIsZiptied[target]) {
			g_iPlayerTarget[client] = target;
			jobs_startProgressBar(client, 10, "Free Player");
		} else
			PrintToChat(client, "[-T-] %N doesn't need to be freed", target);
	}
}

public int criminalInteractionsMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		
		if (StrEqual(cValue, "steal")) {
			if (isValidClient(g_iPlayerTarget[client]))
				PrintToChat(g_iPlayerTarget[client], "[-T-] %N tries to steal your money!!!!", client);
			jobs_startProgressBar(client, 50, "Steal Money");
		} else if (StrEqual(cValue, "ziptie")) {
			jobs_startProgressBar(client, 15, "Ziptie Player");
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void jobs_OnProgressBarFinished(int client, char info[64]) {
	if (!StrEqual(info, "Steal Money") && !StrEqual(info, "Ziptie Player") && !StrEqual(info, "Free Player"))
		return;
	
	float ppos[3];
	float tpos[3];
	GetClientAbsOrigin(client, ppos);
	if (isValidClient(g_iPlayerTarget[client]))
		GetClientAbsOrigin(g_iPlayerTarget[client], tpos);
	else
		return;
	if (GetVectorDistance(ppos, tpos) > 150.0) {
		PrintToChat(client, "[-T-] Target is too far away...");
		return;
	}
	
	if (StrEqual(info, "Steal Money")) {
		int amount = RoundToNearest(tConomy_getCurrency(g_iPlayerTarget[client]) / 10.0);
		char reason[256];
		Format(reason, sizeof(reason), "Stolen from %N", g_iPlayerTarget[client]);
		tConomy_addCurrency(client, amount, reason);
		Format(reason, sizeof(reason), "Stolen by %N", client);
		tConomy_removeCurrency(g_iPlayerTarget[client], amount, reason);
		tCrime_addCrime(client, amount * 2);
	} else if (StrEqual(info, "Ziptie Player")) {
		if (inventory_removePlayerItems(client, "ziptie", 1, "Ziptied Player")) {
			ziptiePlayer(g_iPlayerTarget[client], client);
			tCrime_addCrime(client, 100);
		}
	} else if (StrEqual(info, "Free Player")) {
		unzipPlayer(g_iPlayerTarget[client], client);
	}
}

public void ziptiePlayer(int client, int initiator) {
	if (!isValidClient(client))
		return;
	g_bIsZiptied[client] = true;
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 0.0);
	PrintToChat(client, "[-T-] You were Ziptied by %N", initiator);
}

public void unzipPlayer(int client, int initiator) {
	if (!isValidClient(client))
		return;
	g_bIsZiptied[client] = false;
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
	PrintToChat(client, "[-T-] You were freed by %N", initiator);
}

stock bool isValidClient(int client) {
	return (1 <= client <= MaxClients && IsClientInGame(client));
} 