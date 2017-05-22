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
#define PLUGIN_VERSION "1.1"

#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <rpg_inventory_core>
#include <rpg_jobs_core>
#include <tCrime>
#include <map_workshop_functions>
#include <tStocks>

#pragma newdecls required

#define DESPAWN_TIME 48
#define MAX_SAFEPOINTS 10

enum safeState {
	ssRef, 
	ssSpawnPoint, 
	bool:ssOpened, 
	bool:ssActive, 
	ssTimeToDespawn, 
	ssMoneyRef[5], 
	ssLootSate
}

int g_iTheSafe[safeState];


int g_iPlayerPrevButtons[MAXPLAYERS + 1];
int g_iLastInteractedWith[MAXPLAYERS + 1];

enum Safe {
	Float:gXPos, 
	Float:gYPos, 
	Float:gZPos, 
	Float:gAngle, 
	bool:gIsActive
}

int g_eSafeSpawnPoints[MAX_SAFEPOINTS][Safe];
int g_iLoadedSafe = 0;

public Plugin myinfo = 
{
	name = "[T-RP] Bank Event", 
	author = PLUGIN_AUTHOR, 
	description = "Adds a Bank Event to T-RP", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart()
{
	HookEvent("round_start", onRoundStart);
	RegConsoleCmd("sm_spos", cmdSPos);
}

public Action cmdSPos(int client, int args) {
	float pos[3];
	float angles[3];
	GetClientAbsOrigin(client, pos);
	GetClientAbsAngles(client, angles);
	PrintToChat(client, "%.2f;%.2f;%.2f;%.2f;", pos[0], pos[1], pos[2], angles[1]);
	return Plugin_Handled;
}

public void hardResetSafe() {
	g_iTheSafe[ssRef] = -1;
	g_iTheSafe[ssActive] = false;
	g_iTheSafe[ssOpened] = false;
	g_iTheSafe[ssTimeToDespawn] = -1;
	g_iTheSafe[ssLootSate] = 4;
	for (int i = 0; i < 5; i++)
	g_iTheSafe[ssMoneyRef][i] = -1;
}

public void onRoundStart(Handle event, const char[] name, bool dontBroadcast) {
	hardResetSafe();
	prepareSafeSpawn();
}

public void prepareSafeSpawn() {
	if (g_iLoadedSafe == 0)
		return;
	int point = GetRandomInt(0, g_iLoadedSafe - 1);
	float pos[3];
	pos[0] = g_eSafeSpawnPoints[point][gXPos];
	pos[1] = g_eSafeSpawnPoints[point][gYPos];
	pos[2] = g_eSafeSpawnPoints[point][gZPos];
	
	float angles[3];
	angles[0] = 0.0;
	angles[1] = g_eSafeSpawnPoints[point][gAngle];
	angles[2] = 0.0;
	
	g_iTheSafe[ssSpawnPoint] = point;
	spawnSafe(pos, angles);
}

public void OnMapStart() {
	CreateTimer(10.0, refreshTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	loadSafeSpawnPoints();
}

public Action refreshTimer(Handle Timer) {
	if (g_iTheSafe[ssOpened] && g_iTheSafe[ssActive])
		if (--g_iTheSafe[ssTimeToDespawn] <= 0)
		despawnSafe();
}

public void spawnSafe(float pos[3], float angles[3]) {
	int safeEnt = CreateEntityByName("prop_dynamic_override");
	if (safeEnt == -1)
		return;
	char modelPath[128];
	Format(modelPath, sizeof(modelPath), "models/custom_prop/safe/safe.mdl");
	PrecacheModel("models/custom_prop/safe/safe.mdl", true);
	SetEntityModel(safeEnt, modelPath);
	DispatchKeyValue(safeEnt, "Solid", "6");
	SetEntProp(safeEnt, Prop_Send, "m_nSolidType", 6);
	SetEntProp(safeEnt, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_NONE);
	
	TeleportEntity(safeEnt, pos, angles, NULL_VECTOR);
	
	Entity_SetGlobalName(safeEnt, "Bank Safe");
	
	SetVariantString("idle");
	AcceptEntityInput(safeEnt, "SetAnimation");
	
	g_iTheSafe[ssRef] = EntIndexToEntRef(safeEnt);
	g_iTheSafe[ssActive] = true;
	g_iTheSafe[ssOpened] = false;
	g_iTheSafe[ssLootSate] = 4;
}

public void spawnMoney(int index) {
	int moneyEnt = CreateEntityByName("prop_dynamic_override");
	if (moneyEnt == -1)
		return;
	char modelPath[128];
	Format(modelPath, sizeof(modelPath), "models/props/cs_assault/money.mdl");
	PrecacheModel("models/props/cs_assault/money.mdl", true);
	SetEntityModel(moneyEnt, modelPath);
	DispatchKeyValue(moneyEnt, "Solid", "6");
	SetEntProp(moneyEnt, Prop_Send, "m_nSolidType", 6);
	
	
	float pos[3];
	float off1;
	float off2;
	if (index == 0) {
		off1 = 0.0;
		off2 = 0.0;
	} else if (index == 1) {
		off1 = 0.0;
		off2 = 4.0;
	} else if (index == 2) {
		off1 = 1.0;
		off2 = 0.0;
	} else if (index == 3) {
		off1 = 1.0;
		off2 = 4.0;
	} else if (index == 4) {
		off1 = 2.0;
		off2 = 4.0;
	}
	
	pos[0] = g_eSafeSpawnPoints[g_iTheSafe[ssSpawnPoint]][gXPos];
	pos[1] = g_eSafeSpawnPoints[g_iTheSafe[ssSpawnPoint]][gYPos];
	pos[2] = g_eSafeSpawnPoints[g_iTheSafe[ssSpawnPoint]][gZPos];
	pos[2] += (21 + off1);
	pos[1] -= off2;
	
	float angles[3];
	angles[0] = 0.0;
	angles[1] = g_eSafeSpawnPoints[g_iTheSafe[ssSpawnPoint]][gAngle];
	angles[2] = 0.0;
	
	TeleportEntity(moneyEnt, pos, angles, NULL_VECTOR);
	
	g_iTheSafe[ssMoneyRef][index] = EntIndexToEntRef(moneyEnt);
	
	Entity_SetGlobalName(moneyEnt, "Safe Money");
}

public void despawnSafe() {
	g_iTheSafe[ssActive] = false;
	if (IsValidEntity(EntRefToEntIndex(g_iTheSafe[ssRef])))
		AcceptEntityInput(EntRefToEntIndex(g_iTheSafe[ssRef]), "kill");
	for (int i = 0; i < 5; i++)
	if (IsValidEntity(EntRefToEntIndex(g_iTheSafe[ssMoneyRef][i])))
		AcceptEntityInput(EntRefToEntIndex(g_iTheSafe[ssMoneyRef][i]), "kill");
	hardResetSafe();
	prepareSafeSpawn();
}

public void openSafe() {
	SetVariantString("open");
	AcceptEntityInput(EntRefToEntIndex(g_iTheSafe[ssRef]), "SetAnimation");
	CreateTimer(1.0, keepOpenTimer);
	g_iTheSafe[ssOpened] = true;
	g_iTheSafe[ssTimeToDespawn] = DESPAWN_TIME;
	for (int i = 0; i < 5; i++)
	spawnMoney(i);
}

public Action keepOpenTimer(Handle Timer) {
	SetVariantString("open-idle");
	AcceptEntityInput(EntRefToEntIndex(g_iTheSafe[ssRef]), "SetAnimation");
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon, int &tickcount) {
	if (IsClientInGame(client) && IsPlayerAlive(client)) {
		if (!(g_iPlayerPrevButtons[client] & IN_USE) && iButtons & IN_USE) {
			int ent = GetClientAimTarget(client, false);
			if (!IsValidEntity(ent)) {
				g_iPlayerPrevButtons[client] = iButtons;
				return;
			}
			if (HasEntProp(ent, Prop_Data, "m_iName") && HasEntProp(ent, Prop_Data, "m_iGlobalname")) {
				char entName[256];
				Entity_GetGlobalName(ent, entName, sizeof(entName));
				if (StrEqual(entName, "Bank Safe") && !g_iTheSafe[ssOpened]) {
					float pos[3];
					GetEntPropVector(ent, Prop_Data, "m_vecOrigin", pos);
					float ppos[3];
					GetClientAbsOrigin(client, ppos);
					if (GetVectorDistance(ppos, pos) < 100.0) {
						if (inventory_hasPlayerItem(client, "Lockpick")) {
							if (getPoliceCount() != 0) {
								jobs_startProgressBar(client, 150, "Lockpick Safe");
								g_iLastInteractedWith[client] = ent;
							} else {
								PrintToChat(client, "[-T-] There needs to be atleast one Police officer for you to do that");
							}
						}
					} else {
						PrintToChat(client, "This Safe is too far away (%.2f/100.0)", GetVectorDistance(ppos, pos));
						g_iPlayerPrevButtons[client] = iButtons;
						return;
					}
					
				} else if (StrEqual(entName, "Bank Safe") && g_iTheSafe[ssOpened]) {
					lootSafe(client);
				}
			}
		}
		g_iPlayerPrevButtons[client] = iButtons;
	}
}

public void lootSafe(int client) {
	if (g_iTheSafe[ssLootSate] >= 0) {
		if (IsValidEntity(EntRefToEntIndex(g_iTheSafe[ssMoneyRef][g_iTheSafe[ssLootSate]])))
			AcceptEntityInput(EntRefToEntIndex(g_iTheSafe[ssMoneyRef][g_iTheSafe[ssLootSate]]), "kill");
		inventory_givePlayerItem(client, "Stolen Money", 2500, "", "Criminal", "Stolen", 3, "Stolen from Safe");
		tCrime_addCrime(client, 100);
		g_iTheSafe[ssLootSate]--;
	}
}

public void jobs_OnProgressBarInterrupted(int client, char info[64]) {
	g_iLastInteractedWith[client] = -1;
}

public void jobs_OnProgressBarFinished(int client, char info[64]) {
	if (StrEqual(info, "Lockpick Safe")) {
		if (GetRandomInt(0, 6) == 1) {
			openSafe();
			PrintToChat(client, "lockpicked Safe");
			tCrime_addCrime(client, 500);
		} else {
			PrintToChat(client, "lockpicking failed");
			tCrime_addCrime(client, 100);
		}
		if (GetRandomInt(0, 2) == 1) {
			inventory_removePlayerItems(client, "Lockpick", 1, "Lockpick broke");
			tCrime_addCrime(client, 75);
		}
	}
}

public void loadSafeSpawnPoints()
{
	g_iLoadedSafe = 0;
	char sRawMap[PLATFORM_MAX_PATH];
	char sMap[64];
	GetCurrentMap(sRawMap, sizeof(sRawMap));
	RemoveMapPath(sRawMap, sMap, sizeof(sMap));
	
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/rpg_Safe/%s.txt", sMap);
	
	Handle hFile = OpenFile(sPath, "r");
	
	char sBuffer[512];
	char sDatas[4][32];
	
	if (hFile != INVALID_HANDLE)
	{
		while (ReadFileLine(hFile, sBuffer, sizeof(sBuffer)))
		{
			ExplodeString(sBuffer, ";", sDatas, 4, 32);
			
			g_eSafeSpawnPoints[g_iLoadedSafe][gXPos] = StringToFloat(sDatas[0]);
			g_eSafeSpawnPoints[g_iLoadedSafe][gYPos] = StringToFloat(sDatas[1]);
			g_eSafeSpawnPoints[g_iLoadedSafe][gZPos] = StringToFloat(sDatas[2]);
			g_eSafeSpawnPoints[g_iLoadedSafe][gAngle] = StringToFloat(sDatas[3]);
			
			g_iLoadedSafe++;
		}
		
		CloseHandle(hFile);
	}
	PrintToServer("Loaded %i Safe Spawn Points", g_iLoadedSafe);
}

public int getPoliceCount() {
	int count = 0;
	for (int i = 1; i < MAXPLAYERS; i++)
	if (isValidClient(i))
		if (jobs_isActiveJob(i, "Police"))
		count++;
	return count;
} 