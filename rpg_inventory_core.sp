#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <smlib>

#pragma newdecls required

#define MAX_ITEMS 2048

enum itemProperties {
	String:iTimestamp[64], 
	String:iPlayerid[20], 
	String:iPlayername[64], 
	String:iItemname[18], 
	String:iItemid[64], 
	iWeight, 
	String:iFlags[64], 
	bool:iIsActive
}

int g_ePlayerInventory[MAXPLAYERS + 1][MAX_ITEMS][itemProperties];

Database g_DB;
char dbconfig[] = "gsxh_multiroot";

public Plugin myinfo = 
{
	name = "Inventory for T-RP", 
	author = PLUGIN_AUTHOR, 
	description = "Adds an Item Inventory to T-RP", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart() {
	AddCommandListener(cmdOpenInventory, "+lookatweapon");
	
	char error[255];
	g_DB = SQL_Connect(dbconfig, true, error, sizeof(error));
	SQL_SetCharset(g_DB, "utf8");
	
	char createTableQuery[4096];
	Format(createTableQuery, sizeof(createTableQuery), "CREATE TABLE IF NOT EXISTS `t_rpg_items` ( `Id` BIGINT NULL AUTO_INCREMENT , `timestamp` TIMESTAMP on update CURRENT_TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , `playerid` VARCHAR(20) NOT NULL , `playername` VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL , `itemname` VARCHAR(128) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL , `itemid` VARCHAR(64) NOT NULL , `weight` INT NOT NULL , `flags` VARCHAR(64) NOT NULL , PRIMARY KEY (`Id`)) ENGINE = InnoDB CHARSET=utf8 COLLATE utf8_bin;");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createTableQuery);
}

public void OnClientAuthorized(int client) {
	loadClientInventory(client);
}

public void OnClientDisconnect(int client) {
	resetLocalInventory(client);
}

public void resetLocalInventory(int client) {
	for (int slot = 0; slot < MAX_ITEMS; slot++)
	resetLocalInventorySlot(client, slot);
	
}

public void resetLocalInventorySlot(int client, int slot) {
	strcopy(g_ePlayerInventory[client][slot][iTimestamp], 64, "");
	strcopy(g_ePlayerInventory[client][slot][iPlayerid], 20, "");
	strcopy(g_ePlayerInventory[client][slot][iPlayername], 64, "");
	strcopy(g_ePlayerInventory[client][slot][iItemname], 128, "");
	strcopy(g_ePlayerInventory[client][slot][iItemid], 64, "");
	strcopy(g_ePlayerInventory[client][slot][iFlags], 64, "");
	g_ePlayerInventory[client][slot][iWeight] = -1;
	g_ePlayerInventory[client][slot][iIsActive] = false;
}

public void loadClientInventory(int client) {
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char loadClientInventoryQuery[1024];
	Format(loadClientInventoryQuery, sizeof(loadClientInventoryQuery), "SELECT timestamp,playerid,playername,itemname,itemid,weight,flags FROM t_rpg_items WHERE playerid = '%s';", playerid);
	SQL_TQuery(g_DB, SQLLoadClientInventoryQuery, loadClientInventoryQuery);
}

public void SQLLoadClientInventoryQuery(Handle owner, Handle hndl, const char[] error, any data) {
	while (SQL_FetchRow(hndl)) {
		char timestamp[64];
		char playerid[20];
		char playername[64];
		char itemname[128];
		char itemid[64];
		int weight;
		char flags[64];
		SQL_FetchStringByName(hndl, "timestamp", timestamp, sizeof(timestamp));
		SQL_FetchStringByName(hndl, "playerid", playerid, sizeof(playerid));
		SQL_FetchStringByName(hndl, "playername", playername, sizeof(playername));
		SQL_FetchStringByName(hndl, "itemname", itemname, sizeof(itemname));
		SQL_FetchStringByName(hndl, "itemid", itemid, sizeof(itemid));
		weight = SQL_FetchIntByName(hndl, "weight");
		SQL_FetchStringByName(hndl, "flags", flags, sizeof(flags));
		addItemToLocalInventory(data, timestamp, playerid, playername, itemname, itemid, weight, flags);
	}
}

public void givePlayerItem(int client, char itemname[128], int weight, char flags[64]) {
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char playername[MAX_NAME_LENGTH + 8];
	GetClientName(client, playername, sizeof(playername));
	char clean_playername[MAX_NAME_LENGTH * 2 + 16];
	SQL_EscapeString(g_DB, playername, clean_playername, sizeof(clean_playername));
	
	char timeKey[64];
	int time = GetTime();
	IntToString(time, timeKey, sizeof(timeKey));
	
	char itemid[64];
	Format(itemid, sizeof(itemid), "%s_%s", itemname, timeKey);
	
	char addItemQuery[512];
	Format(addItemQuery, sizeof(addItemQuery), "INSERT INTO `t_rpg_items` (`Id`, `timestamp`, `playerid`, `playername`, `itemname`, `itemid`, `weight`, `flags`) VALUES (NULL, CURRENT_TIMESTAMP, '%s', '%s', '%s', '%s', '%i', '%s');", playerid, clean_playername, itemname, itemid, weight, flags);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, addItemQuery);
	char strict_playername[64];
	strcopy(strict_playername, sizeof(strict_playername), playername);
	addItemToLocalInventory(client, timeKey, playerid, strict_playername, itemname, itemid, weight, flags);
}

public int getItemOwnedAmount(int client, char itemname[128]) {
	int count = 0;
	for (int i = 0; i < MAX_ITEMS; i++) {
		if (g_ePlayerInventory[client][i][iIsActive])
			if (StrEqual(g_ePlayerInventory[client][i][iItemname], itemname))
			count++;
	}
	return count;
}

public bool hasPlayerItem(int client, char itemname[128]) {
	if (getItemOwnedAmount(client, itemname) >= 1)
		return true;
	return false;
}

public bool takePlayerItem(int client, char itemname[128], int amount) {
	if (amount > getItemOwnedAmount(client, itemname))
		return false;
	
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char removeItemQuery[1024];
	Format(removeItemQuery, sizeof(removeItemQuery), "DELETE FROM r_rpg_items WHERE playerid = '%s' AND itemname = '%s' LIMIT %i;", playerid, itemname, amount);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, removeItemQuery);
	
	return takeFromLocalInventory(client, itemname, amount);
}

public bool takeFromLocalInventory(int client, char itemname[128], int amount) {
	if (amount > getItemOwnedAmount(client, itemname))
		return false;
	int taken = 0;
	for (int i = 0; i < MAX_ITEMS; i++) {
		if (StrEqual(g_ePlayerInventory[client][i][iItemname], itemname)) {
			resetLocalInventorySlot(client, i);
			taken++;
			if (taken == amount)
				break;
		}
	}
	if (taken == amount)
		return true;
	return false;
}

public void addItemToLocalInventory(int client, char timestamp[64], char playerid[20], char playername[64], char itemname[128], char itemid[64], int weight, char flags[64]) {
	int slot;
	if ((slot = findFirstEmptySlotInInventory(client)) == -1)
		return;
	strcopy(g_ePlayerInventory[client][slot][iTimestamp], 64, timestamp);
	strcopy(g_ePlayerInventory[client][slot][iPlayerid], 20, playerid);
	strcopy(g_ePlayerInventory[client][slot][iPlayername], 64, playername);
	strcopy(g_ePlayerInventory[client][slot][iItemname], 128, itemname);
	strcopy(g_ePlayerInventory[client][slot][iItemid], 64, itemid);
	strcopy(g_ePlayerInventory[client][slot][iFlags], 64, flags);
	g_ePlayerInventory[client][slot][iWeight] = weight;
	g_ePlayerInventory[client][slot][iIsActive] = true;
}

public int findFirstEmptySlotInInventory(int client) {
	for (int i = 0; i < MAX_ITEMS; i++) {
		if (!g_ePlayerInventory[i][iIsActive])
			return i;
	}
	return -1;
}

public Action cmdOpenInventory(int client, const char[] command, int argc)
{
	Handle menu = CreateMenu(inventoryMenuHandler);
	SetMenuTitle(menu, "Your Inventory");
	for (int i = 0; i < MAX_ITEMS; i++) {
		if (g_ePlayerInventory[client][i][iIsActive]){
			char id[8];
			IntToString(i, id, sizeof(id));
			AddMenuItem(menu, id, g_ePlayerInventory[client][i][iItemname]);
		}
	}
	DisplayMenu(menu, client, 60);
	
	return Plugin_Continue;
}

public int inventoryMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char info[64];
		GetMenuItem(menu, item, info, sizeof(info));
		int id = StringToInt(info);
		
		PrintToChat(client, "Selected: %s | flags: %s", g_ePlayerInventory[client][id][iItemname], g_ePlayerInventory[client][id][iFlags]);
	}
}

public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, any data) {
	if (!StrEqual(error, ""))
		LogError(error);
}
