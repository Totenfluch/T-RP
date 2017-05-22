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
#include <cstrike>
#include <map_workshop_functions>
#include <rpg_jobs_core>
#include <rpg_npc_core>
#include <rpg_inventory_core>
#include <smlib>
#include <tConomy>

#pragma newdecls required

#define MAX_GARBAGE 1024

enum garbage {
	Float:gXPos, 
	Float:gYPos, 
	Float:gZPos, 
	bool:gIsActive
}

int g_eGarbageSpawnPoints[MAX_GARBAGE][garbage];
int g_iLoadedGarbage = 0;
int g_iActiveGarbage = 0;

int g_iBlueGlow;

int g_iBaseGarbageSpawns = 10;
int g_iMaxGarbageSpawns = 20;

ArrayList randomNumbers;

int g_iPlayerPrevButtons[MAXPLAYERS + 1];

char g_cTrash[3][64];

public Plugin myinfo = 
{
	name = "[T-RP] Job: Garbage Collector", 
	author = PLUGIN_AUTHOR, 
	description = "Add the Garbage collector to the T-RP", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart() {
	RegAdminCmd("sm_garbagespawns", addSpawnPoints, ADMFLAG_ROOT, "Opens the Menu to add Garbage spawnpoints");
	HookEvent("round_start", onRoundStart);
	
	jobs_registerJob("Garbage Collector", "Collect Garbage and put it in the Trash Cans", 20, 300, 2.068);
	npc_registerNpcType("Garbagerman Recruiter");
	resetAmountVars();
}

public void OnMapStart() {
	resetAmountVars();
	PrecacheModel("models/props_junk/trashcluster01a_corner.mdl", true);
	PrecacheModel("models/props/de_train/hr_t/trash_c/hr_clothes_pile.mdl", true);
	PrecacheModel("models/props/de_train/hr_t/trash_b/hr_food_pile_02.mdl", true);
	
	strcopy(g_cTrash[0], 64, "models/props_junk/trashcluster01a_corner.mdl");
	strcopy(g_cTrash[1], 64, "models/props/de_train/hr_t/trash_c/hr_clothes_pile.mdl");
	strcopy(g_cTrash[2], 64, "models/props/de_train/hr_t/trash_b/hr_food_pile_02.mdl");
	
	CreateTimer(1.0, refreshTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	for (int i = 0; i < MAX_GARBAGE; i++) {
		g_eGarbageSpawnPoints[g_iLoadedGarbage][gXPos] = -1.0;
		g_eGarbageSpawnPoints[g_iLoadedGarbage][gYPos] = -1.0;
		g_eGarbageSpawnPoints[g_iLoadedGarbage][gZPos] = -1.0;
		g_eGarbageSpawnPoints[g_iLoadedGarbage][gIsActive] = false;
	}
	g_iLoadedGarbage = 0;
	g_iBlueGlow = PrecacheModel("sprites/blueglow1.vmt");
	loadGarbageSpawnPoints();
}

public void onRoundStart(Handle event, const char[] name, bool dontBroadcast) {
	for (int i = 0; i < MAX_GARBAGE; i++) {
		g_eGarbageSpawnPoints[i][gIsActive] = false;
	}
	
	randomNumbers = CreateArray(g_iBaseGarbageSpawns, g_iBaseGarbageSpawns);
	ClearArray(randomNumbers);
	for (int i = 0; i < g_iLoadedGarbage; i++) {
		PushArrayCell(randomNumbers, i);
	}
	
	for (int i = 0; i < MAX_GARBAGE; i++) {
		int index1 = GetRandomInt(0, (g_iLoadedGarbage - 1));
		int index2 = GetRandomInt(0, (g_iLoadedGarbage - 1));
		if (GetArraySize(randomNumbers) > 0)
			SwapArrayItems(randomNumbers, index1, index2);
	}
	
	int spawns = 0;
	if (g_iBaseGarbageSpawns > g_iLoadedGarbage)
		spawns = g_iLoadedGarbage;
	else
		spawns = g_iBaseGarbageSpawns;
	for (int i = 0; i < spawns; i++) {
		int spawnId = GetArrayCell(randomNumbers, 0);
		RemoveFromArray(randomNumbers, 0);
		spawnGarbage(spawnId);
	}
}

public void spawnGarbage(int id) {
	int trashEnt = CreateEntityByName("prop_dynamic_override");
	if (trashEnt == -1)
		return;
	char modelPath[128];
	Format(modelPath, sizeof(modelPath), g_cTrash[GetRandomInt(0, 2)]);
	SetEntityModel(trashEnt, modelPath);
	DispatchKeyValue(trashEnt, "Solid", "2");
	SetEntProp(trashEnt, Prop_Send, "m_nSolidType", 2);
	SetEntProp(trashEnt, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_NONE);
	char cId[8];
	IntToString(id, cId, sizeof(cId));
	SetEntPropString(trashEnt, Prop_Data, "m_iName", cId);
	DispatchSpawn(trashEnt);
	float pos[3];
	pos[0] = g_eGarbageSpawnPoints[id][gXPos];
	pos[1] = g_eGarbageSpawnPoints[id][gYPos];
	pos[2] = g_eGarbageSpawnPoints[id][gZPos];
	TeleportEntity(trashEnt, pos, NULL_VECTOR, NULL_VECTOR);
	Entity_SetGlobalName(trashEnt, "Garbage");
	
	g_eGarbageSpawnPoints[id][gIsActive] = true;
	g_iActiveGarbage++;
}

public Action refreshTimer(Handle Timer) {
	if (randomNumbers == INVALID_HANDLE)
		return;
	int active = getActiveGarbage();
	if (active == g_iLoadedGarbage)
		return;
	if (active >= g_iMaxGarbageSpawns)
		return;
	if (active < g_iBaseGarbageSpawns) {
		if (GetArraySize(randomNumbers) > 0) {
			int spawnId = GetArrayCell(randomNumbers, 0);
			RemoveFromArray(randomNumbers, 0);
			spawnGarbage(spawnId);
			return;
		}
	}
	if (active >= g_iBaseGarbageSpawns && active < g_iMaxGarbageSpawns) {
		if (GetArraySize(randomNumbers) > 0) {
			if (GetRandomInt(0, 20) == 7) {
				int spawnId = GetArrayCell(randomNumbers, 0);
				RemoveFromArray(randomNumbers, 0);
				spawnGarbage(spawnId);
			}
		}
	}
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon, int &tickcount) {
	if (IsClientInGame(client) && IsPlayerAlive(client)) {
		if (!(g_iPlayerPrevButtons[client] & IN_USE) && iButtons & IN_USE) {
			if (jobs_isActiveJob(client, "Garbage Collector")) {
				int ent = GetClientAimTarget(client, false);
				if (IsValidEntity(ent)) {
					if (HasEntProp(ent, Prop_Data, "m_iName") && HasEntProp(ent, Prop_Data, "m_iGlobalname")) {
						char entName[256];
						Entity_GetGlobalName(ent, entName, sizeof(entName));
						if (StrEqual(entName, "Garbage")) {
							float garbagePos[3];
							float clientPos[3];
							GetClientAbsOrigin(client, clientPos);
							GetEntPropVector(ent, Prop_Data, "m_vecOrigin", garbagePos);
							if (GetVectorDistance(clientPos, garbagePos) > 45.0) {
								g_iPlayerPrevButtons[client] = iButtons;
								return;
							}
							char cGarbageId[128];
							GetEntPropString(ent, Prop_Data, "m_iName", cGarbageId, sizeof(cGarbageId));
							int garbageId = StringToInt(cGarbageId);
							pickupGarbage(client, ent, garbageId);
						}
					}
				}
			}
		}
		g_iPlayerPrevButtons[client] = iButtons;
	}
}

public void pickupGarbage(int client, int ent, int garbageId) {
	if (IsValidEntity(ent))
		AcceptEntityInput(ent, "kill");
	PushArrayCell(randomNumbers, garbageId);
	g_eGarbageSpawnPoints[garbageId][gIsActive] = false;
	inventory_givePlayerItem(client, "Garbage", 10, "", "Junk", "Garbage Collector", 1, "Collected");
	g_iActiveGarbage--;
}



public void loadGarbageSpawnPoints()
{
	char sRawMap[PLATFORM_MAX_PATH];
	char sMap[64];
	GetCurrentMap(sRawMap, sizeof(sRawMap));
	RemoveMapPath(sRawMap, sMap, sizeof(sMap));
	
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/rpg_garbage/%s.txt", sMap);
	
	Handle hFile = OpenFile(sPath, "r");
	
	char sBuffer[512];
	char sDatas[3][32];
	
	if (hFile != INVALID_HANDLE)
	{
		while (ReadFileLine(hFile, sBuffer, sizeof(sBuffer)))
		{
			ExplodeString(sBuffer, ";", sDatas, 3, 32);
			
			g_eGarbageSpawnPoints[g_iLoadedGarbage][gXPos] = StringToFloat(sDatas[0]);
			g_eGarbageSpawnPoints[g_iLoadedGarbage][gYPos] = StringToFloat(sDatas[1]);
			g_eGarbageSpawnPoints[g_iLoadedGarbage][gZPos] = StringToFloat(sDatas[2]);
			
			g_iLoadedGarbage++;
		}
		
		CloseHandle(hFile);
	}
	PrintToServer("Loaded %i Garbage Spawn Points", g_iLoadedGarbage);
}

public void saveGarbageSpawnPoints()
{
	char sRawMap[PLATFORM_MAX_PATH];
	char sMap[64];
	GetCurrentMap(sRawMap, sizeof(sRawMap));
	RemoveMapPath(sRawMap, sMap, sizeof(sMap));
	
	CreateDirectory("configs/rpg_garbage", 511);
	
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/rpg_garbage/%s.txt", sMap);
	
	
	
	Handle hFile = OpenFile(sPath, "w");
	
	if (hFile != INVALID_HANDLE)
	{
		for (int i = 0; i < g_iLoadedGarbage; i++) {
			WriteFileLine(hFile, "%.2f;%.2f;%.2f;", g_eGarbageSpawnPoints[i][gXPos], g_eGarbageSpawnPoints[i][gYPos], g_eGarbageSpawnPoints[i][gZPos]);
		}
		
		CloseHandle(hFile);
	}
	
	if (!FileExists(sPath))
		LogError("Couldn't save item spawns to  file: \"%s\".", sPath);
}

public void AddLootSpawn(int client)
{
	float pos[3];
	GetClientAbsOrigin(client, pos);
	
	TE_SetupGlowSprite(pos, g_iBlueGlow, 10.0, 1.0, 235);
	TE_SendToAll();
	
	g_eGarbageSpawnPoints[g_iLoadedGarbage][gXPos] = pos[0];
	g_eGarbageSpawnPoints[g_iLoadedGarbage][gYPos] = pos[1];
	g_eGarbageSpawnPoints[g_iLoadedGarbage][gZPos] = pos[2];
	g_iLoadedGarbage++;
	
	PrintToChat(client, "Added new loot spawn at %.2f:%.2f:%.2f, for type: rpg_garbage", pos[0], pos[1], pos[2]);
	saveGarbageSpawnPoints();
}


public Action addSpawnPoints(int client, int args) {
	addSpawnPointsMenu(client, args);
	return Plugin_Handled;
}

public Action addSpawnPointsMenu(int client, int args)
{
	char garbageText[64];
	
	Format(garbageText, sizeof(garbageText), "Spawn: Garbage (%i)", g_iLoadedGarbage);
	
	Handle panel = CreatePanel();
	SetPanelTitle(panel, "Add a Spawnpoint");
	DrawPanelText(panel, "x-x-x-x-x-x-x-x-x-x");
	DrawPanelItem(panel, garbageText);
	DrawPanelText(panel, "-------------");
	DrawPanelItem(panel, "Show Spawns");
	DrawPanelItem(panel, "Close");
	DrawPanelText(panel, "x-x-x-x-x-x-x-x-x-x");
	
	
	SendPanelToClient(panel, client, addSpawnPointsMenuHandler, 30);
	
	CloseHandle(panel);
	return Plugin_Handled;
}

public int addSpawnPointsMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		if (item == 1) {
			AddLootSpawn(client);
			addSpawnPointsMenu(client, 0);
		} else if (item == 2) {
			ShowSpawns();
			addSpawnPointsMenu(client, 0);
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void ShowSpawns() {
	for (int i = 0; i < g_iLoadedGarbage; i++) {
		float pos[3];
		pos[0] = g_eGarbageSpawnPoints[i][gXPos];
		pos[1] = g_eGarbageSpawnPoints[i][gYPos];
		pos[2] = g_eGarbageSpawnPoints[i][gZPos];
		TE_SetupGlowSprite(pos, g_iBlueGlow, 10.0, 1.0, 235);
		TE_SendToAll();
	}
}

public int getActiveGarbage() {
	int count = 0;
	for (int i = 0; i < g_iLoadedGarbage; i++) {
		if (g_eGarbageSpawnPoints[i][gIsActive])
			count++;
	}
	return count;
}

public void OnNpcInteract(int client, char npcType[64], char UniqueId[128], int entIndex) {
	if (!StrEqual(npcType, "Garbagerman Recruiter"))
		return;
	char activeJob[128];
	jobs_getActiveJob(client, activeJob);
	Menu panel = CreateMenu(JobPanelHandler);
	if (StrEqual(activeJob, "") || !jobs_isActiveJob(client, "Garbage Collector")) {
		SetMenuTitle(panel, "You already have a job! Want to quit it and becoma a Garbage Collector?");
		AddMenuItem(panel, "x", "No");
		AddMenuItem(panel, "x", "Not now.");
		AddMenuItem(panel, "givejob", "Yes");
	} else if (jobs_isActiveJob(client, "Garbage Collector")) {
		SetMenuTitle(panel, "Welcome Garbageman!");
		if (inventory_hasPlayerItem(client, "Garbage"))
			AddMenuItem(panel, "recycle", "Hand in Garbage");
		else
			AddMenuItem(panel, "x", "Hand in Garbage", ITEMDRAW_DISABLED);
		
		if (inventory_hasPlayerItem(client, "Garbage")) {
			char sellAll[256];
			int itemamount = inventory_getPlayerItemAmount(client, "Garbage");
			Format(sellAll, sizeof(sellAll), "Recycle %i Garbage", itemamount);
			AddMenuItem(panel, "recycleAll", sellAll);
		}
		
		AddMenuItem(panel, "skin1", "First Garbage Collector Skin [2](500$)", tConomy_getCurrency(client) >= 500 && jobs_getLevel(client) >= 2 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		
		if (tConomy_getCurrency(client) >= 15000 && jobs_getLevel(client) >= 20 && jobs_getActiveJob(client, "Garbage Collector"))
			AddMenuItem(panel, "skin", "Buy Ellis Skin (15000$)[20]");
		else
			AddMenuItem(panel, "skin", "Buy Ellis Skin (15000$)[20]", ITEMDRAW_DISABLED);
		
		
	}
	DisplayMenu(panel, client, 60);
}

public int JobPanelHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "givejob")) {
			jobs_giveJob(client, "Garbage Collector");
		} else if (StrEqual(cValue, "recycle")) {
			if (inventory_hasPlayerItem(client, "Garbage")) {
				tConomy_addCurrency(client, 75, "Recycled Garbage");
				inventory_removePlayerItems(client, "Garbage", 1, "Recycled");
				jobs_addExperience(client, 40, "Garbage Collector");
			}
		} else if (StrEqual(cValue, "recycleAll")) {
			int itemamount = inventory_getPlayerItemAmount(client, "Garbage");
			if (inventory_removePlayerItems(client, "Garbage", itemamount, "Recycled Garbage (Mass)")) {
				tConomy_addCurrency(client, 75 * itemamount, "Recycled Garbage");
				jobs_addExperience(client, 40 * itemamount, "Garbage Collector");
			}
		} else if (StrEqual(cValue, "skin") && tConomy_getCurrency(client) >= 15000 && jobs_getLevel(client) >= 20 && jobs_isActiveJob(client, "Garbage Collector")) {
			tConomy_removeCurrency(client, 15000, "Bought Skin");
			inventory_givePlayerItem(client, "Ellis", 0, "", "Skin", "Skin", 1, "Bought from Garbage Collector");
		} else if (StrEqual(cValue, "skin1") && tConomy_getCurrency(client) >= 500 && jobs_getLevel(client) >= 2 && jobs_isActiveJob(client, "Garbage Collector")) {
			tConomy_removeCurrency(client, 500, "Bought Skin");
			inventory_givePlayerItem(client, "Dustman", 0, "", "Skin", "Skin", 1, "Bought from Garbage Collector");
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void OnClientPostAdminCheck(int client) {
	resetAmountVars();
}

public void resetAmountVars() {
	int amount;
	if ((amount = GetRealClientCount()) != 0) {
		g_iMaxGarbageSpawns = amount;
		amount /= 3;
		g_iBaseGarbageSpawns = amount <= 3 ? 3:amount;
	} else {
		g_iBaseGarbageSpawns = 1;
		g_iMaxGarbageSpawns = 5;
	}
}

public int GetRealClientCount() {
	int total = 0;
	for (int i = 1; i <= MaxClients; i++)
	if (IsClientConnected(i) && !IsFakeClient(i))
		total++;
	return total;
} 