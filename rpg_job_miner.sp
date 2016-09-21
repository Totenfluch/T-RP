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
	if (!(StrContains("Mining", info, false) != -1))
		return;
	
	if (++g_iCollectedLoot[client][g_iPlayerZoneId[client]] >= MAX_COLLECT)
		g_iMiningZoneCooldown[client][g_iPlayerZoneId[client]] = g_iZoneCooldown + GetRandomInt(0, 50);
	char addCurrencyReason[256];
	Format(addCurrencyReason, sizeof(addCurrencyReason), "Mining Ore (Level %i)", jobs_getLevel(client));
	tConomy_addCurrency(client, 10 * jobs_getLevel(client), addCurrencyReason);
	jobs_addExperience(client, 10, "Mining");
}

public void OnClientAuthorized(int client) {
	g_bPlayerInMiningZone[client] = false;
	g_iPlayerZoneId[client] = -1;
}

public void OnClientDisconnect(int client) {
	g_bPlayerInMiningZone[client] = false;
	g_iPlayerZoneId[client] = -1;
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
	if (StrEqual(activeJob, "")) {
		Panel panel = CreatePanel();
		SetPanelTitle(panel, "You already have a job! Want to quit it and becoma a miner?");
		DrawPanelItem(panel, "No");
		DrawPanelItem(panel, "Not now.");
		DrawPanelItem(panel, "Yes");
		SendPanelToClient(panel, client, JobPanelHandler, 30);
	} else {
		Panel panel = CreatePanel();
		SetPanelTitle(panel, "Do you want to become a Miner?");
		DrawPanelItem(panel, "No");
		DrawPanelItem(panel, "Not now.");
		DrawPanelItem(panel, "Yes");
		SendPanelToClient(panel, client, JobPanelHandler, 30);
	}
}

public int JobPanelHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		if (item == 1) {
			
		} else if (item == 2) {
			
		} else if (item == 3) {
			jobs_quitJob(client);
			jobs_giveJob(client, "Mining");
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

