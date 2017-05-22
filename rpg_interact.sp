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
#include <rpg_job_police>

#pragma newdecls required

int g_iPlayerPrevButtons[MAXPLAYERS + 1];

Handle g_hOnPlayerInteractionStarted;
Handle g_hOnPlayerInteraction;

ArrayList g_aInteractions;

public Plugin myinfo = 
{
	name = "[T-RP] Interact Core", 
	author = PLUGIN_AUTHOR, 
	description = "Adds Player to Player interaction interface to T-RP", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart() {
	g_aInteractions = CreateArray(128, 16);
	ClearArray(g_aInteractions);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	/*
		Registers a new Interaction
		@Param1 -> char interaction[64]
		
		@return none
	*/
	CreateNative("interact_registerInteract", Native_RegisterInteract);
	
	/*
		Forward when a Client uses another Client
		
		@Param1 -> int client
		@Param2 -> int target
		
		@return -
	*/
	g_hOnPlayerInteractionStarted = CreateGlobalForward("OnPlayerInteractionStarted", ET_Ignore, Param_Cell, Param_Cell);
	
	
	/*
		Forward when a Client interacts with another Client
		
		@Param1 -> int client
		@Param2 -> int target
		@Param2 -> char interaction[64]
		
		@return -
	*/
	g_hOnPlayerInteraction = CreateGlobalForward("OnPlayerInteract", ET_Ignore, Param_Cell, Param_Cell, Param_String);
}

public int Native_RegisterInteract(Handle plugin, int numParams) {
	char tempinteraction[64];
	GetNativeString(1, tempinteraction, 64);
	if (FindStringInArray(g_aInteractions, tempinteraction) == -1)
		PushArrayString(g_aInteractions, tempinteraction);
}

public void OnClientPostAdminCheck(int client) {
	g_iPlayerPrevButtons[client] = 0;
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon, int &tickcount) {
	if (IsClientInGame(client) && IsPlayerAlive(client)) {
		if (!(g_iPlayerPrevButtons[client] & IN_USE) && iButtons & IN_USE) {
			int target;
			if ((target = GetClientAimTarget(client, false)) > -1) {
				if (isValidClient(target)) {
					if (!police_isPlayerCuffed(target)) {
						float clientPos[3];
						float targetPos[3];
						GetClientAbsOrigin(client, clientPos);
						GetClientAbsOrigin(target, targetPos);
						if (GetVectorDistance(clientPos, targetPos) <= 75.0)
							onInteract(client, target);
					}
				}
			}
		}
		g_iPlayerPrevButtons[client] = iButtons;
	}
}

public void onInteract(int client, int target) {
	Call_StartForward(g_hOnPlayerInteractionStarted);
	Call_PushCell(client);
	Call_PushCell(target);
	Call_Finish();
	
	
	
	char name[MAX_NAME_LENGTH + 8];
	GetClientName(target, name, sizeof(name));
	Menu interactMenu = CreateMenu(interactMenuHandler);
	SetMenuTitle(interactMenu, name);
	char id[64];
	IntToString(EntIndexToEntRef(target), id, sizeof(id));
	AddMenuItem(interactMenu, id, "Poke Player");
	for (int i = 0; i < GetArraySize(g_aInteractions); i++) {
		char tempI[64];
		GetArrayString(g_aInteractions, i, tempI, sizeof(tempI));
		AddMenuItem(interactMenu, id, tempI);
	}
	DisplayMenu(interactMenu, client, 30);
}


public int interactMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[64];
		int style;
		char display[64];
		GetMenuItem(menu, item, cValue, sizeof(cValue), style, display, sizeof(display));
		int target = EntRefToEntIndex(StringToInt(cValue));
		if (StrEqual(display, "Poke Player"))
			PrintToChat(target, "You've been poked by %N", client);
		
		Call_StartForward(g_hOnPlayerInteraction);
		Call_PushCell(client);
		Call_PushCell(target);
		Call_PushString(display);
		Call_Finish();
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

stock bool isValidClient(int client) {
	return (1 <= client <= MaxClients && IsClientInGame(client));
} 