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
bool g_bPlayerInGardenerZone[MAXPLAYERS + 1];
int g_iCollectedLoot[MAXPLAYERS + 1][MAX_ZONES];
int g_iPlayerZoneId[MAXPLAYERS + 1];

char g_cGardenerZones[MAX_ZONES][PLATFORM_MAX_PATH];
int g_iGardenerZoneCooldown[MAXPLAYERS + 1][MAX_ZONES];
int g_iLoadedZones = 0;

int g_iZoneCooldown = 200;
int MAX_COLLECT = 20;

char npctype[128] = "Gardener Recruiter";

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
	jobs_registerJob("Gardener", "Mow grass and do gardening stuff", 10, 50, 2.0);
	npc_registerNpcType(npctype);
	RegConsoleCmd("sm_mstats", cmdOnMStats, "shows gardening stats");
}

public Action cmdOnMStats(int client, int args) {
	PrintToChatAll("InZone: %i Collected{0} %i Collected{1} %i ZoneID: %i Cd[1] %i Cd[1] %i", g_bPlayerInGardenerZone[client], g_iCollectedLoot[client][0], g_iCollectedLoot[client][1], g_iPlayerZoneId, g_iGardenerZoneCooldown[client][0], g_iGardenerZoneCooldown[client][1]);
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
			if (g_iGardenerZoneCooldown[i][x] > 0)
				g_iGardenerZoneCooldown[i][x]--;
			if (g_iGardenerZoneCooldown[i][x] == 0 && g_iCollectedLoot[i][x] == MAX_COLLECT)
				g_iCollectedLoot[i][x] = 0;
		}
	}
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon, int &tickcount) {
	if (IsClientInGame(client) && IsPlayerAlive(client)) {
		if (!(g_iPlayerPrevButtons[client] & IN_USE) && iButtons & IN_USE) {
			if (g_bPlayerInGardenerZone[client]) {
				if (g_iCollectedLoot[client][g_iPlayerZoneId[client]] >= MAX_COLLECT || g_iGardenerZoneCooldown[client][g_iPlayerZoneId[client]] > 0) {
					CPrintToChat(client, "{red}Gardening in this area is on cooldown");
					g_iPlayerPrevButtons[client] = iButtons;
					return;
				}
				if (!jobs_isActiveJob(client, "Gardener"))
					return;
				char infoString[64];
				Format(infoString, sizeof(infoString), "Gardening (%i)", jobs_getLevel(client));
				jobs_startProgressBar(client, 3, infoString);
			}
		}
		g_iPlayerPrevButtons[client] = iButtons;
	}
}

public void jobs_OnProgressBarFinished(int client, char info[64]) {
	if (!jobs_isActiveJob(client, "Gardener"))
		return;
	if (StrContains(info, "Gardening", false) == -1)
		return;
	
	if (++g_iCollectedLoot[client][g_iPlayerZoneId[client]] >= MAX_COLLECT)
		g_iGardenerZoneCooldown[client][g_iPlayerZoneId[client]] = g_iZoneCooldown + GetRandomInt(0, 50);
	char addCurrencyReason[256];
	Format(addCurrencyReason, sizeof(addCurrencyReason), "Gardening (Level %i)", jobs_getLevel(client));
	tConomy_addBankCurrency(client, 20, "Gardening");
	jobs_addExperience(client, 20, "Gardener");
}

public void OnClientAuthorized(int client) {
	g_bPlayerInGardenerZone[client] = false;
	g_iPlayerZoneId[client] = -1;
	for (int zones = 0; zones < MAX_ZONES; zones++) {
		g_iGardenerZoneCooldown[client][zones] = 0;
		g_iCollectedLoot[client][zones] = 0;
	}
}

public void OnClientDisconnect(int client) {
	g_bPlayerInGardenerZone[client] = false;
	g_iPlayerZoneId[client] = -1;
	for (int zones = 0; zones < MAX_ZONES; zones++) {
		g_iGardenerZoneCooldown[client][zones] = 0;
		g_iCollectedLoot[client][zones] = 0;
	}
}

public int Zone_OnClientEntry(int client, char[] zone) {
	if (StrContains(zone, "garden") != -1) {
		addZone(zone);
		g_bPlayerInGardenerZone[client] = true;
		g_iPlayerZoneId[client] = getZoneId(zone);
	} else {
		g_bPlayerInGardenerZone[client] = false;
		g_iPlayerZoneId[client] = -1;
	}
}

public int Zone_OnClientLeave(int client, char[] zone) {
	if (StrContains(zone, "garden", false) != -1) {
		g_bPlayerInGardenerZone[client] = false;
		g_iPlayerZoneId[client] = -1;
	}
}

public void OnNpcInteract(int client, char npcType[64], char UniqueId[128], int entIndex) {
	if (!StrEqual(npcType, npctype))
		return;
	char activeJob[128];
	jobs_getActiveJob(client, activeJob);
	Menu panel = CreateMenu(JobPanelHandler);
	if (StrEqual(activeJob, "") || !jobs_isActiveJob(client, "Gardener")) {
		SetMenuTitle(panel, "You already have a job! Want to quit it and becoma a Gardener?");
		AddMenuItem(panel, "x", "No");
		AddMenuItem(panel, "x", "Not now.");
		AddMenuItem(panel, "givejob", "Yes");
	} else if (jobs_isActiveJob(client, "Gardener")) {
		SetMenuTitle(panel, "Welcome Gardener!");
		AddMenuItem(panel, "x", "Are you having a nice day?", ITEMDRAW_DISABLED);
	}
	DisplayMenu(panel, client, 60);
}

public int JobPanelHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "givejob")) {
			jobs_quitJob(client);
			jobs_giveJob(client, "Gardener");
		}
	}
}

public void addZone(char[] zone) {
	if (StrContains(zone, "garden", false) != -1) {
		for (int i = 0; i < g_iLoadedZones; i++) {
			if (StrEqual(g_cGardenerZones[i], zone))
				return;
		}
		strcopy(g_cGardenerZones[g_iLoadedZones], PLATFORM_MAX_PATH, zone);
		g_iLoadedZones++;
	}
}

public int getZoneId(char[] zone) {
	for (int i = 0; i < g_iLoadedZones; i++) {
		if (StrEqual(g_cGardenerZones[i], zone))
			return i;
	}
	return -1;
}

stock bool isValidClient(int client) {
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client))
		return false;
	
	return true;
}
