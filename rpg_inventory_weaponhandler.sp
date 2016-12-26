#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <rpg_inventory_core>

#pragma newdecls required

char g_cLastItemUsed[MAXPLAYERS + 1][128];

public Plugin myinfo = 
{
	name = "Inventory Weapon Handler", 
	author = PLUGIN_AUTHOR, 
	description = "Handles weapon equip and stash for T-RP", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_stash", cmdStashWeapon, "Stashes Weapon to inventory");
}

public void OnMapStart() {
	inventory_addItemHandle("Weapon", 2);
	inventory_addItemHandle("item_kevlar", 1);
	inventory_addItemHandle("item_assaultsuit", 1);
}

public void OnClientAuthorized(int client) {
	strcopy(g_cLastItemUsed[client], 128, "");
}

public Action cmdStashWeapon(int client, int args) {
	stashWeapon(client, false, "");
	return Plugin_Handled;
}

public void inventory_onItemUsed(int client, char itemname[128], int weight, char category[64], char category2[64], int rarity, char timestamp[64]) {
	Menu wMenu = CreateMenu(weaponMenuHandler);
	strcopy(g_cLastItemUsed[client], 128, itemname);
	char out[512];
	Format(out, sizeof(out), "Used: %s (Weight: %i|Category: %s|Category2: %s|rarity: %i)", itemname, weight, category, category2, rarity);
	PrintToConsole(client, out);
	SetMenuTitle(wMenu, "What do you want to do?");
	if (StrContains(itemname, "weapon_") != -1) {
		AddMenuItem(wMenu, "EquipAndStash", "Stash Weapon and equip new one");
		AddMenuItem(wMenu, "GiveWeapon", "Give me the Weapon");
		AddMenuItem(wMenu, "Delete", "Delete Weapon");
	} else if (StrEqual(itemname, "item_assaultsuit")) {
		SetMenuTitle(wMenu, "What do you want to do?");
		AddMenuItem(wMenu, "eqSuit", "Equip Assaultsuit");
		AddMenuItem(wMenu, "Delete", "Delete Assaultsuit");
	} else if (StrEqual(itemname, "item_kevlar")) {
		SetMenuTitle(wMenu, "What do you want to do?");
		AddMenuItem(wMenu, "eqKevlar", "Equip Kevlar");
		AddMenuItem(wMenu, "Delete", "Delete Kevlar");
	} else {
		delete wMenu;
		return;
	}
	DisplayMenu(wMenu, client, 30);
}

public int weaponMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		
		if (StrEqual(cValue, "EquipAndStash")) {
			stashWeapon(client, false, g_cLastItemUsed[client]);
			takeItem(client, g_cLastItemUsed[client]);
		} else if (StrEqual(cValue, "GiveWeapon")) {
			takeItem(client, g_cLastItemUsed[client]);
		} else if (StrEqual(cValue, "Delete")) {
			inventory_removePlayerItems(client, g_cLastItemUsed[client], 1, "Deleted from Inventory");
		} else if (StrEqual(cValue, "eqSuit")) {
			takeItem(client, g_cLastItemUsed[client]);
		} else if (StrEqual(cValue, "eqKevlar")) {
			takeItem(client, g_cLastItemUsed[client]);
		}
		strcopy(g_cLastItemUsed[client], 128, "");
	}
}

public void stashWeapon(int client, bool useOverride, char[] weapon) {
	char item[128];
	GetClientWeapon(client, item, sizeof(item));
	if (useOverride)
		strcopy(item, sizeof(item), weapon);
	if (StrEqual(item, "") || StrContains(item, "knife") != -1) {
		PrintToChat(client, "Can't stash this one");
		return;
	}
	
	int slot = -1;
	if (isPistol(item))
		slot = 1;
	else if (isSMG(item) || isRifle(item) || isShotgun(item) || isSniper(item) || isMg(item))
		slot = 0;
	
	if (slot != -1) {
		int weaponIndex = GetPlayerWeaponSlot(client, slot);
		if (weaponIndex != -1) {
			RemovePlayerItem(client, weaponIndex);
			RemoveEdict(weaponIndex);
			inventory_givePlayerItem(client, item, 40, "", "Weapon", "Weapon", 2, "Stashed Weapon");
		}
	}
	
	if(GetPlayerWeaponSlot(client, 2) != -1)
		EquipPlayerWeapon(client, GetPlayerWeaponSlot(client, 2));
}

public void takeItem(int client, char[] item) {
	char item2[128];
	strcopy(item2, sizeof(item2), item);
	if (inventory_removePlayerItems(client, item2, 1, "Taken from Inventory"))
		GivePlayerItem(client, item);
}



public bool isPistol(char[] weaponName) {
	if (StrContains(weaponName, "hkp2000", false) != -1 || StrContains(weaponName, "p250", false) != -1 || StrContains(weaponName, "glock", false) != -1 || StrContains(weaponName, "deagle", false) != -1 || StrContains(weaponName, "revolver", false) != -1 || StrContains(weaponName, "usp", false) != -1 || StrContains(weaponName, "tec9", false) != -1 || StrContains(weaponName, "fiveseven", false) != -1 || StrContains(weaponName, "cz75a", false) != -1 || StrContains(weaponName, "elite", false) != -1) {
		return true;
	} else {
		return false;
	}
}

public bool isSMG(char[] weaponName) {
	if (StrContains(weaponName, "p90", false) != -1 || StrContains(weaponName, "mp7", false) != -1 || StrContains(weaponName, "ump45", false) != -1 || StrContains(weaponName, "mp9", false) != -1 || StrContains(weaponName, "mac10", false) != -1 || StrContains(weaponName, "bizon", false) != -1) {
		return true;
	} else {
		return false;
	}
}

public bool isRifle(char[] weaponName) {
	if (StrContains(weaponName, "ak47", false) != -1 || StrContains(weaponName, "aug", false) != -1 || StrContains(weaponName, "famas", false) != -1 || StrContains(weaponName, "galilar", false) != -1 || StrContains(weaponName, "sg556", false) != -1 || StrContains(weaponName, "m4a1", false) != -1) {
		return true;
	} else {
		return false;
	}
}

public bool isShotgun(char[] weaponName) {
	if (StrContains(weaponName, "xm1014", false) != -1 || StrContains(weaponName, "mag7", false) != -1 || StrContains(weaponName, "nova", false) != -1 || StrContains(weaponName, "sawedoff", false) != -1) {
		return true;
	} else {
		return false;
	}
}

public bool isSniper(char[] weaponName) {
	if (StrContains(weaponName, "awp", false) != -1 || StrContains(weaponName, "g3sg1", false) != -1 || StrContains(weaponName, "ssg08", false) != -1 || StrContains(weaponName, "scar20", false) != -1) {
		return true;
	} else {
		return false;
	}
} 

public bool isMg(char[] weaponName){
	if (StrContains(weaponName, "negev", false) != -1 || StrContains(weaponName, "m249", false) != -1){
		return true;
	} else {
		return false;
	}
}