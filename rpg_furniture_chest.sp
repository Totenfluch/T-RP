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
#include <rpg_inventory_core>
#include <multicolors>
#include <tStocks>

#pragma newdecls required

Database g_DB;
char dbconfig[] = "gsxh_multiroot";

int g_iPlayerPrevButtons[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[T-RP] Furniture: Chest", 
	author = PLUGIN_AUTHOR, 
	description = "Adds options for the Chest in T-RP", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart() {
	char error[255];
	g_DB = SQL_Connect(dbconfig, true, error, sizeof(error));
	SQL_SetCharset(g_DB, "utf8");
}

int g_iLastInteractedWith[MAXPLAYERS + 1];
public void furniture_OnFurnitureInteract(int entity, int client, char name[64], char lfBuf[64], char flags[8], char ownerId[20], int durability) {
	if (!StrEqual(lfBuf, "container"))
		return;
	
	openChooserMenuForClient(client, entity);
}

public void openChooserMenuForClient(int client, int entity) {
	Menu chooserMenu = CreateMenu(chooserMenuHandler);
	SetMenuTitle(chooserMenu, "What do you want to do?");
	AddMenuItem(chooserMenu, "store", "Store Item");
	AddMenuItem(chooserMenu, "take", "Take Item");
	DisplayMenu(chooserMenu, client, 60);
	
	g_iLastInteractedWith[client] = entity;
}

public int chooserMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		
		if (StrEqual(cValue, "store")) {
			float playerPos[3];
			float entPos[3];
			if (!isValidClient(client))
				return;
			if (!IsValidEntity(g_iLastInteractedWith[client]))
				return;
			GetClientAbsOrigin(client, playerPos);
			GetEntPropVector(g_iLastInteractedWith[client], Prop_Data, "m_vecOrigin", entPos);
			if (GetVectorDistance(playerPos, entPos) > 100.0)
				return;
			
			//openStoreChooserForClient(client, g_iLastInteractedWith[client]);
			getItemsInChest(client, g_iLastInteractedWith[client]);
		} else if (StrEqual(cValue, "take")) {
			openChestForClient(client, g_iLastInteractedWith[client]);
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void openChestForClient(int client, int ent) {
	if (!IsValidEntity(ent))
		return;
	char uniqueId[64];
	GetEntPropString(ent, Prop_Data, "m_iName", uniqueId, sizeof(uniqueId));
	
	char selectItemsQuery[1024];
	
	char entName[256];
	GetEntPropString(ent, Prop_Data, "m_iName", entName, sizeof(entName));
	if (StrEqual(entName, "button_safes_01")) {
		char playerid[20];
		GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
		Format(selectItemsQuery, sizeof(selectItemsQuery), "SELECT itemname,itemid FROM t_rpg_items WHERE container = '%s' AND playerid = '%s';", uniqueId, playerid);
	} else
		Format(selectItemsQuery, sizeof(selectItemsQuery), "SELECT itemname,itemid FROM t_rpg_items WHERE container = '%s';", uniqueId);
	
	SQL_TQuery(g_DB, loadItemsFromChestCallback, selectItemsQuery, client);
}

public void loadItemsFromChestCallback(Handle owner, Handle hndl, const char[] error, any data) {
	int client = data;
	bool hasItems = false;
	Menu takeItemMenu = CreateMenu(takeItemMenuHandler);
	SetMenuTitle(takeItemMenu, "Take Items from Container");
	while (SQL_FetchRow(hndl)) {
		char itemid[64];
		char itemname[128];
		SQL_FetchString(hndl, 1, itemid, sizeof(itemid));
		SQL_FetchString(hndl, 0, itemname, sizeof(itemname));
		AddMenuItem(takeItemMenu, itemid, itemname);
		hasItems = true;
	}
	if (!hasItems)
		PrintToChat(client, "[-T-] There are no Items in this Container");
	DisplayMenu(takeItemMenu, client, 30);
}

public int takeItemMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		float playerPos[3];
		float entPos[3];
		if (!isValidClient(client))
			return;
		if (!IsValidEntity(g_iLastInteractedWith[client]))
			return;
		GetClientAbsOrigin(client, playerPos);
		GetEntPropVector(g_iLastInteractedWith[client], Prop_Data, "m_vecOrigin", entPos);
		if (GetVectorDistance(playerPos, entPos) > 100.0)
			return;
		
		char containerName[64];
		GetEntPropString(g_iLastInteractedWith[client], Prop_Data, "m_iName", containerName, sizeof(containerName));
		
		char itemid[64];
		int style = 0;
		char name[64];
		GetMenuItem(menu, item, itemid, sizeof(itemid), style, name, sizeof(name));
		
		CPrintToChat(client, "{lightgreen}You have recieved: {grey2}%s {blue}({grey2}%s{blue})", name, "Taken from Chest");
		inventory_transferItemFromContainer(client, containerName, itemid);
		openChestForClient(client, g_iLastInteractedWith[client]);
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void getItemsInChest(int client, int entity) {
	char containerName[64];
	GetEntPropString(entity, Prop_Data, "m_iName", containerName, sizeof(containerName));
	
	char getTheItemsInChest[1024];
	
	char entName[256];
	GetEntPropString(entity, Prop_Data, "m_iName", entName, sizeof(entName));
	if (StrEqual(entName, "button_safes_01")) {
		char playerid[20];
		GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
		Format(getTheItemsInChest, sizeof(getTheItemsInChest), "SELECT Count(*) as amount from t_rpg_items WHERE container = '%s' AND playerid = '%s';", containerName, playerid);
	} else
		Format(getTheItemsInChest, sizeof(getTheItemsInChest), "SELECT Count(*) as amount from t_rpg_items WHERE container = '%s';", containerName);
	
	SQL_TQuery(g_DB, SQLGetItemsInChestCallback, getTheItemsInChest, client);
	g_iLastInteractedWith[client] = entity;
}

public void SQLGetItemsInChestCallback(Handle owner, Handle hndl, const char[] error, any data) {
	int client = data;
	while (SQL_FetchRow(hndl)) {
		int amount = SQL_FetchInt(hndl, 0);
		int maxAmount;
		
		char entName[256];
		GetEntPropString(g_iLastInteractedWith[client], Prop_Data, "m_iName", entName, sizeof(entName));
		if (StrEqual(entName, "button_safes_01")) {
			if (isVipRank2(client))
				maxAmount = 3;
			else
				maxAmount = 1;
		} else {
			maxAmount = furniture_getDurability(g_iLastInteractedWith[client]);
		}
		
		if (amount < maxAmount)
			openStoreChooserForClient(client, g_iLastInteractedWith[client], false, amount, maxAmount);
		else
			openStoreChooserForClient(client, g_iLastInteractedWith[client], true, amount, maxAmount);
	}
}

public void openStoreChooserForClient(int client, int entity, bool full, int amount, int maxAmount) {
	Menu storeItemMenu = CreateMenu(storeItemMenuHandler);
	char menuTitle[256];
	Format(menuTitle, sizeof(menuTitle), "Store an Item (%i/%i)", amount, maxAmount);
	SetMenuTitle(storeItemMenu, menuTitle);
	bool hasItems = false;
	int maxItems = inventory_getClientItemsAmount(client);
	for (int i = 0; i <= maxItems; i++) {
		if (inventory_isValidItem(client, i)) {
			char itemName[128];
			if (inventory_getItemNameBySlotAndClient(client, i, itemName, "")) {
				char cId[8];
				IntToString(i, cId, sizeof(cId));
				AddMenuItem(storeItemMenu, cId, itemName, full ? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
				hasItems = true;
			}
		}
	}
	if (!hasItems)
		PrintToChat(client, "[-T-] There is no item that can be stored in your Inventory");
	
	DisplayMenu(storeItemMenu, client, 60);
}


public int storeItemMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		float playerPos[3];
		float entPos[3];
		if (!isValidClient(client))
			return;
		if (!IsValidEntity(g_iLastInteractedWith[client]))
			return;
		GetClientAbsOrigin(client, playerPos);
		GetEntPropVector(g_iLastInteractedWith[client], Prop_Data, "m_vecOrigin", entPos);
		if (GetVectorDistance(playerPos, entPos) > 100.0)
			return;
		
		char uniqueId[64];
		GetEntPropString(g_iLastInteractedWith[client], Prop_Data, "m_iName", uniqueId, sizeof(uniqueId));
		
		char cId[8];
		GetMenuItem(menu, item, cId, sizeof(cId));
		int theId = StringToInt(cId);
		char reason[256];
		Format(reason, sizeof(reason), "Transfered from %N to Container", client);
		if (inventory_isValidItem(client, theId)) {
			inventory_transferItemToContainer(client, theId, uniqueId);
			//openStoreChooserForClient(client, g_iLastInteractedWith[client]);
			getItemsInChest(client, g_iLastInteractedWith[client]);
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon, int &tickcount) {
	if (IsClientInGame(client) && IsPlayerAlive(client)) {
		if (!(g_iPlayerPrevButtons[client] & IN_USE) && iButtons & IN_USE) {
			int ent = getClientViewObject(client);
			if (IsValidEntity(ent)) {
				if (HasEntProp(ent, Prop_Data, "m_iName")) {
					char entName[256];
					GetEntPropString(ent, Prop_Data, "m_iName", entName, sizeof(entName));
					if (StrEqual(entName, "button_safes_01")) {
						openChooserMenuForClient(client, ent);
					}
				}
			}
		}
	}
	g_iPlayerPrevButtons[client] = iButtons;
}

public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, any data) {
	if (!StrEqual(error, ""))
		LogError(error);
} 