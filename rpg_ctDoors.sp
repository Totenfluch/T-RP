#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <rpg_jobs_core>
#include <rpg_inventory_core>
#include <tCrime>

#pragma newdecls required

int g_iPlayerPrevButtons[MAXPLAYERS + 1];
int g_iSelectedDoorRef[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Control Plugin for Police doos in T-RP", 
	author = PLUGIN_AUTHOR, 
	description = "Allows Police Officers to lock/unlock doors and prisoners escape", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart() {
	
}

public void OnClientPostAdminCheck(int client) {
	g_iPlayerPrevButtons[client] = 0;
	g_iSelectedDoorRef[client] = -1;
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon, int &tickcount) {
	if (!isValidClient(client))
		return;
	if (IsPlayerAlive(client)) {
		if (!(g_iPlayerPrevButtons[client] & IN_USE) && iButtons & IN_USE) {
			int ent = GetClientAimTarget(client, false);
			if (IsValidEntity(ent) && ent > 64) {
				if (HasEntProp(ent, Prop_Data, "m_iName")) {
					char uniqueId[64];
					GetEntPropString(ent, Prop_Data, "m_iName", uniqueId, sizeof(uniqueId));
					if (StrContains(uniqueId, "_ct_") != -1) {
						if (jobs_isActiveJob(client, "Police")) {
							ctDoorMenu(client, ent);
						} else {
							if (inventory_hasPlayerItem(client, "lockpick"))
								openCriminalMenu(client, ent);
						}
					}
				}
			}
		}
		g_iPlayerPrevButtons[client] = iButtons;
	}
}

public void ctDoorMenu(int client, int ent) {
	g_iSelectedDoorRef[client] = EntIndexToEntRef(ent);
	Menu ctMenu = CreateMenu(ctMenuHandler);
	SetMenuTitle(ctMenu, "CT Door");
	AddMenuItem(ctMenu, "x", "Ignore");
	AddMenuItem(ctMenu, "unlock", "Unlock Door");
	AddMenuItem(ctMenu, "lock", "Lock Door");
	DisplayMenu(ctMenu, client, 60);
}

public int ctMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "x"))
			return;
		
		int doorEnt = EntRefToEntIndex(g_iSelectedDoorRef[client]);
		float playerPos[3];
		float entPos[3];
		if (!isValidClient(client))
			return;
		if (!IsValidEntity(doorEnt))
			return;
		GetClientAbsOrigin(client, playerPos);
		GetEntPropVector(doorEnt, Prop_Data, "m_vecOrigin", entPos);
		if (GetVectorDistance(playerPos, entPos) > 100.0){
			PrintToChat(client, "[-T-] Door is too far away");
			return;
		}
		
		if (StrEqual(cValue, "lock")) {
			AcceptEntityInput(doorEnt, "lock", -1);
			PrintToChat(client, "[-T-] CT Door locked");
		} else if (StrEqual(cValue, "unlock")) {
			AcceptEntityInput(doorEnt, "unlock", -1);
			PrintToChat(client, "[-T-] Door unlocked");
		}
	}
}

public void openCriminalMenu(int client, int ent) {
	g_iSelectedDoorRef[client] = EntIndexToEntRef(ent);
	Menu criminalMenu = CreateMenu(criminalMenuHandler);
	SetMenuTitle(criminalMenu, "CT Door");
	AddMenuItem(criminalMenu, "x", "Ignore");
	AddMenuItem(criminalMenu, "lockpick", "Lockpick Door");
	DisplayMenu(criminalMenu, client, 60);
}

public int criminalMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "x"))
			return;
		
		int doorEnt = EntRefToEntIndex(g_iSelectedDoorRef[client]);
		float playerPos[3];
		float entPos[3];
		if (!isValidClient(client))
			return;
		if (!IsValidEntity(doorEnt))
			return;
		GetClientAbsOrigin(client, playerPos);
		GetEntPropVector(doorEnt, Prop_Data, "m_vecOrigin", entPos);
		if (GetVectorDistance(playerPos, entPos) > 100.0){
			PrintToChat(client, "[-T-] Door is too far away");
			return;
		}
		
		if (StrEqual(cValue, "lockpick")) {
			if (GetRandomInt(0, 10) == 2) {
				AcceptEntityInput(doorEnt, "unlock", -1);
				PrintToChat(client, "lockpicked CT Door...");
				tCrime_addCrime(client, 300);
			} else {
				PrintToChat(client, "lockpicking CT Door failed");
				tCrime_addCrime(client, 75);
			}
			if (GetRandomInt(0, 3) == 1) {
				inventory_removePlayerItems(client, "Lockpick", 1, "Lockpick broke");
				tCrime_addCrime(client, 50);
			}
		}
	}
}

stock bool isValidClient(int client) {
	return (1 <= client <= MaxClients && IsClientInGame(client));
}
