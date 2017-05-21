#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <rpg_jobs_core>
#include <tStocks>

#pragma newdecls required

int g_iCooldown[MAXPLAYERS + 1];
#define COOLDOWN 120

public Plugin myinfo = 
{
	name = "RPG Unstuck", 
	author = PLUGIN_AUTHOR, 
	description = "allows players to unstuck", 
	version = PLUGIN_VERSION, 
	url = "https://ggc-base.de"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_unstuck", cmdUnstuck, "Unstucks yourself after waiting");
}

public Action cmdUnstuck(int client, int args) {
	if (isValidClient(client))
		if (g_iCooldown[client] == 0)
		jobs_startProgressBar(client, 300, "Unstuck");
	else
		PrintToChat(client, "[-T-] You have %is Cooldown left", g_iCooldown[client]);
	return Plugin_Handled;
}

public void OnClientPostAdminCheck(int client) {
	g_iCooldown[client] = COOLDOWN;
}

public void OnMapStart() {
	CreateTimer(1.0, refreshTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action refreshTimer(Handle Timer) {
	for (int i = 1; i < MAXPLAYERS; i++)
	if (g_iCooldown[i] > 0)
		g_iCooldown[i]--;
}

public void jobs_OnProgressBarFinished(int client, char info[64]) {
	if (!isValidClient(client))
		return;
	g_iCooldown[client] = COOLDOWN;
	if (StrContains(info, "Unstuck") != -1)
		unstuckClient(client);
}

public void unstuckClient(int client) {
	float pos[3];
	GetClientAbsOrigin(client, pos);
	pos[2] += 50;
	float speed[3];
	speed[0] = 0.0;
	speed[1] = 0.0;
	speed[2] = 0.0;
	TeleportEntity(client, pos, NULL_VECTOR, speed);
} 