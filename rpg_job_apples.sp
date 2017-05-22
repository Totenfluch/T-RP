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
#include <rpg_jobs_core>
#include <rpg_npc_core>
#include <devzones>
#include <multicolors>
#include <tConomy>
#include <rpg_inventory_core>
#include <rpg_perks>

#pragma newdecls required

#define MAX_ZONES 128

int g_iPlayerPrevButtons[MAXPLAYERS + 1];
bool g_bPlayerInAppleZone[MAXPLAYERS + 1];
int g_iCollectedLoot[MAXPLAYERS + 1][MAX_ZONES];
int g_iPlayerZoneId[MAXPLAYERS + 1];

char g_cInAppleZones[MAX_ZONES][PLATFORM_MAX_PATH];
int g_iAppleZoneCooldown[MAXPLAYERS + 1][MAX_ZONES];
int g_iLoadedZones = 0;

int g_iZoneCooldown = 240;
int MAX_COLLECT = 3;

char activeZone[MAXPLAYERS + 1][128];

char npctype[128] = "Apple Recruiter";

public Plugin myinfo = 
{
	name = "[T-RP] Job: Apple Harvester", 
	author = PLUGIN_AUTHOR, 
	description = "Adds Apple Harvester to T-RP Jobs", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart()
{
	jobs_registerJob("Apple Harvester", "Harvest Apples to earn Money", 20, 300, 2.55);
	npc_registerNpcType(npctype);
	RegConsoleCmd("sm_astats", cmdOnMStats, "shows Apple Harvesting stats");
}

public Action cmdOnMStats(int client, int args) {
	PrintToChatAll("A:InZone: %i Collected{0} %i Collected{1} %i ZoneID: %i Cd[1] %i Cd[1] %i", g_bPlayerInAppleZone[client], g_iCollectedLoot[client][0], g_iCollectedLoot[client][1], g_iPlayerZoneId, g_iAppleZoneCooldown[client][0], g_iAppleZoneCooldown[client][1]);
	
	PrintToConsole(client, "In Zone: |%d| (ID: %i)", g_bPlayerInAppleZone[client], g_iPlayerZoneId[client]);
	for (int zones = 0; zones < MAX_ZONES; zones++)
	PrintToConsole(client, "ZoneCheck: %i : CD: %i COLL: %i", zones, g_iAppleZoneCooldown[client][zones], g_iCollectedLoot[client][zones]);
	
}

public void OnMapStart() {
	CreateTimer(1.0, refreshTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action refreshTimer(Handle Timer) {
	for (int i = 1; i < MAXPLAYERS; i++) {
		if (!isValidClient(i))
			continue;
		for (int x = 0; x < MAX_ZONES; x++) {
			if (g_iAppleZoneCooldown[i][x] > 0)
				g_iAppleZoneCooldown[i][x]--;
			if (g_iAppleZoneCooldown[i][x] == 0 && g_iCollectedLoot[i][x] == MAX_COLLECT)
				g_iCollectedLoot[i][x] = 0;
		}
	}
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon, int &tickcount) {
	if (IsClientInGame(client) && IsPlayerAlive(client)) {
		if (!(g_iPlayerPrevButtons[client] & IN_USE) && iButtons & IN_USE) {
			if (g_bPlayerInAppleZone[client]) {
				if (g_iCollectedLoot[client][g_iPlayerZoneId[client]] >= MAX_COLLECT || g_iAppleZoneCooldown[client][g_iPlayerZoneId[client]] > 0) {
					CPrintToChat(client, "{red}Apple Harvesting at this Tree is on cooldown");
					g_iPlayerPrevButtons[client] = iButtons;
					setInfo(client);
					return;
				}
				if (!jobs_isActiveJob(client, "Apple Harvester"))
					return;
				char infoString[64];
				Format(infoString, sizeof(infoString), "Apple Harvesting (%i)", jobs_getLevel(client));
				jobs_startProgressBar(client, 10, infoString);
				setInfo(client);
			}
		}
		g_iPlayerPrevButtons[client] = iButtons;
	}
}

public void jobs_OnProgressBarFinished(int client, char info[64]) {
	if (!jobs_isActiveJob(client, "Apple Harvester"))
		return;
	if (StrContains(info, "Apple", false) == -1)
		return;
	
	if (++g_iCollectedLoot[client][g_iPlayerZoneId[client]] >= MAX_COLLECT)
		g_iAppleZoneCooldown[client][g_iPlayerZoneId[client]] = g_iZoneCooldown + GetRandomInt(0, 50);
	char addCurrencyReason[256];
	Format(addCurrencyReason, sizeof(addCurrencyReason), "Apple Harvesting (Level %i)", jobs_getLevel(client));
	
	if (perks_hasPerk(client, "Apple:Avocado"))
		inventory_givePlayerItem(client, "Avocado", 50, "", "Crafting Materials", "Apple Harvesting", 1, addCurrencyReason);
	else if (perks_hasPerk(client, "Apple:Walnuts"))
		inventory_givePlayerItem(client, "Walnut", 40, "", "Crafting Materials", "Apple Harvesting", 1, addCurrencyReason);
	else if (perks_hasPerk(client, "Apple:Nuts"))
		inventory_givePlayerItem(client, "Nut", 30, "", "Crafting Materials", "Apple Harvesting", 1, addCurrencyReason);
	else if (perks_hasPerk(client, "Apple:Pears"))
		inventory_givePlayerItem(client, "Pear", 20, "", "Crafting Materials", "Apple Harvesting", 1, addCurrencyReason);
	else
		inventory_givePlayerItem(client, "Apple", 10, "", "Crafting Materials", "Apple Harvesting", 1, addCurrencyReason);
	
	if (perks_hasPerk(client, "Apples Boost4"))
		jobs_addExperience(client, 40, "Apple Harvester");
	else if (perks_hasPerk(client, "Apples Boost3"))
		jobs_addExperience(client, 30, "Apple Harvester");
	else if (perks_hasPerk(client, "Apples Boost2"))
		jobs_addExperience(client, 20, "Apple Harvester");
	else if (perks_hasPerk(client, "Apples Boost1"))
		jobs_addExperience(client, 15, "Apple Harvester");
	else
		jobs_addExperience(client, 10, "Apple Harvester");
	setInfo(client);
}

public void OnClientAuthorized(int client) {
	g_bPlayerInAppleZone[client] = false;
	g_iPlayerZoneId[client] = -1;
	for (int zones = 0; zones < MAX_ZONES; zones++) {
		g_iAppleZoneCooldown[client][zones] = g_iZoneCooldown;
		g_iCollectedLoot[client][zones] = 0;
	}
}

public void OnClientDisconnect(int client) {
	g_bPlayerInAppleZone[client] = false;
	g_iPlayerZoneId[client] = -1;
	for (int zones = 0; zones < MAX_ZONES; zones++) {
		g_iAppleZoneCooldown[client][zones] = 0;
		g_iCollectedLoot[client][zones] = 0;
	}
}

public int Zone_OnClientEntry(int client, char[] zone) {
	strcopy(activeZone[client], sizeof(activeZone), zone);
	if (StrContains(zone, "Apple", false) != -1) {
		addZone(zone);
		g_bPlayerInAppleZone[client] = true;
		g_iPlayerZoneId[client] = getZoneId(zone);
	} else {
		g_bPlayerInAppleZone[client] = false;
		g_iPlayerZoneId[client] = -1;
	}
	setInfo(client);
}

public int Zone_OnClientLeave(int client, char[] zone) {
	float pos[3];
	GetClientAbsOrigin(client, pos);
	if (Zone_isPositionInZone(activeZone[client], pos[0], pos[1], pos[2]))
		return;
	if (StrContains(zone, "Apple", false) != -1) {
		g_bPlayerInAppleZone[client] = false;
		g_iPlayerZoneId[client] = -1;
	}
	eraseInfo(client);
}

public void OnNpcInteract(int client, char npcType[64], char UniqueId[128], int entIndex) {
	if (!StrEqual(npcType, npctype))
		return;
	char activeJob[128];
	jobs_getActiveJob(client, activeJob);
	Menu panel = CreateMenu(JobPanelHandler);
	if (StrEqual(activeJob, "") || !jobs_isActiveJob(client, "Apple Harvester")) {
		SetMenuTitle(panel, "Do you want to become a Harvester?");
		AddMenuItem(panel, "x", "Nope, harvest yourself :)");
		AddMenuItem(panel, "x", "Perhaps later");
		AddMenuItem(panel, "givejob", "Yes, please!");
	} else if (jobs_isActiveJob(client, "Apple Harvester")) {
		SetMenuTitle(panel, "Welcome Harvester!");
		
		if (inventory_hasPlayerItem(client, "Apple"))
			AddMenuItem(panel, "sellApple", "Sell Apple");
		else
			AddMenuItem(panel, "x", "Sell Apple", ITEMDRAW_DISABLED);
		
		if (inventory_hasPlayerItem(client, "Apple")) {
			char sellAll[256];
			int itemamount = inventory_getPlayerItemAmount(client, "Apple");
			Format(sellAll, sizeof(sellAll), "Sell %i Apples", itemamount);
			AddMenuItem(panel, "sellAllApples", sellAll);
		}
		
		if (inventory_hasPlayerItem(client, "Pear"))
			AddMenuItem(panel, "sellPear", "Sell Pear");
		else
			AddMenuItem(panel, "x", "Sell Pear", ITEMDRAW_DISABLED);
		
		if (inventory_hasPlayerItem(client, "Pear")) {
			char sellAll[256];
			int itemamount = inventory_getPlayerItemAmount(client, "Pear");
			Format(sellAll, sizeof(sellAll), "Sell %i Pears", itemamount);
			AddMenuItem(panel, "sellAllPears", sellAll);
		}
		
		if (inventory_hasPlayerItem(client, "Nut"))
			AddMenuItem(panel, "sellNut", "Sell Nut");
		else
			AddMenuItem(panel, "x", "Sell Nut", ITEMDRAW_DISABLED);
		
		if (inventory_hasPlayerItem(client, "Nut")) {
			char sellAll[256];
			int itemamount = inventory_getPlayerItemAmount(client, "Nut");
			Format(sellAll, sizeof(sellAll), "Sell %i Nuts", itemamount);
			AddMenuItem(panel, "sellAllNuts", sellAll);
		}
		
		if (inventory_hasPlayerItem(client, "Walnut"))
			AddMenuItem(panel, "sellWalnut", "Sell Walnut");
		else
			AddMenuItem(panel, "x", "Sell Walnut", ITEMDRAW_DISABLED);
		
		if (inventory_hasPlayerItem(client, "Walnut")) {
			char sellAll[256];
			int itemamount = inventory_getPlayerItemAmount(client, "Walnut");
			Format(sellAll, sizeof(sellAll), "Sell %i Walnuts", itemamount);
			AddMenuItem(panel, "sellAllWalnuts", sellAll);
		}
		
		if (inventory_hasPlayerItem(client, "Avocado"))
			AddMenuItem(panel, "sellAvocado", "Sell Avocado");
		else
			AddMenuItem(panel, "x", "Sell Avocado", ITEMDRAW_DISABLED);
		
		if (inventory_hasPlayerItem(client, "Avocado")) {
			char sellAll[256];
			int itemamount = inventory_getPlayerItemAmount(client, "Avocado");
			Format(sellAll, sizeof(sellAll), "Sell %i Avocados", itemamount);
			AddMenuItem(panel, "sellAllAvocados", sellAll);
		}
		
		if (tConomy_getCurrency(client) >= 15000 && jobs_getLevel(client) >= 20 && jobs_getActiveJob(client, "Harvester"))
			AddMenuItem(panel, "skin", "Buy Zoey Skin (15000)[20]");
		else
			AddMenuItem(panel, "skin", "Buy Zoey Skin (15000)[20]", ITEMDRAW_DISABLED);
		
	}
	DisplayMenu(panel, client, 60);
}

public int JobPanelHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "givejob")) {
			jobs_giveJob(client, "Apple Harvester");
		} else if (StrEqual(cValue, "sellApple")) {
			if (inventory_hasPlayerItem(client, "Apple")) {
				tConomy_addCurrency(client, 10 + jobs_getLevel(client), "Sold Apple to Vendor");
				inventory_removePlayerItems(client, "Apple", 1, "Sold to Vendor");
			}
		} else if (StrEqual(cValue, "sellAllApples")) {
			int itemamount = inventory_getPlayerItemAmount(client, "Apple");
			if (inventory_removePlayerItems(client, "Apple", itemamount, "Sold to Vendor (Mass Sell)"))
				tConomy_addCurrency(client, (10 + jobs_getLevel(client)) * itemamount, "Sold Apple to Vendor");
		} else if (StrEqual(cValue, "sellPear")) {
			if (inventory_hasPlayerItem(client, "Pear")) {
				tConomy_addCurrency(client, 15 + jobs_getLevel(client), "Sold Pear to Vendor");
				inventory_removePlayerItems(client, "Pear", 1, "Sold to Vendor");
			}
		} else if (StrEqual(cValue, "sellAllPears")) {
			int itemamount = inventory_getPlayerItemAmount(client, "Pear");
			if (inventory_removePlayerItems(client, "Pear", itemamount, "Sold to Vendor (Mass Sell)"))
				tConomy_addCurrency(client, (15 + jobs_getLevel(client)) * itemamount, "Sold Pear to Vendor");
		} else if (StrEqual(cValue, "sellNut")) {
			if (inventory_hasPlayerItem(client, "Nut")) {
				tConomy_addCurrency(client, 20 + jobs_getLevel(client), "Sold Nut to Vendor");
				inventory_removePlayerItems(client, "Nut", 1, "Sold to Vendor");
			}
		} else if (StrEqual(cValue, "sellAllNuts")) {
			int itemamount = inventory_getPlayerItemAmount(client, "Nut");
			if (inventory_removePlayerItems(client, "Nut", itemamount, "Sold to Vendor (Mass Sell)"))
				tConomy_addCurrency(client, (20 + jobs_getLevel(client)) * itemamount, "Sold Nut to Vendor");
		} else if (StrEqual(cValue, "sellWalnut")) {
			if (inventory_hasPlayerItem(client, "Walnut")) {
				tConomy_addCurrency(client, 25 + jobs_getLevel(client), "Sold Walnut to Vendor");
				inventory_removePlayerItems(client, "Walnut", 1, "Sold to Vendor");
			}
		} else if (StrEqual(cValue, "sellAllWalnuts")) {
			int itemamount = inventory_getPlayerItemAmount(client, "Walnut");
			if (inventory_removePlayerItems(client, "Walnut", itemamount, "Sold to Vendor (Mass Sell)"))
				tConomy_addCurrency(client, (25 + jobs_getLevel(client)) * itemamount, "Sold Walnut to Vendor");
		} else if (StrEqual(cValue, "sellAvocado")) {
			if (inventory_hasPlayerItem(client, "Avocado")) {
				tConomy_addCurrency(client, 30 + jobs_getLevel(client), "Sold Avocado to Vendor");
				inventory_removePlayerItems(client, "Avocado", 1, "Sold to Vendor");
			}
		} else if (StrEqual(cValue, "sellAllAvocados")) {
			int itemamount = inventory_getPlayerItemAmount(client, "Avocado");
			if (inventory_removePlayerItems(client, "Avocado", itemamount, "Sold to Vendor (Mass Sell)"))
				tConomy_addCurrency(client, (30 + jobs_getLevel(client)) * itemamount, "Sold Avocado to Vendor");
		} else if (StrEqual(cValue, "skin") && jobs_getLevel(client) >= 20 && jobs_getActiveJob(client, "Harvester")) {
			tConomy_removeCurrency(client, 15000, "Bought Skin");
			inventory_givePlayerItem(client, "Zoey", 0, "", "Skin", "Skin", 1, "Bought from Apple Harvester");
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void addZone(char[] zone) {
	if (StrContains(zone, "Apple", false) != -1) {
		for (int i = 0; i < g_iLoadedZones; i++) {
			if (StrEqual(g_cInAppleZones[i], zone))
				return;
		}
		strcopy(g_cInAppleZones[g_iLoadedZones], PLATFORM_MAX_PATH, zone);
		g_iLoadedZones++;
	}
}

public int getZoneId(char[] zone) {
	for (int i = 0; i < g_iLoadedZones; i++) {
		if (StrEqual(g_cInAppleZones[i], zone))
			return i;
	}
	return -1;
}

stock bool isValidClient(int client) {
	return (1 <= client <= MaxClients && IsClientInGame(client));
}

public void setInfo(int client) {
	if (!jobs_isActiveJob(client, "Apple Harvester"))
		return;
	if (StrContains(activeZone[client], "Apple", false) == -1)
		return;
	char info[128];
	Format(info, sizeof(info), "%s: Harvested %i/%i (%is Cd)", activeZone[client], g_iCollectedLoot[client][g_iPlayerZoneId[client]], MAX_COLLECT, g_iAppleZoneCooldown[client][g_iPlayerZoneId[client]]);
	jobs_setCurrentInfo(client, info);
}

public void eraseInfo(int client) {
	jobs_setCurrentInfo(client, "");
}

