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
bool g_bPlayerInAppleZone[MAXPLAYERS + 1];
int g_iCollectedLoot[MAXPLAYERS + 1][MAX_ZONES];
int g_iPlayerZoneId[MAXPLAYERS + 1];

char g_cInAppleZones[MAX_ZONES][PLATFORM_MAX_PATH];
int g_iAppleZoneCooldown[MAXPLAYERS + 1][MAX_ZONES];
int g_iLoadedZones = 0;

int g_iZoneCooldown = 100;
int MAX_COLLECT = 5;

char activeZone[MAXPLAYERS + 1][128];

char npctype[128] = "Apple Recruiter";

public Plugin myinfo = 
{
	name = "RPG Job Apple Harvester", 
	author = PLUGIN_AUTHOR, 
	description = "Adds Apple Harvester to T-RP Jobs", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart()
{
	jobs_registerJob("Apple Harvester", "Harvest Apples to earn Money", 20, 100, 3.0);
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
				jobs_startProgressBar(client, 1, infoString);
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
	inventory_givePlayerItem(client, "Apple", 20, "", "Crafting Materials", "Apple Harvesting", 1, addCurrencyReason);
	jobs_addExperience(client, 10, "Apple Harvester");
	setInfo(client);
}

public void OnClientAuthorized(int client) {
	g_bPlayerInAppleZone[client] = false;
	g_iPlayerZoneId[client] = -1;
	for (int zones = 0; zones < MAX_ZONES; zones++) {
		g_iAppleZoneCooldown[client][zones] = 0;
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
		SetMenuTitle(panel, "You already have a job! Want to quit it and becoma a Apple Harvester?");
		AddMenuItem(panel, "x", "No Miner is cooler");
		AddMenuItem(panel, "x", "Do I look like a vegetarian?");
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
		
		if (tConomy_getCurrency(client) >= 250)
			AddMenuItem(panel, "skin", "Buy Zoey Skin (250)");
		else
			AddMenuItem(panel, "skin", "Buy Zoey Skin (250)", ITEMDRAW_DISABLED);
		
	}
	DisplayMenu(panel, client, 60);
}

public int JobPanelHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "givejob")) {
			jobs_quitJob(client);
			jobs_giveJob(client, "Apple Harvester");
		} else if (StrEqual(cValue, "sellApple")) {
			if (inventory_hasPlayerItem(client, "Apple")) {
				tConomy_addCurrency(client, 5 + jobs_getLevel(client), "Sold Apple to Vendor");
				inventory_removePlayerItems(client, "Apple", 1, "Sold to Vendor");
			}
		} else if (StrEqual(cValue, "sellAllApples")) {
			int itemamount = inventory_getPlayerItemAmount(client, "Apple");
			if (inventory_removePlayerItems(client, "Apple", itemamount, "Sold to Vendor (Mass Sell)"))
				tConomy_addCurrency(client, (5 + jobs_getLevel(client)) * itemamount, "Sold Apple to Vendor");
		} else if (StrEqual(cValue, "skin")) {
			tConomy_removeCurrency(client, 250, "Bought Skin");
			inventory_givePlayerItem(client, "Zoey", 0, "", "Skin", "Skin", 1, "Bought from Apple Harvester");
		}
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
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client))
		return false;
	
	return true;
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

