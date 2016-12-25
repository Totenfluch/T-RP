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

#pragma newdecls required

#define MAX_ZONES 128

int g_iPlayerPrevButtons[MAXPLAYERS + 1];
bool g_bPlayerInMiningZone[MAXPLAYERS + 1];
int g_iCollectedLoot[MAXPLAYERS + 1][MAX_ZONES];
int g_iPlayerZoneId[MAXPLAYERS + 1];

char g_cMiningZones[MAX_ZONES][PLATFORM_MAX_PATH];
int g_iMiningZoneCooldown[MAXPLAYERS + 1][MAX_ZONES];
int g_iLoadedZones = 0;

int g_iZoneCooldown = 200;
int MAX_COLLECT = 5;

char npctype[128] = "mining_recruiter";

public Plugin myinfo = 
{
	name = "RPG Job Mining", 
	author = PLUGIN_AUTHOR, 
	description = "Adds mining to T-RP Jobs", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart()
{
	jobs_registerJob("Mining", "Mine Stones and Ores, melt them and sell them for money", 10, 50, 2.0);
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
					return;
				}
				if (!jobs_isActiveJob(client, "Mining"))
					return;
				char infoString[64];
				Format(infoString, sizeof(infoString), "Mining (%i)", jobs_getLevel(client));
				jobs_startProgressBar(client, 5, infoString);
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
	
	if (++g_iCollectedLoot[client][g_iPlayerZoneId[client]] >= MAX_COLLECT)
		g_iMiningZoneCooldown[client][g_iPlayerZoneId[client]] = g_iZoneCooldown + GetRandomInt(0, 50);
	char addCurrencyReason[256];
	Format(addCurrencyReason, sizeof(addCurrencyReason), "Mining Ore (Level %i)", jobs_getLevel(client));
	//tConomy_addCurrency(client, 10 * jobs_getLevel(client), addCurrencyReason);
	inventory_givePlayerItem(client, "Iron ore", 20, "", "Crafting Materials", "Mining", 1, addCurrencyReason);
	jobs_addExperience(client, 10, "Mining");
}

public void OnClientAuthorized(int client) {
	g_bPlayerInMiningZone[client] = false;
	g_iPlayerZoneId[client] = -1;
	for (int zones = 0; zones < MAX_ZONES; zones++) {
		g_iMiningZoneCooldown[client][zones] = 0;
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
	if (StrContains(zone, "mining") != -1) {
		addZone(zone);
		g_bPlayerInMiningZone[client] = true;
		g_iPlayerZoneId[client] = getZoneId(zone);
	} else {
		g_bPlayerInMiningZone[client] = false;
		g_iPlayerZoneId[client] = -1;
	}
}

public int Zone_OnClientLeave(int client, char[] zone) {
	if (StrContains(zone, "mining", false) != -1) {
		g_bPlayerInMiningZone[client] = false;
		g_iPlayerZoneId[client] = -1;
	}
}

public void OnNpcInteract(int client, char npcType[64], char UniqueId[128], int entIndex) {
	if (!StrEqual(npcType, npctype))
		return;
	char activeJob[128];
	jobs_getActiveJob(client, activeJob);
	Menu panel = CreateMenu(JobPanelHandler);
	if (StrEqual(activeJob, "") || !jobs_isActiveJob(client, "Mining")) {
		SetMenuTitle(panel, "You already have a job! Want to quit it and becoma a miner?");
		AddMenuItem(panel, "x", "No");
		AddMenuItem(panel, "x", "Not now.");
		AddMenuItem(panel, "givejob", "Yes");
	} else if (jobs_isActiveJob(client, "Mining")) {
		SetMenuTitle(panel, "Welcome Miner!");
		if (inventory_hasPlayerItem(client, "Iron ore") && tConomy_getCurrency(client) >= 10)
			AddMenuItem(panel, "refine", "Refine Iron ore (10)");
		else
			AddMenuItem(panel, "x", "Refine Iron ore (10)", ITEMDRAW_DISABLED);
		
		if (inventory_hasPlayerItem(client, "Iron Bar"))
			AddMenuItem(panel, "sellIronBar", "Sell Iron Bar");
		else
			AddMenuItem(panel, "x", "Sell Iron Bar", ITEMDRAW_DISABLED);
		
		if (inventory_hasPlayerItem(client, "Iron Bar")) {
			char sellAll[256];
			int itemamount = inventory_getPlayerItemAmount(client, "Iron Bar");
			Format(sellAll, sizeof(sellAll), "Sell %i Iron Bar%s", itemamount, itemamount > 2 ? "s":"");
			AddMenuItem(panel, "SellBars", sellAll);
		}
	}
	DisplayMenu(panel, client, 60);
}

public int JobPanelHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "givejob")) {
			jobs_quitJob(client);
			jobs_giveJob(client, "Mining");
		} else if (StrEqual(cValue, "refine")) {
			if (inventory_hasPlayerItem(client, "Iron ore") && tConomy_getCurrency(client) >= 10) {
				tConomy_removeCurrency(client, 10, "Refined Iron");
				inventory_removePlayerItems(client, "Iron ore", 1, "Gave to Vendor");
				inventory_givePlayerItem(client, "Iron Bar", 60, "", "Crafting Material", "Mining", 2, "Refined ore to Bar");
			}
		} else if (StrEqual(cValue, "sellIronBar")) {
			if (inventory_hasPlayerItem(client, "Iron Bar")) {
				tConomy_addCurrency(client, 50, "Sold Iron Bar to Vendor");
				inventory_removePlayerItems(client, "Iron Bar", 1, "Sold to Vendor");
			}
		} else if (StrEqual(cValue, "SellBars")) {
			int itemamount = inventory_getPlayerItemAmount(client, "Iron Bar");
			if (inventory_removePlayerItems(client, "Iron Bar", itemamount, "Sold to Vendor (Mass Sell)"))
				tConomy_addCurrency(client, 50 * itemamount, "Sold Iron Bar to Vendor");
		}
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
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client))
		return false;
	
	return true;
}
