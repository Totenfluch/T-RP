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
bool g_bPlayerInMiningZone[MAXPLAYERS + 1];
int g_iCollectedLoot[MAXPLAYERS + 1][MAX_ZONES];
int g_iPlayerZoneId[MAXPLAYERS + 1];

char g_cMiningZones[MAX_ZONES][PLATFORM_MAX_PATH];
int g_iMiningZoneCooldown[MAXPLAYERS + 1][MAX_ZONES];
int g_iLoadedZones = 0;

char activeZone[MAXPLAYERS + 1][128];

int g_iZoneCooldown = 320;
int MAX_COLLECT = 5;

char npctype[128] = "Mining Recruiter";

public Plugin myinfo = 
{
	name = "[T-RP] Job: Miner", 
	author = PLUGIN_AUTHOR, 
	description = "Adds mining to T-RP Jobs", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart()
{
	jobs_registerJob("Mining", "Mine Stones and Ores, melt them and sell them for money", 20, 300, 2.08);
	npc_registerNpcType(npctype);
	RegConsoleCmd("sm_mstats", cmdOnMStats, "shows Mining stats");
}

public Action cmdOnMStats(int client, int args) {
	PrintToChatAll("InZone: %i Collected{0} %i Collected{1} %i ZoneID: %i Cd[1] %i Cd[1] %i", g_bPlayerInMiningZone[client], g_iCollectedLoot[client][0], g_iCollectedLoot[client][1], g_iPlayerZoneId, g_iMiningZoneCooldown[client][0], g_iMiningZoneCooldown[client][1]);
	return Plugin_Handled;
}

public void OnMapStart() {
	CreateTimer(1.0, refreshTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action refreshTimer(Handle Timer) {
	for (int i = 1; i < MAXPLAYERS; i++) {
		if (!isValidClient(i))
			continue;
		for (int x = 0; x < MAX_ZONES; x++) {
			if (g_iMiningZoneCooldown[i][x] > 0)
				g_iMiningZoneCooldown[i][x]--;
			if (g_iMiningZoneCooldown[i][x] == 0 && g_iCollectedLoot[i][x] == MAX_COLLECT)
				g_iCollectedLoot[i][x] = 0;
		}
	}
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon, int &tickcount) {
	if (IsClientInGame(client) && IsPlayerAlive(client)) {
		if (!(g_iPlayerPrevButtons[client] & IN_USE) && iButtons & IN_USE) {
			if (g_bPlayerInMiningZone[client]) {
				if (g_iCollectedLoot[client][g_iPlayerZoneId[client]] >= MAX_COLLECT || g_iMiningZoneCooldown[client][g_iPlayerZoneId[client]] > 0) {
					CPrintToChat(client, "{red}Mining in this field is on cooldown");
					g_iPlayerPrevButtons[client] = iButtons;
					setInfo(client);
					return;
				}
				if (!jobs_isActiveJob(client, "Mining"))
					return;
				char infoString[64];
				Format(infoString, sizeof(infoString), "Mining (%i)", jobs_getLevel(client));
				if (perks_hasPerk(client, "Mining Boost3"))
					jobs_startProgressBar(client, 30, infoString);
				else if (perks_hasPerk(client, "Mining Boost1"))
					jobs_startProgressBar(client, 40, infoString);
				else
					jobs_startProgressBar(client, 50, infoString);
				setInfo(client);
			}
		}
		g_iPlayerPrevButtons[client] = iButtons;
	}
}

public void jobs_OnProgressBarFinished(int client, char info[64]) {
	if (!jobs_isActiveJob(client, "Mining"))
		return;
	if (StrContains(info, "Mining", false) == -1)
		return;
	if (g_iPlayerZoneId[client] == -1)
		return;
	
	if (++g_iCollectedLoot[client][g_iPlayerZoneId[client]] >= MAX_COLLECT)
		g_iMiningZoneCooldown[client][g_iPlayerZoneId[client]] = g_iZoneCooldown + GetRandomInt(0, 50);
	char addCurrencyReason[256];
	Format(addCurrencyReason, sizeof(addCurrencyReason), "Mining Ore (Level %i)", jobs_getLevel(client));
	//tConomy_addCurrency(client, 10 * jobs_getLevel(client), addCurrencyReason);
	
	if (perks_hasPerk(client, "Mining Gold") && GetRandomInt(0, 10) == 2)
		inventory_givePlayerItem(client, "Gold ore", 20, "", "Crafting Materials", "Mining", 1, addCurrencyReason);
	else if (perks_hasPerk(client, "Mining Iron") && GetRandomInt(0, 10) == 2)
		inventory_givePlayerItem(client, "Iron ore", 20, "", "Crafting Materials", "Mining", 1, addCurrencyReason);
	else if (perks_hasPerk(client, "Mining Fosil") && GetRandomInt(0, 10) == 2)
		inventory_givePlayerItem(client, "Fosil", 20, "", "Crafting Materials", "Mining", 1, addCurrencyReason);
	else if (perks_hasPerk(client, "Mining Copper") && GetRandomInt(0, 10) == 2)
		inventory_givePlayerItem(client, "Copper ore", 20, "", "Crafting Materials", "Mining", 1, addCurrencyReason);
	
	inventory_givePlayerItem(client, "Iron ore", 20, "", "Crafting Materials", "Mining", 1, addCurrencyReason);
	
	if (perks_hasPerk(client, "Mining Boost4"))
		jobs_addExperience(client, 35, "Mining");
	else if (perks_hasPerk(client, "Mining Boost2"))
		jobs_addExperience(client, 30, "Mining");
	else
		jobs_addExperience(client, 25, "Mining");
	setInfo(client);
}

public void OnClientAuthorized(int client) {
	g_bPlayerInMiningZone[client] = false;
	g_iPlayerZoneId[client] = -1;
	for (int zones = 0; zones < MAX_ZONES; zones++) {
		g_iMiningZoneCooldown[client][zones] = g_iZoneCooldown;
		g_iCollectedLoot[client][zones] = 0;
	}
}

public void OnClientDisconnect(int client) {
	g_bPlayerInMiningZone[client] = false;
	g_iPlayerZoneId[client] = -1;
	for (int zones = 0; zones < MAX_ZONES; zones++) {
		g_iMiningZoneCooldown[client][zones] = 0;
		g_iCollectedLoot[client][zones] = 0;
	}
}

public int Zone_OnClientEntry(int client, char[] zone) {
	strcopy(activeZone[client], sizeof(activeZone), zone);
	if (StrContains(zone, "mining") != -1) {
		addZone(zone);
		g_bPlayerInMiningZone[client] = true;
		g_iPlayerZoneId[client] = getZoneId(zone);
	} else {
		g_bPlayerInMiningZone[client] = false;
		g_iPlayerZoneId[client] = -1;
	}
	setInfo(client);
}

public int Zone_OnClientLeave(int client, char[] zone) {
	float pos[3];
	GetClientAbsOrigin(client, pos);
	if (Zone_isPositionInZone(activeZone[client], pos[0], pos[1], pos[2]))
		return;
	if (StrContains(zone, "mining", false) != -1) {
		g_bPlayerInMiningZone[client] = false;
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
	if (StrEqual(activeJob, "") || !jobs_isActiveJob(client, "Mining")) {
		SetMenuTitle(panel, "Do you want to be a Miner?");
		AddMenuItem(panel, "x", "No");
		AddMenuItem(panel, "x", "Not now.");
		AddMenuItem(panel, "givejob", "Yes");
	} else if (jobs_isActiveJob(client, "Mining")) {
		SetMenuTitle(panel, "Welcome Miner!");
		
		if (inventory_hasPlayerItem(client, "Iron ore") && tConomy_getCurrency(client) >= 10)
			AddMenuItem(panel, "refineIron", "Refine Iron ore (10$)");
		else
			AddMenuItem(panel, "x", "Refine Iron ore (10$)", ITEMDRAW_DISABLED);
		
		if (inventory_hasPlayerItem(client, "Iron Bar"))
			AddMenuItem(panel, "sellIronBar", "Sell Iron Bar");
		
		if (inventory_getPlayerItemAmount(client, "Iron Bar") > 1) {
			char sellAll[256];
			int itemamount = inventory_getPlayerItemAmount(client, "Iron Bar");
			Format(sellAll, sizeof(sellAll), "Sell %i Iron Bar%s", itemamount, itemamount > 2 ? "s":"");
			AddMenuItem(panel, "SellIronBars", sellAll);
		}
		
		if (inventory_hasPlayerItem(client, "Fosil"))
			AddMenuItem(panel, "sellFosil", "Sell Fosil");
		
		if (inventory_getPlayerItemAmount(client, "Fosil") > 1) {
			char sellAll[256];
			int itemamount = inventory_getPlayerItemAmount(client, "Fosil");
			Format(sellAll, sizeof(sellAll), "Sell %i Fosil%s", itemamount, itemamount > 2 ? "s":"");
			AddMenuItem(panel, "SellFosils", sellAll);
		}
		
		if (inventory_hasPlayerItem(client, "Copper ore") && tConomy_getCurrency(client) >= 10)
			AddMenuItem(panel, "refineCopper", "Refine Copper ore (25$)");
		else
			AddMenuItem(panel, "x", "Refine Copper ore (25$)", ITEMDRAW_DISABLED);
		
		if (inventory_hasPlayerItem(client, "Copper Bar"))
			AddMenuItem(panel, "sellCopperBar", "Sell Copper Bar");
		
		if (inventory_getPlayerItemAmount(client, "Copper Bar") > 1) {
			char sellAll[256];
			int itemamount = inventory_getPlayerItemAmount(client, "Copper Bar");
			Format(sellAll, sizeof(sellAll), "Sell %i Copper Bar%s", itemamount, itemamount > 2 ? "s":"");
			AddMenuItem(panel, "SellCopperBars", sellAll);
		}
		
		if (inventory_hasPlayerItem(client, "Gold ore") && tConomy_getCurrency(client) >= 10)
			AddMenuItem(panel, "refineGold", "Refine Gold ore (500$)");
		else
			AddMenuItem(panel, "x", "Refine Gold ore (500$)", ITEMDRAW_DISABLED);
		
		if (inventory_hasPlayerItem(client, "Gold Bar"))
			AddMenuItem(panel, "sellGoldBar", "Sell Gold Bar");
		
		if (inventory_getPlayerItemAmount(client, "Gold Bar") > 1) {
			char sellAll[256];
			int itemamount = inventory_getPlayerItemAmount(client, "Gold Bar");
			Format(sellAll, sizeof(sellAll), "Sell %i Gold Bar%s", itemamount, itemamount > 2 ? "s":"");
			AddMenuItem(panel, "SellGoldBars", sellAll);
		}
		
		if (tConomy_getCurrency(client) >= 15000 && jobs_getLevel(client) >= 20 && jobs_getActiveJob(client, "Mining"))
			AddMenuItem(panel, "skin", "Buy Barryv Skin (15000)[20]");
		else
			AddMenuItem(panel, "skin", "Buy Barryv Skin (15000)[20]", ITEMDRAW_DISABLED);
	}
	DisplayMenu(panel, client, 60);
}

public int JobPanelHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "givejob")) {
			jobs_giveJob(client, "Mining");
		} else if (StrEqual(cValue, "refineIron")) {
			if (inventory_hasPlayerItem(client, "Iron ore") && tConomy_getCurrency(client) >= 10) {
				tConomy_removeCurrency(client, 10, "Refined Iron");
				inventory_removePlayerItems(client, "Iron ore", 1, "Gave to Vendor");
				inventory_givePlayerItem(client, "Iron Bar", 60, "", "Crafting Material", "Mining", 2, "Refined ore to Bar");
			}
		} else if (StrEqual(cValue, "sellIronBar")) {
			if (inventory_hasPlayerItem(client, "Iron Bar")) {
				tConomy_addCurrency(client, 80, "Sold Iron Bar to Vendor");
				inventory_removePlayerItems(client, "Iron Bar", 1, "Sold to Vendor");
			}
		} else if (StrEqual(cValue, "SellIronBars")) {
			int itemamount = inventory_getPlayerItemAmount(client, "Iron Bar");
			if (inventory_removePlayerItems(client, "Iron Bar", itemamount, "Sold to Vendor (Mass Sell)"))
				tConomy_addCurrency(client, 80 * itemamount, "Sold Iron Bar to Vendor");
		} else if (StrEqual(cValue, "sellFosil")) {
			if (inventory_hasPlayerItem(client, "Fosil")) {
				tConomy_addCurrency(client, 65, "Sold Fosil to Vendor");
				inventory_removePlayerItems(client, "Fosil", 1, "Sold to Vendor");
			}
		} else if (StrEqual(cValue, "SellFosils")) {
			int itemamount = inventory_getPlayerItemAmount(client, "Fosil");
			if (inventory_removePlayerItems(client, "Fosil", itemamount, "Sold to Vendor (Mass Sell)"))
				tConomy_addCurrency(client, 65 * itemamount, "Sold Fosil to Vendor");
		} else if (StrEqual(cValue, "refineCopper")) {
			if (inventory_hasPlayerItem(client, "Copper ore") && tConomy_getCurrency(client) >= 25) {
				tConomy_removeCurrency(client, 25, "Refined Copper");
				inventory_removePlayerItems(client, "Copper ore", 1, "Gave to Vendor");
				inventory_givePlayerItem(client, "Copper Bar", 60, "", "Crafting Material", "Mining", 2, "Refined ore to Bar");
			}
		} else if (StrEqual(cValue, "sellCopperBar")) {
			if (inventory_hasPlayerItem(client, "Copper Bar")) {
				tConomy_addCurrency(client, 85, "Sold Copper Bar to Vendor");
				inventory_removePlayerItems(client, "Copper Bar", 1, "Sold to Vendor");
			}
		} else if (StrEqual(cValue, "SellCopperBars")) {
			int itemamount = inventory_getPlayerItemAmount(client, "Copper Bar");
			if (inventory_removePlayerItems(client, "Copper Bar", itemamount, "Sold to Vendor (Mass Sell)"))
				tConomy_addCurrency(client, 85 * itemamount, "Sold Copper Bar to Vendor");
		} else if (StrEqual(cValue, "refineGold")) {
			if (inventory_hasPlayerItem(client, "Gold ore") && tConomy_getCurrency(client) >= 500) {
				tConomy_removeCurrency(client, 500, "Refined Gold");
				inventory_removePlayerItems(client, "Gold ore", 1, "Gave to Vendor");
				inventory_givePlayerItem(client, "Gold Bar", 60, "", "Crafting Material", "Mining", 2, "Refined ore to Bar");
			}
		} else if (StrEqual(cValue, "sellGoldBar")) {
			if (inventory_hasPlayerItem(client, "Gold Bar")) {
				tConomy_addCurrency(client, 900, "Sold Gold Bar to Vendor");
				inventory_removePlayerItems(client, "Gold Bar", 1, "Sold to Vendor");
			}
		} else if (StrEqual(cValue, "SellGoldBars")) {
			int itemamount = inventory_getPlayerItemAmount(client, "Gold Bar");
			if (inventory_removePlayerItems(client, "Gold Bar", itemamount, "Sold to Vendor (Mass Sell)"))
				tConomy_addCurrency(client, 900 * itemamount, "Sold Gold Bar to Vendor");
		} else if (tConomy_getCurrency(client) >= 15000 && jobs_getLevel(client) >= 20 && jobs_getActiveJob(client, "Mining")) {
			tConomy_removeCurrency(client, 15000, "Bought Skin");
			inventory_givePlayerItem(client, "Barryv", 0, "", "Skin", "Skin", 1, "Bought from Mining Recruiter");
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void addZone(char[] zone) {
	if (StrContains(zone, "mining", false) != -1) {
		for (int i = 0; i < g_iLoadedZones; i++) {
			if (StrEqual(g_cMiningZones[i], zone))
				return;
		}
		strcopy(g_cMiningZones[g_iLoadedZones], PLATFORM_MAX_PATH, zone);
		g_iLoadedZones++;
	}
}

public int getZoneId(char[] zone) {
	for (int i = 0; i < g_iLoadedZones; i++) {
		if (StrEqual(g_cMiningZones[i], zone))
			return i;
	}
	return -1;
}

stock bool isValidClient(int client) {
	return (1 <= client <= MaxClients && IsClientInGame(client));
}

public void setInfo(int client) {
	if (!jobs_isActiveJob(client, "Mining"))
		return;
	if (StrContains(activeZone[client], "mining", false) == -1)
		return;
	char info[128];
	Format(info, sizeof(info), "%s: Mined %i/%i (%is Cd)", activeZone[client], g_iCollectedLoot[client][g_iPlayerZoneId[client]], MAX_COLLECT, g_iMiningZoneCooldown[client][g_iPlayerZoneId[client]]);
	jobs_setCurrentInfo(client, info);
}

public void eraseInfo(int client) {
	jobs_setCurrentInfo(client, "");
}
