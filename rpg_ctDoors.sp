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
#include <rpg_jobs_core>
#include <rpg_inventory_core>
#include <tCrime>

#pragma newdecls required

int g_iPlayerPrevButtons[MAXPLAYERS + 1];
int g_iSelectedDoorRef[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[T-RP] CT Doors", 
	author = PLUGIN_AUTHOR, 
	description = "Allows Police Officers to lock/unlock doors and prisoners escape", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart() {
	HookEvent("round_start", onRoundStart);
}

public void onRoundStart(Handle event, const char[] name, bool dontBroadcast) {
	lockDoors("jail_door");
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
					if (/*(StrContains(uniqueId, "ct_p_") != -1) || */StrContains(uniqueId, "jail_door") != -1) {
						if (jobs_isActiveJob(client, "Police")) {
							ctDoorMenu(client, ent);
						} else {
							if (inventory_hasPlayerItem(client, "Lockpick"))
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
		if (GetVectorDistance(playerPos, entPos) > 175.0) {
			PrintToChat(client, "[-T-] Door is too far away (%.2f/150.0)", GetVectorDistance(playerPos, entPos));
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
	if (action == MenuAction_End) {
		delete menu;
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

int g_iClientDoorTarget[MAXPLAYERS + 1];
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
		if (GetVectorDistance(playerPos, entPos) > 175.0) {
			PrintToChat(client, "[-T-] Door is too far away (%.2f/150.0)", GetVectorDistance(playerPos, entPos));
			return;
		}
		
		if (StrEqual(cValue, "lockpick")) {
			g_iClientDoorTarget[client] = EntIndexToEntRef(doorEnt);
			jobs_startProgressBar(client, 100, "Lockpicking CT Door");
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void jobs_OnProgressBarInterrupted(int client, char info[64]) {
	g_iClientDoorTarget[client] = -1;
}

public void jobs_OnProgressBarFinished(int client, char info[64]) {
	if (StrEqual(info, "Lockpicking CT Door")) {
		if (g_iClientDoorTarget[client] != -1) {
			if (GetRandomInt(0, 10) == 2) {
				AcceptEntityInput(EntRefToEntIndex(g_iClientDoorTarget[client]), "unlock", -1);
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

public void lockDoors(char[] name) {
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "func_door")) != INVALID_ENT_REFERENCE) {
		char uniqueId[64];
		GetEntPropString(entity, Prop_Data, "m_iName", uniqueId, sizeof(uniqueId));
		if (StrContains(uniqueId, name) != -1) {
			AcceptEntityInput(entity, "lock", -1);
		}
	}
}
