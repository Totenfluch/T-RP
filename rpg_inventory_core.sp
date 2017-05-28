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
#include <smlib>
#include <multicolors>
#include <rpg_licensing>
#include <sha1>
#include <tStocks>

#pragma newdecls required

#define MAX_ITEMS 550

enum Item {
	String:iTimestamp[64], 
	String:iPlayerid[20], 
	String:iPlayername[64], 
	String:iItemname[128], 
	String:iItemid[64], 
	iWeight, 
	String:iFlags[64], 
	/*
	* i -> Invisible (doesn't show in inventory)
	* n -> Doesn't use a Player inventory slot
	* u -> Unique
	* l -> locked (can't use)
	*/
	bool:iIsActive, 
	String:iCategory[64], 
	String:iCategory2[64], 
	iRarity
}

int g_ePlayerInventory[MAXPLAYERS + 1][MAX_ITEMS][Item];

Database g_DB;
char dbconfig[] = "gsxh_multiroot";

Handle g_hOnItemUsed;
ArrayList g_aHandledItems;
ArrayList g_aHandledCategories;
ArrayList g_aHandledCategories2;

public Plugin myinfo = 
{
	name = "[T-RP] Inventory Core", 
	author = PLUGIN_AUTHOR, 
	description = "Adds an Item Inventory to T-RP", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
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
  `container` varchar(64) COLLATE utf8_bin NOT NULL, \
  PRIMARY KEY (`Id`) \
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin;");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createTableQuery);
	
	Format(createTableQuery, sizeof(createTableQuery), "CREATE TABLE IF NOT EXISTS t_rpg_inventory_log ( `Id` BIGINT NOT NULL AUTO_INCREMENT , `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , `playerid` VARCHAR(20) NOT NULL , `item` VARCHAR(64) NOT NULL , `category` VARCHAR(64) NOT NULL , `category2` VARCHAR(64) NOT NULL , `reason` VARCHAR(128) NOT NULL , `type` VARCHAR(20) NOT NULL , PRIMARY KEY (`Id`)) ENGINE = InnoDB;");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createTableQuery);
	
	RegAdminCmd("sm_sinv", cmdSInvCallback, ADMFLAG_GENERIC, "Inventory by category");
	RegAdminCmd("sm_tableinv", cmdTableInvCb, ADMFLAG_GENERIC, "Lists inventory as table in console");
	
	if (g_aHandledItems == INVALID_HANDLE) {
		g_aHandledItems = CreateArray(400, 200);
		ClearArray(g_aHandledItems);
	}
	
	if (g_aHandledCategories == INVALID_HANDLE) {
		g_aHandledCategories = CreateArray(300, 100);
		ClearArray(g_aHandledCategories);
	}
	
	if (g_aHandledCategories2 == INVALID_HANDLE) {
		g_aHandledCategories2 = CreateArray(300, 100);
		ClearArray(g_aHandledCategories2);
	}
}

public bool liCheck() {
	char licenseKey[64];
	char shaKey[128];
	licensing_getChecksums(licenseKey, shaKey);
	char checksum[128];
	char tochecksum[128];
	int t = GetTime();
	int w = t / 10000 + (24 * 60 * 60) * 3;
	Format(tochecksum, sizeof(tochecksum), "|||success %i %s|||", w, licenseKey);
	SHA1String(tochecksum, checksum, true);
	return StrEqual(checksum, shaKey);
}

public void licensing_OnTokenRefreshed(char serverToken[64], char sha1Token[128]) {
	if (!licensing_isValid() || !liCheck())
		SetFailState("Invalid License");
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
		
		@return success
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
		Shows the inventory of client1 to client2
		
		@Param1 -> int client1
		@Param2 -> int client2
		
		@return -
	*/
	CreateNative("inventory_showInventoryOfClientToOtherClient", Native_showInventoryOfClientToOtherClient);
	
	/*
		Shows the inventory of client1 to client2
		
		@Param1 -> int client1
		@Param2 -> int client2
		@Param3 -> char category[64]
		
		@return -
	*/
	CreateNative("inventory_showInventoryOfClientToOtherClientByCategory", Native_showInventoryOfClientToOtherClientByCategory);
	
	/*
		Return the owned items of a client
		
		@Param1 -> int client
		
		return amount of items the client has
	*/
	CreateNative("inventory_getClientItemsAmount", Native_getClientItemsAmount);
	
	/*
		Check if the Item is valid or not
		
		@Param1 -> int client
		@Param2 -> int slot
		
		return true when it is valid false if not
	*/
	CreateNative("inventory_isValidItem", Native_isValidItem);
	
	/*
		Return the Name of an Item Slot
		
		@Param1 -> int client
		@Param2 -> int slot
		@Param3 -> ItemNameBuffer[128]
		@Param4 -> char FilterFlags[8] // leave blank to enforce flags (only usable items)
		
		Saves the ItemName in Param3
		
		return true if usable false if not
	*/
	CreateNative("inventory_getItemNameBySlotAndClient", Native_getItemNameBySlotAndClient);
	
	/*
		Return the Category of an Item Slot
		
		@Param1 -> int client
		@Param2 -> int slot
		@Param3 -> ItemNameBuffer[128]
		@Param4 -> char FilterFlags[8] // leave blank to enforce flags (only usable items)
		
		Saves the ItemName in Param3
		
		return true if usable false if not
	*/
	CreateNative("inventory_getItemCategoryBySlotAndClient", Native_getItemCategoryBySlotAndClient);
	
	/*
		Return the Weight of an Item Slot
		
		@Param1 -> int client
		@Param2 -> int slot
		
		return weight of item if exists otherwise -1
	*/
	CreateNative("inventory_getItemWeightBySlot", Native_getItemWeightBySlot);
	
	/*
		Return the Flags of an Item Slot
		
		@Param1 -> int client
		@Param2 -> int slot
		@Param3 -> char flags[8] 
		
		return - (Saves into Param3)
	*/
	CreateNative("inventory_getItemFlagsBySlot", Native_getItemFlagsBySlot);
	
	/*
		Transfer Item to Container
		
		@Param1 -> int client
		@Param2 -> int slot
		@Param3 -> char containerName[64]
		
		noreturn
	*/
	CreateNative("inventory_transferItemToContainer", Native_transferItemToContainer);
	
	/*
		Transfer Item from Container
		
		@Param1 -> int client
		@Param2 -> char containerName[64]
		@Param3 -> char uniqueId[64]
		
		@return noreturn
	*/
	CreateNative("inventory_transferItemFromContainer", Native_transferItemFromContainer);
	
	/*
		Delete Item by Slot
		
		@Param1 -> int client
		@Param2 -> int slot
		@Param3 -> char reason[256]
		
		noreturn
	*/
	CreateNative("inventory_deleteItemBySlot", Native_deleteItemBySlot);
	
	/*
		Transfer Item to other Player by Slot
		
		@Param1 -> int client
		@Param2 -> int target
		@Param3 -> int slot
		@Param4 -> char reason[256]
		
		noreturn
	*/
	CreateNative("inventory_transferItemToPlayerBySlot", Native_transferItemToPlayerBySlot);
	
	
	/*
		On Item used
		@Param1 -> int client
		@Param2 -> char Itemname[128]
		@Param3 -> int weight
		@Param4 -> category[64]
		@Param5 -> category2[64]
		@Param6 -> int rarity
		@Param7 -> char timestamp[64]
		@Param8 -> int slot
	
	*/
	g_hOnItemUsed = CreateGlobalForward("inventory_onItemUsed", ET_Ignore, Param_Cell, Param_String, Param_Cell, Param_String, Param_String, Param_Cell, Param_String, Param_Cell);
	
	
	
	/*
		Blocks the default Item handle
		@Param1-> char Itemname[128];
		@Param2-> int type = 1: Single Item, 2: Category, 3: Category2, 4:Category+Category2
	*/
	CreateNative("inventory_addItemHandle", Native_addItemHandle);
}

public Action cmdSInvCallback(int client, int args) {
	PrintToConsole(client, "Handled Items: ");
	for (int i = 0; i < GetArraySize(g_aHandledItems); i++) {
		char buff[128];
		GetArrayString(g_aHandledItems, i, buff, sizeof(buff));
		PrintToConsole(client, "Item: %s", buff);
	}
	PrintToConsole(client, "Handled Categories: ");
	for (int i = 0; i < GetArraySize(g_aHandledCategories); i++) {
		char buff[128];
		GetArrayString(g_aHandledCategories, i, buff, sizeof(buff));
		PrintToConsole(client, "Category: %s", buff);
	}
	PrintToConsole(client, "Handled Categories2: ");
	for (int i = 0; i < GetArraySize(g_aHandledCategories2); i++) {
		char buff[128];
		GetArrayString(g_aHandledCategories2, i, buff, sizeof(buff));
		PrintToConsole(client, "Category: %s", buff);
	}
	return Plugin_Handled;
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
	
	return givePlayerItem(client, itemname, weight, flags, category, category2, rarity, reason);
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

public int Native_showInventoryOfClientToOtherClient(Handle plugin, int numParams) {
	int client1 = GetNativeCell(1);
	int client2 = GetNativeCell(2);
	showInventoryOfClientToOtherClient(client1, client2);
}

public int Native_showInventoryOfClientToOtherClientByCategory(Handle plugin, int numParams) {
	int client1 = GetNativeCell(1);
	int client2 = GetNativeCell(2);
	char category[64];
	GetNativeString(3, category, sizeof(category));
	showInventoryOfClientToOtherClientByCategory(client1, client2, category);
}

public int Native_getClientItemsAmount(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	return getMaxSlot(client);
}

public int Native_isValidItem(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	int slot = GetNativeCell(2);
	return g_ePlayerInventory[client][slot][iIsActive];
}

public int Native_transferItemToContainer(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	int slot = GetNativeCell(2);
	char containerBuffer[64];
	GetNativeString(3, containerBuffer, sizeof(containerBuffer));
	transferItemToContainer(client, slot, containerBuffer);
}

public int Native_deleteItemBySlot(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	int slot = GetNativeCell(2);
	char reason[256];
	GetNativeString(3, reason, sizeof(reason));
	takePlayerItemBySlot(client, slot, reason);
}

public int Native_getItemCategoryBySlotAndClient(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	int slot = GetNativeCell(2);
	SetNativeString(3, g_ePlayerInventory[client][slot][iCategory], 128);
	char flags[8];
	GetNativeString(4, flags, sizeof(flags));
	if ((StrContains(flags, "i") == -1) && (StrContains(g_ePlayerInventory[client][slot][iFlags], "i") != -1))
		return false;
	if ((StrContains(flags, "l") == -1) && (StrContains(g_ePlayerInventory[client][slot][iFlags], "l") != -1))
		return false;
	return true;
}

public int Native_getItemFlagsBySlot(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	int slot = GetNativeCell(2);
	SetNativeString(3, g_ePlayerInventory[client][slot][iFlags], 8);
}

public int Native_getItemWeightBySlot(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	int slot = GetNativeCell(2);
	return g_ePlayerInventory[client][slot][iWeight];
}

public int Native_getItemNameBySlotAndClient(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	int slot = GetNativeCell(2);
	SetNativeString(3, g_ePlayerInventory[client][slot][iItemname], 128);
	char flags[8];
	GetNativeString(4, flags, sizeof(flags));
	if ((StrContains(flags, "i") == -1) && (StrContains(g_ePlayerInventory[client][slot][iFlags], "i") != -1))
		return false;
	if ((StrContains(flags, "l") == -1) && (StrContains(g_ePlayerInventory[client][slot][iFlags], "l") != -1))
		return false;
	return true;
}

public int Native_transferItemToPlayerBySlot(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	int target = GetNativeCell(2);
	int slot = GetNativeCell(3);
	char reason[256];
	GetNativeString(4, reason, sizeof(reason));
	transferItemBySlot(client, target, slot, reason);
}

public int Native_transferItemFromContainer(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	char containerName[64];
	GetNativeString(2, containerName, sizeof(containerName));
	char uniqueId[64];
	GetNativeString(3, uniqueId, sizeof(uniqueId));
	transferItemFromContainer(client, containerName, uniqueId);
}


public int Native_addItemHandle(Handle plugin, int numParams) {
	if (g_aHandledItems == INVALID_HANDLE) {
		g_aHandledItems = CreateArray(400, 200);
		ClearArray(g_aHandledItems);
	}
	
	if (g_aHandledCategories == INVALID_HANDLE) {
		g_aHandledCategories = CreateArray(300, 100);
		ClearArray(g_aHandledCategories);
	}
	
	if (g_aHandledCategories2 == INVALID_HANDLE) {
		g_aHandledCategories2 = CreateArray(300, 100);
		ClearArray(g_aHandledCategories2);
	}
	
	char itemName[128];
	GetNativeString(1, itemName, sizeof(itemName));
	int type = GetNativeCell(2);
	if (type == 1) {
		if (FindStringInArray(g_aHandledItems, itemName) == -1)
			PushArrayString(g_aHandledItems, itemName);
	} else if (type == 2) {
		if (FindStringInArray(g_aHandledCategories, itemName) == -1)
			PushArrayString(g_aHandledCategories, itemName);
	} else if (type == 3) {
		if (FindStringInArray(g_aHandledCategories2, itemName) == -1)
			PushArrayString(g_aHandledCategories2, itemName);
	} else if (type == 4) {
		if (FindStringInArray(g_aHandledCategories, itemName) == -1)
			PushArrayString(g_aHandledCategories, itemName);
		if (FindStringInArray(g_aHandledCategories2, itemName) == -1)
			PushArrayString(g_aHandledCategories2, itemName);
	}
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
	if (IsClientInGame(client))
		PrintToConsole(client, "cleared: %i", slot);
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
	Format(loadClientInventoryQuery, sizeof(loadClientInventoryQuery), "SELECT timestamp,playerid,playername,itemname,itemid,weight,flags,category,category2,rarity FROM t_rpg_items WHERE playerid = '%s' AND container = '';", playerid);
	SQL_TQuery(g_DB, SQLLoadClientInventoryQuery, loadClientInventoryQuery, GetClientUserId(client));
}

public void SQLLoadClientInventoryQuery(Handle owner, Handle hndl, const char[] error, int data) {
	int client = GetClientOfUserId(data);
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
		addItemToLocalInventory(client, timestamp, playerid, playername, itemname, itemid, weight, flags, category, category2, rarity);
	}
}

public bool givePlayerItem(int client, char itemname[128], int weight, char flags[64], char category[64], char category2[64], int rarity, char reason[256]) {
	if (getPlayerItems(client) >= maxPlayerItems(client)) {
		CPrintToChat(client, "[-T-]{red} Your Inventory is full. (%s)", itemname);
		return false;
	}
	if (hasPlayerItem(client, itemname) && StrContains(flags, "u") != -1) {
		CPrintToChat(client, "[-T-]{red} You can not carry more than one unique Item. (%s)", itemname);
		return false;
	}
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
	Format(itemid, sizeof(itemid), "%s_%s%s%i", itemname, timeKey, GetRandomInt(0, 1) == 0 ? "|":"-", GetRandomInt(0, 10000));
	
	char addItemQuery[512];
	Format(addItemQuery, sizeof(addItemQuery), "INSERT INTO `t_rpg_items` (`Id`, `timestamp`, `playerid`, `playername`, `itemname`, `itemid`, `weight`, `flags`, `category`, `category2`, `rarity`, `container`) VALUES (NULL, CURRENT_TIMESTAMP, '%s', '%s', '%s', '%s', '%i', '%s', '%s', '%s', '%i', '');", playerid, clean_playername, itemname, itemid, weight, flags, category, category2, rarity);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, addItemQuery);
	
	Format(addItemQuery, sizeof(addItemQuery), "INSERT INTO `t_rpg_inventory_log` (`Id`, `timestamp`, `playerid`, `item`, `category`, `category2`, `reason`, `type`) VALUES (NULL, CURRENT_TIMESTAMP, '%s', '%s', '%s', '%s', '%s', '%s');", playerid, itemname, category, category2, reason, "GIVEN");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, addItemQuery);
	
	char strict_playername[64];
	strcopy(strict_playername, sizeof(strict_playername), playername);
	CPrintToChat(client, "{lightgreen}You have recieved: {grey2}%s {blue}({grey2}%s{blue})", itemname, reason);
	return addItemToLocalInventory(client, timeKey, playerid, strict_playername, itemname, itemid, weight, flags, category, category2, rarity);
}

public int maxPlayerItems(int client) {
	if (hasPlayerItem(client, "Gigantic Backpack"))
		return 200;
	else if (hasPlayerItem(client, "Enormous Backpack"))
		return 175;
	else if (hasPlayerItem(client, "Big Backpack"))
		return 150;
	else if (hasPlayerItem(client, "Large Backpack"))
		return 125;
	else if (hasPlayerItem(client, "Medium Backpack"))
		return 100;
	else if (hasPlayerItem(client, "Small Backpack"))
		return 75;
	else if (hasPlayerItem(client, "Tiny Backpack"))
		return 50;
	return 30;
}

public int getItemOwnedAmount(int client, char[] itemname) {
	int count = 0;
	for (int i = 0; i < MAX_ITEMS; i++) {
		if (g_ePlayerInventory[client][i][iIsActive])
			if (StrEqual(g_ePlayerInventory[client][i][iItemname], itemname))
			count++;
	}
	return count;
}

public int getMaxSlot(int client) {
	int max = 0;
	for (int i = 0; i < MAX_ITEMS; i++)
	if (g_ePlayerInventory[client][i][iIsActive])
		max = i;
	return max;
}

public bool hasPlayerItem(int client, char itemname[128]) {
	if (getItemOwnedAmount(client, itemname) >= 1)
		return true;
	return false;
}

public void takePlayerItemBySlot(int client, int slot, char reason[256]) {
	char itemname[128];
	char itemid[64];
	strcopy(itemname, 128, g_ePlayerInventory[client][slot][iItemname]);
	strcopy(itemid, 64, g_ePlayerInventory[client][slot][iItemid]);
	
	CPrintToChat(client, "{darkred}Removed {olive}1x{darkred} {olive}%s{darkred} from your Inventory {purple}({darkred}%s{purple})", itemname, reason);
	
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char removeItemQuery[1024];
	Format(removeItemQuery, sizeof(removeItemQuery), "DELETE FROM t_rpg_items WHERE playerid = '%s' AND itemid = '%s' AND container = '';", playerid, itemid);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, removeItemQuery);
	
	Format(removeItemQuery, sizeof(removeItemQuery), "INSERT INTO `t_rpg_inventory_log` (`Id`, `timestamp`, `playerid`, `item`, `category`, `category2`, `reason`, `type`) VALUES (NULL, CURRENT_TIMESTAMP, '%s', '%s', '%s', '%s', '%s', '%s');", playerid, itemname, "", "", reason, "TAKEN");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, removeItemQuery);
	
	resetLocalInventorySlot(client, slot);
}

public bool takePlayerItem(int client, char itemname[128], int amount, char reason[256]) {
	if (amount > getItemOwnedAmount(client, itemname))
		return false;
	
	CPrintToChat(client, "{darkred}Removed {olive}%ix{darkred} {olive}%s{darkred} from your Inventory {purple}({darkred}%s{purple})", amount, itemname, reason);
	
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char removeItemQuery[1024];
	Format(removeItemQuery, sizeof(removeItemQuery), "DELETE FROM t_rpg_items WHERE playerid = '%s' AND itemname = '%s' AND container = '' LIMIT %i;", playerid, itemname, amount);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, removeItemQuery);
	
	Format(removeItemQuery, sizeof(removeItemQuery), "INSERT INTO `t_rpg_inventory_log` (`Id`, `timestamp`, `playerid`, `item`, `category`, `category2`, `reason`, `type`) VALUES (NULL, CURRENT_TIMESTAMP, '%s', '%s', '%s', '%s', '%s', '%s');", playerid, itemname, "", "", reason, "TAKEN");
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

public bool addItemToLocalInventory(int client, char timestamp[64], char playerid[20], char playername[64], char itemname[128], char itemid[64], int weight, char flags[64], char category[64], char category2[64], int rarity) {
	int slot;
	if ((slot = findFirstEmptySlotInInventory(client)) == -1)
		return false;
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
	return true;
}

public int findFirstEmptySlotInInventory(int client) {
	for (int i = 0; i < MAX_ITEMS; i++) {
		if (!g_ePlayerInventory[client][i][iIsActive])
			return i;
	}
	return -1;
}

public int getPlayerItems(int client) {
	int items = 0;
	for (int i = 0; i < MAX_ITEMS; i++) {
		if (g_ePlayerInventory[client][i][iIsActive] && StrContains(g_ePlayerInventory[client][i][iFlags], "n") == -1)
			items++;
	}
	return items;
}

public void showInventoryOfClientToOtherClient(int client1, int client2) {
	Handle menu = CreateMenu(showInventoryHandler);
	char menuTitle[512];
	Format(menuTitle, sizeof(menuTitle), "%Ns Inventory", client1);
	SetMenuTitle(menu, menuTitle);
	for (int i = 0; i < MAX_ITEMS; i++) {
		if (g_ePlayerInventory[client1][i][iIsActive]) {
			char id[8];
			IntToString(i, id, sizeof(id));
			AddMenuItem(menu, id, g_ePlayerInventory[client1][i][iItemname], ITEMDRAW_DISABLED);
		}
	}
	DisplayMenu(menu, client2, 60);
}

public void showInventoryOfClientToOtherClientByCategory(int client1, int client2, char category[64]) {
	if (!isValidClient(client1) || !isValidClient(client2))
		return;
	Handle menu;
	if (client1 != client2)
		menu = CreateMenu(showInventoryHandler);
	else
		menu = CreateMenu(inventoryMenuHandler);
	
	char menuTitle[512];
	Format(menuTitle, sizeof(menuTitle), "%Ns %ss", client1, category);
	SetMenuTitle(menu, menuTitle);
	for (int i = 0; i < MAX_ITEMS; i++) {
		if (g_ePlayerInventory[client1][i][iIsActive]) {
			if ((StrEqual(g_ePlayerInventory[client1][i][iCategory], category)) || (StrEqual(g_ePlayerInventory[client1][i][iCategory2], category))) {
				char id[8];
				IntToString(i, id, sizeof(id));
				if (client1 != client2)
					AddMenuItem(menu, id, g_ePlayerInventory[client1][i][iItemname], ITEMDRAW_DISABLED);
				else
					AddMenuItem(menu, id, g_ePlayerInventory[client1][i][iItemname]);
			}
		}
	}
	DisplayMenu(menu, client2, 60);
}

public int showInventoryHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public Action cmdOpenInventory(int client, const char[] command, int argc) {
	Handle menu = CreateMenu(inventoryTopMenuHandler);
	char menuTitle[128];
	Format(menuTitle, sizeof(menuTitle), "Your Inventory (%i/%i)", getPlayerItems(client), maxPlayerItems(client));
	SetMenuTitle(menu, menuTitle);
	AddMenuItem(menu, "inv", "Inventory");
	AddMenuItem(menu, "weapons", "Weapons");
	AddMenuItem(menu, "license", "Licenses");
	AddMenuItem(menu, "bagpack", "Backpack");
	DisplayMenu(menu, client, 60);
	
	return Plugin_Continue;
}

public int inventoryTopMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "inv")) {
			openTheInventory(client);
		} else if (StrEqual(cValue, "weapons")) {
			showInventoryOfClientToOtherClientByCategory(client, client, "Weapon");
		} else if (StrEqual(cValue, "license")) {
			showInventoryOfClientToOtherClientByCategory(client, client, "License");
		} else if (StrEqual(cValue, "bagpack")) {
			showInventoryOfClientToOtherClientByCategory(client, client, "Backpack");
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void openTheInventory(int client) {
	Handle menu = CreateMenu(inventoryMenuHandler);
	char menuTitle[128];
	Format(menuTitle, sizeof(menuTitle), "Your Inventory (%i/%i)", getPlayerItems(client), maxPlayerItems(client));
	SetMenuTitle(menu, menuTitle);
	ArrayList containedItems = CreateArray(501, 500);
	for (int i = 0; i < MAX_ITEMS; i++) {
		if (g_ePlayerInventory[client][i][iIsActive]) {
			if (FindStringInArray(containedItems, g_ePlayerInventory[client][i][iItemname]) == -1) {
				if (StrContains(g_ePlayerInventory[client][i][iFlags], "i") != -1)
					continue;
				if (StrContains(g_ePlayerInventory[client][i][iCategory], "Weapon") != -1)
					continue;
				PushArrayString(containedItems, g_ePlayerInventory[client][i][iItemname]);
				char id[8];
				IntToString(i, id, sizeof(id));
				char display[512];
				int amount = getItemOwnedAmount(client, g_ePlayerInventory[client][i][iItemname]);
				
				if (amount > 1)
					Format(display, sizeof(display), "%s (%i)", g_ePlayerInventory[client][i][iItemname], amount);
				else
					Format(display, sizeof(display), "%s", g_ePlayerInventory[client][i][iItemname]);
				
				if (StrContains(g_ePlayerInventory[client][i][iFlags], "l") != -1)
					AddMenuItem(menu, id, display, ITEMDRAW_DISABLED);
				else
					AddMenuItem(menu, id, display);
			}
		}
	}
	delete containedItems;
	DisplayMenu(menu, client, 60);
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
		Call_PushCell(id);
		Call_Finish();
		
		if (FindStringInArray(g_aHandledItems, g_ePlayerInventory[client][id][iItemname]) == -1 && FindStringInArray(g_aHandledCategories, g_ePlayerInventory[client][id][iCategory]) == -1 && FindStringInArray(g_aHandledCategories2, g_ePlayerInventory[client][id][iCategory2]) == -1) {
			Menu m = CreateMenu(defaultItemHandleHandler);
			char display[128];
			Format(display, sizeof(display), "What to do with '%s' ?", g_ePlayerInventory[client][id][iItemname]);
			SetMenuTitle(m, display);
			char cId[8];
			IntToString(id, cId, sizeof(cId));
			AddMenuItem(m, cId, "Throw Away");
			int amount = getItemOwnedAmount(client, g_ePlayerInventory[client][id][iItemname]);
			if (amount > 1) {
				char displ[128];
				Format(displ, sizeof(displ), "Throw all Away (%i)", amount);
				AddMenuItem(m, cId, displ);
			}
			DisplayMenu(m, client, 60);
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void transferItemToContainer(int client, int slot, char containerBuffer[64]) {
	char iName[128];
	strcopy(iName, sizeof(iName), g_ePlayerInventory[client][slot][iItemname]);
	if (!takeFromLocalInventory(client, iName, 1))
		return;
	CPrintToChat(client, "{darkred}Removed {olive}%ix{darkred} {olive}%s{darkred} from your Inventory {purple}({darkred}%s{purple})", 1, iName, "Put in Container");
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char updateContainerQuery[1024];
	Format(updateContainerQuery, sizeof(updateContainerQuery), "UPDATE t_rpg_items SET container = '%s' WHERE playerid = '%s' AND container = '' AND itemname = '%s' LIMIT 1;", containerBuffer, playerid, iName);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateContainerQuery);
}

public int defaultItemHandleHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char info[64];
		char displayBuffer[64];
		int flags;
		GetMenuItem(menu, item, info, sizeof(info), flags, displayBuffer, sizeof(displayBuffer));
		int id = StringToInt(info);
		char tempItem[128];
		Format(tempItem, sizeof(tempItem), "%s", g_ePlayerInventory[client][id][iItemname]);
		if (StrContains(displayBuffer, "Throw all Away") == -1)
			takePlayerItem(client, tempItem, 1, "Throwed away");
		else {
			int amount = getItemOwnedAmount(client, g_ePlayerInventory[client][id][iItemname]);
			if (takePlayerItem(client, tempItem, amount, "Throwed all away"))
				PrintToConsole(client, "Successfully removed items");
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void transferItemBySlot(int client, int target, int slot, char reason[256]) {
	char itemName[128];
	strcopy(itemName, sizeof(itemName), g_ePlayerInventory[client][slot][iItemname]);
	
	char flags[64];
	char category[64];
	char category2[64];
	strcopy(flags, sizeof(flags), g_ePlayerInventory[client][slot][iFlags]);
	strcopy(category, sizeof(category), g_ePlayerInventory[client][slot][iCategory]);
	strcopy(category2, sizeof(category2), g_ePlayerInventory[client][slot][iCategory2]);
	int weightcopy = g_ePlayerInventory[client][slot][iWeight];
	int raritycopy = g_ePlayerInventory[client][slot][iRarity];
	
	if (takePlayerItem(client, itemName, 1, reason)) {
		givePlayerItem(target, itemName, weightcopy, flags, category, category2, raritycopy, reason);
	}
}

public void transferItemFromContainer(int client, char containerName[64], char uniqueId[64]) {
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char updateContainerQuery[512];
	Format(updateContainerQuery, sizeof(updateContainerQuery), "UPDATE t_rpg_items SET playerid = '%s' WHERE itemid = '%s' AND container = '%s';", playerid, uniqueId, containerName);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateContainerQuery);
	
	char playername[MAX_NAME_LENGTH + 8];
	GetClientName(client, playername, sizeof(playername));
	char clean_playername[MAX_NAME_LENGTH * 2 + 16];
	SQL_EscapeString(g_DB, playername, clean_playername, sizeof(clean_playername));
	
	Format(updateContainerQuery, sizeof(updateContainerQuery), "UPDATE t_rpg_items SET playername = '%s' WHERE itemid = '%s' AND container = '%s';", clean_playername, uniqueId, containerName);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateContainerQuery);
	
	char loadClientInventoryQuery[1024];
	Format(loadClientInventoryQuery, sizeof(loadClientInventoryQuery), "SELECT timestamp,playerid,playername,itemname,itemid,weight,flags,category,category2,rarity FROM t_rpg_items WHERE playerid = '%s' AND container = '%s' AND itemid = '%s';", playerid, containerName, uniqueId);
	SQL_TQuery(g_DB, SQLLoadClientInventoryQuery, loadClientInventoryQuery, GetClientUserId(client));
	
	Format(updateContainerQuery, sizeof(updateContainerQuery), "UPDATE t_rpg_items SET container = '' WHERE itemid = '%s' AND container = '%s';", uniqueId, containerName);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateContainerQuery);
}

public Action cmdTableInvCb(int client, int args) {
	for (int i = 0; i < MAX_ITEMS; i++) {
		if (g_ePlayerInventory[client][i][iIsActive]) {
			char output[512];
			Format(output, sizeof(output), "Slot: %i | Name: %s | Weight: %i", i, g_ePlayerInventory[client][i][iItemname], g_ePlayerInventory[client][i][iWeight]);
			PrintToConsole(client, output);
		}
	}
	return Plugin_Handled;
}

public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, any data) {
	if (!StrEqual(error, ""))
		LogError(error);
}
