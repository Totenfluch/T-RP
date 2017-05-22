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

#pragma newdecls required

bool g_bIsGettingHealed[MAXPLAYERS + 1];
int g_iHealTicks[MAXPLAYERS + 1];

int g_iPlayerPrevButtons[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[T-RP] Police Health Station", 
	author = PLUGIN_AUTHOR, 
	description = "Adds a Healthsation that heals Cops", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart() {  }

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon, int &tickcount) {
	if (IsClientInGame(client) && IsPlayerAlive(client)) {
		if (!(g_iPlayerPrevButtons[client] & IN_USE) && iButtons & IN_USE) {
			int targetObject = GetTargetBlock(client);
			if (IsValidEntity(targetObject)) {
				char name[255];
				GetEntPropString(targetObject, Prop_Data, "m_iName", name, sizeof(name));
				if (StrEqual(name, "ct_medicstation")) {
					if (jobs_isActiveJob(client, "Police")) {
						g_bIsGettingHealed[client] = true;
						g_iHealTicks[client] = 0;
					}
				}
			}
		}
		g_iPlayerPrevButtons[client] = iButtons;
	}
}

public void OnMapStart() {
	CreateTimer(1.0, refreshTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action refreshTimer(Handle Timer) {
	for (int i = 1; i < MAXPLAYERS; i++) {
		if (!isValidClient(i))
			continue;
		if (!g_bIsGettingHealed[i])
			continue;
		if (g_bIsGettingHealed[i] && !jobs_isActiveJob(i, "Police")) {
			g_bIsGettingHealed[i] = false;
			continue;
		}
		if (!IsPlayerAlive(i))
			continue;
		if (g_iHealTicks[i]++ > 30) {
			g_iHealTicks[i] = 0;
			g_bIsGettingHealed[i] = false;
			continue;
		}
		int hp;
		if ((hp = GetClientHealth(i)) >= 100)
			continue;
		else
			SetEntityHealth(i, hp + 1);
	}
}

stock bool isValidClient(int client) {
	return (1 <= client <= MaxClients && IsClientInGame(client));
}

stock int GetTargetBlock(int client) {
	int entity = GetClientAimTarget(client, false);
	if (IsValidEdict(entity)) {
		return entity;
	}
	return -1;
} 