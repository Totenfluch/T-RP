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
#include <rpg_furniture>
#include <rpg_jobs_core>

#pragma newdecls required

bool g_bIsHealing[MAXPLAYERS + 1];
int g_iLastBedUsed[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[T-RP] Furniture: Bed", 
	author = PLUGIN_AUTHOR, 
	description = "Adds an interaction for the Furniture Bed", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart() {  }

public void OnClientPostAdminCheck(int client) {
	g_bIsHealing[client] = false;
	g_iLastBedUsed[client] = -1;
}


public void furniture_OnFurnitureInteract(int entity, int client, char name[64], char lfBuf[64], char flags[8], char ownerId[20], int durability) {
	if (!StrEqual(name, "Double Bed") && !StrEqual(name, "Classic Bed"))
		return;
	
	g_bIsHealing[client] = true;
	jobs_startProgressBar(client, 200, "Resting (to 60hp)");
}

public void OnMapStart() {
	CreateTimer(2.0, refreshTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action refreshTimer(Handle Timer) {
	for (int i = 1; i < MAXPLAYERS; i++) {
		if (!isValidClient(i))
			continue;
		if (!g_bIsHealing[i])
			continue;
		int health;
		if ((health = GetClientHealth(i)) >= 60)
			continue;
		SetEntityHealth(i, health + 1);
	}
}

public void jobs_OnProgressBarInterrupted(int client, char info[64]) {
	g_bIsHealing[client] = false;
}

public void jobs_OnProgressBarFinished(int client, char info[64]) {
	g_bIsHealing[client] = false;
}

stock bool isValidClient(int client) {
	return (1 <= client <= MaxClients && IsClientInGame(client));
}
