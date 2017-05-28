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
#include <tStocks>

#pragma newdecls required

int g_iCooldown[MAXPLAYERS + 1];
#define COOLDOWN 120

public Plugin myinfo = 
{
	name = "[T-RP] Unstuck", 
	author = PLUGIN_AUTHOR, 
	description = "allows players to unstuck", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_unstuck", cmdUnstuck, "Unstucks yourself after waiting");
}

public Action cmdUnstuck(int client, int args) {
	if (isValidClient(client)) {
		if (g_iCooldown[client] == 0 && isSpaceAbove(client)) {
			jobs_startProgressBar(client, 300, "Unstuck");
		}
	} else
		PrintToChat(client, "[-T-] You have %is Cooldown left", g_iCooldown[client]);
	return Plugin_Handled;
}

public void OnClientPostAdminCheck(int client) {
	g_iCooldown[client] = COOLDOWN;
}

public void OnMapStart() {
	CreateTimer(1.0, refreshTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action refreshTimer(Handle Timer) {
	for (int i = 1; i < MAXPLAYERS; i++)
	if (g_iCooldown[i] > 0)
		g_iCooldown[i]--;
}

public void jobs_OnProgressBarFinished(int client, char info[64]) {
	if (!isValidClient(client))
		return;
	g_iCooldown[client] = COOLDOWN;
	if (StrContains(info, "Unstuck") != -1)
		unstuckClient(client);
}

public void unstuckClient(int client) {
	float pos[3];
	GetClientAbsOrigin(client, pos);
	pos[2] += 20;
	float speed[3];
	speed[0] = 0.0;
	speed[1] = 0.0;
	speed[2] = 0.0;
	TeleportEntity(client, pos, NULL_VECTOR, speed);
}

public bool isSpaceAbove(int client) {
	float playerPos[3];
	float playerAngles[3];
	GetClientEyePosition(client, playerPos);
	playerAngles[0] = -90.0;
	playerAngles[1] = 0.0;
	playerAngles[2] = 0.0;
	
	Handle trace = TR_TraceRayFilterEx(playerPos, playerAngles, MASK_VISIBLE, RayType_Infinite, TraceRayNoPlayers, client);
	
	if (TR_DidHit(trace)) {
		float hOrigin[3];
		float beam2Vector[3];
		TR_GetEndPosition(hOrigin, trace);
		MakeVectorFromPoints(playerPos, hOrigin, beam2Vector);
		CloseHandle(trace);
		
		if (GetVectorLength(beam2Vector) < 80.0) {
			return false;
		} else {
			return true;
		}
	}
	CloseHandle(trace);
	return true;
}

public bool TraceRayNoPlayers(int entity, int mask, any data) {
	if (entity == data || (entity >= 1 && entity <= MaxClients))
		return false;
	return true;
} 