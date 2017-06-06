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
#include <smlib>
#include <rpg_jobs_core>

#pragma newdecls required

int g_iLatestSlotUsed[MAXPLAYERS + 1];
char g_cLastItemUsed[MAXPLAYERS + 1][128];

int g_iPlayerPrevButtons[MAXPLAYERS + 1];

/* 
	CS:GO Grenades Indexes
*/
#define CSGO_HEGRENADE_AMMO 13
#define CSGO_FLASH_AMMO 14
#define CSGO_SMOKE_AMMO 15
#define INCENDERY_AND_MOLOTOV_AMMO 16
#define	DECOY_AMMO 17

public Plugin myinfo = 
{
	name = "[T-RP] Inventory: Weapon Handler", 
	author = PLUGIN_AUTHOR, 
	description = "Handles weapon equip and stash for T-RP", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_stash", cmdStashWeapon, "Stashes Weapon to inventory");
	//AddCommandListener(dropCSGO, "drop");
}

public void OnMapStart() {
	inventory_addItemHandle("Weapon", 4);
	inventory_addItemHandle("item_kevlar", 1);
	inventory_addItemHandle("item_assaultsuit", 1);
}

public void OnClientAuthorized(int client) {
	g_iLatestSlotUsed[client] = -1;
	strcopy(g_cLastItemUsed[client], 128, "");
}

public Action cmdStashWeapon(int client, int args) {
	stashWeapon(client, false, "");
	return Plugin_Handled;
}

public void inventory_onItemUsed(int client, char itemname[128], int weight, char category[64], char category2[64], int rarity, char timestamp[64], int slot) {
	if (!(StrContains(category, "Weapon") != -1 || StrEqual(itemname, "item_kevlar") || StrEqual(itemname, "item_assaultsuit")))
		return;
	if (StrEqual(category, "Police Weapon") && !jobs_isActiveJob(client, "Police")) {
		PrintToChat(client, "[-T-] Can not use Police Weapon");
		return;
	}
	Menu wMenu = CreateMenu(weaponMenuHandler);
	strcopy(g_cLastItemUsed[client], 128, itemname);
	g_iLatestSlotUsed[client] = slot;
	char out[512];
	Format(out, sizeof(out), "Used: %s (Weight: %i|Category: %s|Category2: %s|rarity: %i | Slot: %i)", itemname, weight, category, category2, rarity, slot);
	PrintToConsole(client, out);
	SetMenuTitle(wMenu, "What do you want to do?");
	if (StrContains(itemname, "weapon_") != -1) {
		AddMenuItem(wMenu, "EquipAndStash", "Equip Weapon (Stashes weapon slot)");
		//AddMenuItem(wMenu, "GiveWeapon", "Give me the Weapon");
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
			int slot = getSlot(g_cLastItemUsed[client]);
			if (slot != 3) {
				if (stashWeaponSlot(client, slot)) {
					takeItem(client, g_cLastItemUsed[client], g_iLatestSlotUsed[client]);
				}
			} else {
				takeItem(client, g_cLastItemUsed[client], g_iLatestSlotUsed[client]);
			}
		} else if (StrEqual(cValue, "GiveWeapon")) {
			takeItem(client, g_cLastItemUsed[client], g_iLatestSlotUsed[client]);
		} else if (StrEqual(cValue, "Delete")) {
			inventory_removePlayerItems(client, g_cLastItemUsed[client], 1, "Deleted from Inventory");
		} else if (StrEqual(cValue, "eqSuit")) {
			takeItemSuit(client, g_cLastItemUsed[client]);
		} else if (StrEqual(cValue, "eqKevlar")) {
			takeItemSuit(client, g_cLastItemUsed[client]);
		}
		strcopy(g_cLastItemUsed[client], 128, "");
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void stashWeapon(int client, bool useOverride, char[] weapon) {
	char item[128];
	GetClientWeapon(client, item, sizeof(item));
	if (useOverride)
		strcopy(item, sizeof(item), weapon);
	if (StrContains(item, "knife") != -1) {
		PrintToChat(client, "Can't stash this one");
		return;
	}
	if (StrEqual(item, "")) {
		int wpindex = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		GetEntityClassname(wpindex, item, sizeof(item));
	}
	
	if (StrEqual(item, ""))
		return;
	
	int slot = getSlot(item);
	
	if (slot != -1 && slot != 3) {
		int weaponIndex = GetPlayerWeaponSlot(client, slot);
		if (weaponIndex != -1) {
			int primaryWeaponClip = Weapon_GetPrimaryClip(weaponIndex);
			int primaryWeaponAmmo = GetEntProp(weaponIndex, Prop_Send, "m_iPrimaryReserveAmmoCount");
			
			char weaponType[64];
			if (jobs_isActiveJob(client, "Police"))
				strcopy(weaponType, sizeof(weaponType), "Police Weapon");
			else
				strcopy(weaponType, sizeof(weaponType), "Weapon");
			
			if (inventory_givePlayerItem(client, item, primaryWeaponClip * 1000 + primaryWeaponAmmo, "", weaponType, "Weapon", 2, "Stashed Weapon")) {
				RemovePlayerItem(client, weaponIndex);
				RemoveEdict(weaponIndex);
			}
		}
	} else if (slot == 3) {
		char weaponType[64];
		if (jobs_isActiveJob(client, "Police"))
			strcopy(weaponType, sizeof(weaponType), "Police Weapon");
		else
			strcopy(weaponType, sizeof(weaponType), "Weapon");
		
		if (inventory_givePlayerItem(client, item, 1, "", weaponType, "Weapon", 2, "Stashed Grenade"))
			Client_RemoveWeapon(client, item, true, true);
	}
	
	if (GetPlayerWeaponSlot(client, 2) != -1)
		EquipPlayerWeapon(client, GetPlayerWeaponSlot(client, 2));
}

public bool stashWeaponSlot(int client, int slot) {
	if (slot != -1 && slot != 3) {
		int weaponIndex = GetPlayerWeaponSlot(client, slot);
		if (weaponIndex != -1) {
			int primaryWeaponClip = Weapon_GetPrimaryClip(weaponIndex);
			int primaryWeaponAmmo = GetEntProp(weaponIndex, Prop_Send, "m_iPrimaryReserveAmmoCount");
			char item[128];
			Entity_GetClassName(weaponIndex, item, sizeof(item));
			char weaponType[64];
			if (jobs_isActiveJob(client, "Police"))
				strcopy(weaponType, sizeof(weaponType), "Police Weapon");
			else
				strcopy(weaponType, sizeof(weaponType), "Weapon");
			if (inventory_givePlayerItem(client, item, primaryWeaponClip * 1000 + primaryWeaponAmmo, "", weaponType, "Weapon", 2, "Stashed Weapon")) {
				RemovePlayerItem(client, weaponIndex);
				RemoveEdict(weaponIndex);
				if (GetPlayerWeaponSlot(client, 2) != -1)
					EquipPlayerWeapon(client, GetPlayerWeaponSlot(client, 2));
				return true;
			} else {
				return false;
			}
		}
	}
	return true;
}

public void takeItemSuit(int client, char[] item) {
	char item2[128];
	strcopy(item2, sizeof(item2), item);
	if (inventory_removePlayerItems(client, item2, 1, "Taken from Inventory")) {
		SetEntProp(client, Prop_Data, "m_ArmorValue", 100, 1);
		if (StrContains(item2, "assaultsuit") != -1) {
			SetEntProp(client, Prop_Send, "m_bHasHelmet", 1);
		}
	}
}

public void takeItem(int client, char[] item, int islot) {
	char item2[128];
	strcopy(item2, sizeof(item2), item);
	
	int weight = inventory_getItemWeightBySlot(client, islot);
	inventory_deleteItemBySlot(client, islot, "Equiped Weapon");
	GivePlayerItem(client, item);
	
	int slot = getSlot(item2);
	
	if (GetPlayerWeaponSlot(client, slot) != -1 && slot != 3) {
		EquipPlayerWeapon(client, GetPlayerWeaponSlot(client, slot));
		int weaponIndex;
		if ((weaponIndex = GetPlayerWeaponSlot(client, slot)) != -1) {
			Weapon_SetClips(weaponIndex, weight / 1000, weight % 1000);
			SetEntProp(weaponIndex, Prop_Send, "m_iPrimaryReserveAmmoCount", weight % 1000);
		}
	}
}

public int getSlot(char item[128]) {
	if (isPistol(item))
		return 1;
	else if (isSMG(item) || isRifle(item) || isShotgun(item) || isSniper(item) || isMg(item))
		return 0;
	else if (isGrenade(item))
		return 3;
	return -1;
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

public bool isMg(char[] weaponName) {
	if (StrContains(weaponName, "negev", false) != -1 || StrContains(weaponName, "m249", false) != -1) {
		return true;
	} else {
		return false;
	}
}

public bool isGrenade(char[] weaponName) {
	if (StrContains(weaponName, "grenade") != -1 || StrContains(weaponName, "decoy") != -1 || StrContains(weaponName, "molotov") != -1 || StrContains(weaponName, "flashbang") != -1)
		return true;
	return false;
}

int g_iDuckPushedTimes[MAXPLAYERS + 1];
public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon, int &tickcount) {
	if (IsClientInGame(client) && IsPlayerAlive(client)) {
		if (!(g_iPlayerPrevButtons[client] & IN_DUCK) && iButtons & IN_DUCK) {
			if (g_iDuckPushedTimes[client] == 1)
				cmdStashWeapon(client, 0);
			else
				g_iDuckPushedTimes[client] = 1;
			CreateTimer(0.3, resetDucks, GetClientUserId(client));
		}
		g_iPlayerPrevButtons[client] = iButtons;
	}
}

public Action resetDucks(Handle Timer, int client) {
	int theClient = GetClientOfUserId(client);
	g_iDuckPushedTimes[theClient] = 0;
} 