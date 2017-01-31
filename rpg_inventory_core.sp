#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <multicolors>
#include <rpg_licensing>
#include <sha1>

#pragma newdecls required

#define MAX_ITEMS 500

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
	
	RegConsoleCmd("sm_sinv", cmdSInvCallback, "Inventory by category");
	
	HookEvent("round_start", onRoundStart);
	
	g_aHandledItems = CreateArray(400, 200);
	g_aHandledCategories = CreateArray(300, 100);
	g_aHandledCategories2 = CreateArray(300, 100);
	ClearArray(g_aHandledItems);
	ClearArray(g_aHandledCategories);
	ClearArray(g_aHandledCategories2);
}

public bool liCheck() {
	char licenseKey[64];
	char shaKey[128];
	licensing_getChecksums(licenseKey, shaKey);
	char checksum[128];
	char tochecksum[128];
	int t = GetTime();
	int w = t/10000+(24*60*60)*3;
	Format(tochecksum, sizeof(tochecksum), "|||success %i %s|||", w, licenseKey);
	SHA1String(tochecksum, checksum, true);
	return StrEqual(checksum, shaKey);
}

public void onRoundStart(Handle event, const char[] name, bool dontBroadcast){
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

public int Native_addItemHandle(Handle plugin, int numParams) {
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
	Format(itemid, sizeof(itemid), "%s_%s", itemname, timeKey);
	
	char addItemQuery[512];
	Format(addItemQuery, sizeof(addItemQuery), "INSERT INTO `t_rpg_items` (`Id`, `timestamp`, `playerid`, `playername`, `itemname`, `itemid`, `weight`, `flags`, `category`, `category2`, `rarity`) VALUES (NULL, CURRENT_TIMESTAMP, '%s', '%s', '%s', '%s', '%i', '%s', '%s', '%s', '%i');", playerid, clean_playername, itemname, itemid, weight, flags, category, category2, rarity);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, addItemQuery);
	char strict_playername[64];
	strcopy(strict_playername, sizeof(strict_playername), playername);
	CPrintToChat(client, "{lightgreen}You have recieved: {grey2}%s {blue}({grey2}%s{blue})", itemname, reason);
	return addItemToLocalInventory(client, timeKey, playerid, strict_playername, itemname, itemid, weight, flags, category, category2, rarity);
}

public int maxPlayerItems(int client) {
	if (hasPlayerItem(client, "Gigantic Backpack"))
		return 500;
	else if (hasPlayerItem(client, "Enormous Backpack"))
		return 375;
	else if (hasPlayerItem(client, "Big Backpack"))
		return 250;
	else if (hasPlayerItem(client, "Large Backpack"))
		return 150;
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
	Handle menu = CreateMenu(showInventoryHandler);
	char menuTitle[512];
	Format(menuTitle, sizeof(menuTitle), "%Ns Licenses", client1);
	SetMenuTitle(menu, menuTitle);
	for (int i = 0; i < MAX_ITEMS; i++) {
		if (g_ePlayerInventory[client1][i][iIsActive]) {
			if (StrContains(g_ePlayerInventory[client1][i][iCategory], category) != 1 || StrContains(g_ePlayerInventory[client1][i][iCategory2], category) != -1) {
				char id[8];
				IntToString(i, id, sizeof(id));
				AddMenuItem(menu, id, g_ePlayerInventory[client1][i][iItemname], ITEMDRAW_DISABLED);
			}
		}
	}
	DisplayMenu(menu, client2, 60);
}

public int showInventoryHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		
	}
}

public Action cmdOpenInventory(int client, const char[] command, int argc) {
	Handle menu = CreateMenu(inventoryMenuHandler);
	char menuTitle[128];
	Format(menuTitle, sizeof(menuTitle), "Your Inventory (%i/%i)", getPlayerItems(client), maxPlayerItems(client));
	SetMenuTitle(menu, menuTitle);
	ArrayList containedItems = CreateArray(800, 800);
	for (int i = 0; i < MAX_ITEMS; i++) {
		if (g_ePlayerInventory[client][i][iIsActive]) {
			if (FindStringInArray(containedItems, g_ePlayerInventory[client][i][iItemname]) == -1) {
				if (StrContains(g_ePlayerInventory[client][i][iFlags], "i") != -1)
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
	DisplayMenu(menu, client, 60);
	
	return Plugin_Continue;
}

/*public Action cmdOpenInventory(int client, const char[] command, int argc)
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
}*/

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
}

public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, any data) {
	if (!StrEqual(error, ""))
		LogError(error);
}
