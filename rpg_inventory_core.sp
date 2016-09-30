#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <multicolors>

#pragma newdecls required

#define MAX_ITEMS 756

enum Item {
	String:iTimestamp[64], 
	String:iPlayerid[20], 
	String:iPlayername[64], 
	String:iItemname[128], 
	String:iItemid[64], 
	iWeight, 
	String:iFlags[64], 
	bool:iIsActive, 
	String:iCategory[64], 
	String:iCategory2[64], 
	iRarity
}

int g_ePlayerInventory[MAXPLAYERS + 1][MAX_ITEMS][Item];

Database g_DB;
char dbconfig[] = "gsxh_multiroot";

Handle g_hOnItemUsed;

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
	Format(createTableQuery, sizeof(createTableQuery), "CREATE TABLE IF NOT EXISTS `t_rpg_items` ( \
  `Id` bigint(20) NOT NULL AUTO_INCREMENT, \
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, \
  `playerid` varchar(20) COLLATE utf8_bin NOT NULL, \
  `playername` varchar(64) COLLATE utf8_bin NOT NULL, \
  `itemname` varchar(128) COLLATE utf8_bin NOT NULL, \
  `itemid` varchar(64) COLLATE utf8_bin NOT NULL, \
  `weight` int(11) NOT NULL, \
  `flags` varchar(64) COLLATE utf8_bin NOT NULL, \
  `category` varchar(64) COLLATE utf8_bin NOT NULL, \
  `category2` varchar(64) COLLATE utf8_bin NOT NULL, \
  `rarity` int(11) NOT NULL, \
  PRIMARY KEY (`Id`) \
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin;");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createTableQuery);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	/*
		Give an Item to a Player
		
		@Param1 -> int client
		@Param2 -> char itemname[128]
		@Param3 -> int weight
		@Param4 -> char flags[64]
		@Param5 -> char category[64]
		@Param6 -> char category2[64]
		@Param7 -> int rarity
		@Param8 -> char reason[256]
		
		@return none
	*/
	CreateNative("inventory_givePlayerItem", Native_givePlayerItem);
	
	/*
		Returns if a Player has a item
	
		@Param1 -> client
		@Param2 -> char itemname[128]
		
		@return true or false
	*/
	CreateNative("inventory_hasPlayerItem", Native_hasPlayerItem);
	
	/*
		Returns the amount of items a player has
	
		@Param1 -> int client
		@Param2 -> char itemname[128]
		
		@return int amount
	*/
	CreateNative("inventory_getPlayerItemAmount", Native_getPlayerItemAmount);
	
	/*
		Removes x items from the players inventory
	
		@Param1 -> int client	
		@Param2 -> char itemname[128]
		@Param3 -> int amount
		@Param4 -> char reason[256]
		
		@return true if successfull - false if not (false still removes items!!)
	*/
	CreateNative("inventory_removePlayerItems", Native_removePlayerItems);
	
	/*
		On Item used
		@Param1 -> int client
		@Param2 -> char Itemname[128]
		@Param3 -> int weight
		@Param4 -> category[64]
		@Param5 -> category2[64]
		@Param6 -> int rarity
		@Param7 -> char timestamp[64]
	
	*/
	
	g_hOnItemUsed = CreateGlobalForward("inventory_onItemUsed", ET_Ignore, Param_Cell, Param_String, Param_Cell, Param_String, Param_String, Param_Cell, Param_String);
}

public int Native_givePlayerItem(Handle plugin, int numParams) {
	char itemname[128];
	char flags[64];
	char category[64];
	char category2[64];
	
	int client = GetNativeCell(1);
	GetNativeString(2, itemname, sizeof(itemname));
	int weight = GetNativeCell(3);
	GetNativeString(4, flags, sizeof(flags));
	GetNativeString(5, category, sizeof(category));
	GetNativeString(6, category2, sizeof(category2));
	int rarity = GetNativeCell(7);
	char reason[256];
	GetNativeString(8, reason, sizeof(reason));
	
	givePlayerItem(client, itemname, weight, flags, category, category2, rarity, reason);
}

public int Native_hasPlayerItem(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	char itemname[128];
	GetNativeString(2, itemname, sizeof(itemname));
	return hasPlayerItem(client, itemname);
}

public int Native_getPlayerItemAmount(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	char itemname[128];
	GetNativeString(2, itemname, sizeof(itemname));
	return getItemOwnedAmount(client, itemname);
}

public int Native_removePlayerItems(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	char itemname[128];
	GetNativeString(2, itemname, sizeof(itemname));
	int amount = GetNativeCell(3);
	char reason[256];
	GetNativeString(4, reason, sizeof(reason));
	return takePlayerItem(client, itemname, amount, reason);
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
	strcopy(g_ePlayerInventory[client][slot][iCategory], 64, "");
	strcopy(g_ePlayerInventory[client][slot][iCategory2], 64, "");
	g_ePlayerInventory[client][slot][iRarity] = -1;
	g_ePlayerInventory[client][slot][iWeight] = -1;
	g_ePlayerInventory[client][slot][iIsActive] = false;
}

public void loadClientInventory(int client) {
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char loadClientInventoryQuery[1024];
	Format(loadClientInventoryQuery, sizeof(loadClientInventoryQuery), "SELECT timestamp,playerid,playername,itemname,itemid,weight,flags,category,category2,rarity FROM t_rpg_items WHERE playerid = '%s';", playerid);
	SQL_TQuery(g_DB, SQLLoadClientInventoryQuery, loadClientInventoryQuery, client);
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
		char category[64];
		char category2[64];
		int rarity;
		SQL_FetchStringByName(hndl, "timestamp", timestamp, sizeof(timestamp));
		SQL_FetchStringByName(hndl, "playerid", playerid, sizeof(playerid));
		SQL_FetchStringByName(hndl, "playername", playername, sizeof(playername));
		SQL_FetchStringByName(hndl, "itemname", itemname, sizeof(itemname));
		SQL_FetchStringByName(hndl, "itemid", itemid, sizeof(itemid));
		weight = SQL_FetchIntByName(hndl, "weight");
		SQL_FetchStringByName(hndl, "flags", flags, sizeof(flags));
		SQL_FetchStringByName(hndl, "category", category, sizeof(category));
		SQL_FetchStringByName(hndl, "category2", category2, sizeof(category2));
		rarity = SQL_FetchIntByName(hndl, "rarity");
		addItemToLocalInventory(data, timestamp, playerid, playername, itemname, itemid, weight, flags, category, category2, rarity);
	}
}

public void givePlayerItem(int client, char itemname[128], int weight, char flags[64], char category[64], char category2[64], int rarity, char reason[256]) {
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
	Format(addItemQuery, sizeof(addItemQuery), "INSERT INTO `t_rpg_items` (`Id`, `timestamp`, `playerid`, `playername`, `itemname`, `itemid`, `weight`, `flags`, `category`, `category2`, `rarity`) VALUES (NULL, CURRENT_TIMESTAMP, '%s', '%s', '%s', '%s', '%i', '%s', '%s', '%s', '%i');", playerid, clean_playername, itemname, itemid, weight, flags, category, category2, rarity);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, addItemQuery);
	char strict_playername[64];
	strcopy(strict_playername, sizeof(strict_playername), playername);
	addItemToLocalInventory(client, timeKey, playerid, strict_playername, itemname, itemid, weight, flags, category, category2, rarity);
	CPrintToChat(client, "{lightgreen}You have recieved: {grey2}%s {blue}({grey2}%s{blue})", itemname, reason);
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

public bool takePlayerItem(int client, char itemname[128], int amount, char reason[256]) {
	if (amount > getItemOwnedAmount(client, itemname))
		return false;
	
	CPrintToChat(client, "{darkred}Removed {olive}%ix{darkred} {olive}%s{darkred} from your Inventory {purple}({darkred}%s{purple})", amount, itemname, reason);
	
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char removeItemQuery[1024];
	Format(removeItemQuery, sizeof(removeItemQuery), "DELETE FROM t_rpg_items WHERE playerid = '%s' AND itemname = '%s' LIMIT %i;", playerid, itemname, amount);
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

public void addItemToLocalInventory(int client, char timestamp[64], char playerid[20], char playername[64], char itemname[128], char itemid[64], int weight, char flags[64], char category[64], char category2[64], int rarity) {
	int slot;
	if ((slot = findFirstEmptySlotInInventory(client)) == -1)
		return;
	strcopy(g_ePlayerInventory[client][slot][iTimestamp], 64, timestamp);
	strcopy(g_ePlayerInventory[client][slot][iPlayerid], 20, playerid);
	strcopy(g_ePlayerInventory[client][slot][iPlayername], 64, playername);
	strcopy(g_ePlayerInventory[client][slot][iItemname], 128, itemname);
	strcopy(g_ePlayerInventory[client][slot][iItemid], 64, itemid);
	strcopy(g_ePlayerInventory[client][slot][iFlags], 64, flags);
	strcopy(g_ePlayerInventory[client][slot][iCategory], 64, category);
	strcopy(g_ePlayerInventory[client][slot][iCategory2], 64, category2);
	g_ePlayerInventory[client][slot][iRarity] = rarity;
	g_ePlayerInventory[client][slot][iWeight] = weight;
	g_ePlayerInventory[client][slot][iIsActive] = true;
}

public int findFirstEmptySlotInInventory(int client) {
	for (int i = 0; i < MAX_ITEMS; i++) {
		if (!g_ePlayerInventory[client][i][iIsActive])
			return i;
	}
	return -1;
}

public Action cmdOpenInventory(int client, const char[] command, int argc)
{
	Handle menu = CreateMenu(inventoryMenuHandler);
	SetMenuTitle(menu, "Your Inventory");
	for (int i = 0; i < MAX_ITEMS; i++) {
		if (g_ePlayerInventory[client][i][iIsActive]) {
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
		
		//PrintToChat(client, "Selected: %s | flags: %s", g_ePlayerInventory[client][id][iItemname], g_ePlayerInventory[client][id][iFlags]);
		
		Call_StartForward(g_hOnItemUsed);
		Call_PushCell(client);
		Call_PushString(g_ePlayerInventory[client][id][iItemname]);
		Call_PushCell(g_ePlayerInventory[client][id][iWeight]);
		Call_PushString(g_ePlayerInventory[client][id][iCategory]);
		Call_PushString(g_ePlayerInventory[client][id][iCategory2]);
		Call_PushCell(g_ePlayerInventory[client][id][iRarity]);
		Call_PushString(g_ePlayerInventory[client][id][iTimestamp]);
		Call_Finish();
	}
}

public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, any data) {
	if (!StrEqual(error, ""))
		LogError(error);
}
