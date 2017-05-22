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
#include <rpg_inventory_core>
#include <rpg_furniture>

#pragma newdecls required

int g_iLastWardrobeUsed[MAXPLAYERS + 1];
char g_cCurrentSkin[MAXPLAYERS + 1][128];

char dbconfig[] = "gsxh_multiroot";
Database g_DB;

#define MAX_SKINS 64

enum PlayerSkins {
	psId, 
	String:psName[128], 
	String:psPath[128], 
	String:psJob[64]
}

int g_iLoadedSkins;
int g_ePlayerSkins[MAX_SKINS][PlayerSkins];

public Plugin myinfo = 
{
	name = "[T-RP] Skins Core", 
	author = PLUGIN_AUTHOR, 
	description = "Adds Skins over a Wardrobe in T-RP", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart()
{
	HookEvent("player_spawn", onPlayerSpawn);
	
	char error[255];
	g_DB = SQL_Connect(dbconfig, true, error, sizeof(error));
	SQL_SetCharset(g_DB, "utf8");
	
	char createTableQuery[2048];
	Format(createTableQuery, sizeof(createTableQuery), "CREATE TABLE IF NOT EXISTS t_rpg_skins (`Id`BIGINT NOT NULL AUTO_INCREMENT, `timestamp`TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, `playerid`VARCHAR(20)NOT NULL, `skin`VARCHAR(128)CHARACTER SET utf8 COLLATE utf8_bin NOT NULL, `active`BOOLEAN NOT NULL, `flags`VARCHAR(8)NOT NULL, `map`VARCHAR(64)CHARACTER SET utf8 COLLATE utf8_bin NOT NULL, PRIMARY KEY(`Id`))ENGINE = InnoDB; ");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createTableQuery);
}

public void onPlayerSpawn(Handle event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (GetClientTeam(client) != 3 && GetClientTeam(client) != 2)
		return;
	if (!IsPlayerAlive(client))
		return;
	
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	char loadPlayerQuery2[512];
	Format(loadPlayerQuery2, sizeof(loadPlayerQuery2), "SELECT skin FROM t_rpg_skins WHERE playerid = '%s' AND map = '%s' AND active = 1;", playerid, mapName);
	SQL_TQuery(g_DB, SQLLoadSkinsQueryCallback, loadPlayerQuery2, client);
}

public void SQLLoadSkinsQueryCallback(Handle owner, Handle hndl, const char[] error, any data) {
	int client = data;
	while (SQL_FetchRow(hndl)) {
		char skin[128];
		SQL_FetchString(hndl, 0, skin, sizeof(skin));
		strcopy(g_cCurrentSkin[client], 128, skin);
		changePlayerSkin(client);
	}
}


public void OnClientPostAdminCheck(int client) {
	g_iLastWardrobeUsed[client] = -1;
	strcopy(g_cCurrentSkin[client], 128, "");
}

public void OnMapStart() {
	inventory_addItemHandle("Skin", 2);
	loadSkins();
}

public void furniture_OnFurnitureInteract(int entity, int client, char name[64], char lfBuf[64], char flags[8], char ownerId[20], int durability) {
	if (!StrEqual(name, "Wardrobe") && StrContains(lfBuf, "wardrobe", false) == -1)
		return;
	
	g_iLastWardrobeUsed[client] = entity;
	
	Menu wardrobeMenu = CreateMenu(wardrobeMenuHandler);
	SetMenuTitle(wardrobeMenu, "Wardrobe");
	AddMenuItem(wardrobeMenu, "openstash", "Stash Cloth");
	AddMenuItem(wardrobeMenu, "equip", "Change Cloth");
	DisplayMenu(wardrobeMenu, client, 60);
}

public int wardrobeMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		
		if (StrEqual(cValue, "openstash")) {
			inventory_showInventoryOfClientToOtherClientByCategory(client, client, "Skin");
		} else if (StrEqual(cValue, "equip")) {
			showWardrobeToClient(client);
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void showWardrobeToClient(int client) {
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	char selectSkinsQuery[256];
	Format(selectSkinsQuery, sizeof(selectSkinsQuery), "SELECT skin FROM t_rpg_skins WHERE playerid = '%s' AND map = '%s';", playerid, mapName);
	SQL_TQuery(g_DB, SQLSkinsQueryCallback, selectSkinsQuery, client);
}

public void SQLSkinsQueryCallback(Handle owner, Handle hndl, const char[] error, any data) {
	int client = data;
	Menu chooseSkinMenu = CreateMenu(chooseSkinMenuCallback);
	SetMenuTitle(chooseSkinMenu, "Choose a Skin");
	bool empty = true;
	while (SQL_FetchRow(hndl)) {
		char skin[128];
		SQL_FetchString(hndl, 0, skin, sizeof(skin));
		AddMenuItem(chooseSkinMenu, skin, skin);
		empty = false;
	}
	if (empty) {
		delete chooseSkinMenu;
		PrintToChat(client, "You have no other Skins");
	} else {
		DisplayMenu(chooseSkinMenu, client, 60);
	}
}

public int chooseSkinMenuCallback(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[128];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		strcopy(g_cCurrentSkin[client], 128, cValue);
		changeSkinGlobally(client);
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void changeSkinGlobally(int client) {
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	
	char updateSkins[256];
	Format(updateSkins, sizeof(updateSkins), "UPDATE t_rpg_skins SET active = 0 WHERE playerid = '%s' AND map = '%s';", playerid, mapName);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateSkins);
	
	Format(updateSkins, sizeof(updateSkins), "UPDATE t_rpg_skins SET active = 1 WHERE playerid = '%s' AND map = '%s' AND skin = '%s';", playerid, mapName, g_cCurrentSkin[client]);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateSkins);
	
	changePlayerSkin(client);
}

public void changePlayerSkin(int client) {
	int id;
	if ((id = getIdOfSkinName(g_cCurrentSkin[client])) == -1)
		return;
	SetEntityModel(client, g_ePlayerSkins[id][psPath]);
}

public void inventory_onItemUsed(int client, char itemname[128], int weight, char category[64], char category2[64], int rarity, char timestamp[64], int slot) {
	if (!(StrEqual(category, "Skin")))
		return;
	
	if (IsValidEntity(g_iLastWardrobeUsed[client])) {
		float playerPos[3];
		float entPos[3];
		GetClientAbsOrigin(client, playerPos);
		GetEntPropVector(g_iLastWardrobeUsed[client], Prop_Data, "m_vecOrigin", entPos);
		if (GetVectorDistance(playerPos, entPos) > 100.0) {
			PrintToChat(client, "Too far away from Wardrobe");
		} else {
			Menu stashCloth = CreateMenu(stashClothMenuHandler);
			SetMenuTitle(stashCloth, "Stash this Skin?");
			AddMenuItem(stashCloth, itemname, "Stash Skin");
			AddMenuItem(stashCloth, "x", "Abort");
			DisplayMenu(stashCloth, client, 60);
		}
	}
}

public int stashClothMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[128];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		
		if (!StrEqual(cValue, "x")) {
			if (inventory_removePlayerItems(client, cValue, 1, "Stashed in Wardrobe")) {
				addItemToWardrobe(client, cValue);
			}
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void addItemToWardrobe(int client, char item[128]) {
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	
	char insertWardrobeQuery[512];
	Format(insertWardrobeQuery, sizeof(insertWardrobeQuery), "INSERT IGNORE INTO `t_rpg_skins` (`Id`, `timestamp`, `playerid`, `skin`, `active`, `flags`, `map`) VALUES (NULL, CURRENT_TIMESTAMP, '%s', '%s', '0', '', '%s');", playerid, item, mapName);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, insertWardrobeQuery);
}

public void clearAllSkins() {
	g_iLoadedSkins = 0;
	for (int i = 0; i < MAX_SKINS; i++) {
		g_ePlayerSkins[i][psId] = -1;
		strcopy(g_ePlayerSkins[i][psName], 128, "");
		strcopy(g_ePlayerSkins[i][psPath], 128, "");
		strcopy(g_ePlayerSkins[i][psJob], 64, "");
	}
}

public int getIdOfSkinName(char name[128]) {
	for (int i = 0; i < g_iLoadedSkins; i++)
	if (StrEqual(g_ePlayerSkins[i][psName], name))
		return i;
	return -1;
}

public bool loadSkins() {
	clearAllSkins();
	
	KeyValues kv = new KeyValues("rpg_skins");
	kv.ImportFromFile("addons/sourcemod/configs/rpg_skins.txt");
	
	if (!kv.GotoFirstSubKey())
		return false;
	
	char buffer[128];
	do
	{
		kv.GetSectionName(buffer, sizeof(buffer));
		strcopy(g_ePlayerSkins[g_iLoadedSkins][psName], 128, buffer);
		
		char tempVars[128];
		kv.GetString("model", tempVars, 128, "models/player/tm_professional.mdl");
		strcopy(g_ePlayerSkins[g_iLoadedSkins][psPath], 128, tempVars);
		PrecacheModel(tempVars, true);
		
		kv.GetString("job", tempVars, 64, "");
		strcopy(g_ePlayerSkins[g_iLoadedSkins][psJob], 64, tempVars);
		
		g_iLoadedSkins++;
		
	} while (kv.GotoNextKey());
	
	delete kv;
	return true;
}

public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, any data) {
	if (!StrEqual(error, ""))
		LogError(error);
} 