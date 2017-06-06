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
#include <devzones>
#include <tStocks>
#include <autoexecconfig>
#include <rpg_jobs_core>
#include <rpg_system>

#pragma newdecls required

float g_fSpawnX;
float g_fSpawnY;
float g_fSpawnZ;
int g_iTeleportDelay;

Handle g_hSpawnX;
Handle g_hSpawnY;
Handle g_hSpawnZ;
Handle g_hTeleportDelay;

int g_iPlayerDelay[MAXPLAYERS + 1];

Database g_DB;
char dbconfig[] = "gsxh_multiroot";

bool g_bIsClientLoaded[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[T-RP] Spawn Teleporter", 
	author = PLUGIN_AUTHOR, 
	description = "Teleports players into the map", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart()
{
	AutoExecConfig_SetFile("rpg_spawnteleporter");
	AutoExecConfig_SetCreateFile(true);
	
	g_hSpawnX = AutoExecConfig_CreateConVar("spawn_teleportPositionX", "-2920.29", "X-Position where the spawn teleporter leads to");
	g_hSpawnY = AutoExecConfig_CreateConVar("spawn_teleportPositionY", "-276.88", "Y-Position where the spawn teleporter leads to");
	g_hSpawnZ = AutoExecConfig_CreateConVar("spawn_teleportPositionz", "-50.79", "Z-Position where the spawn teleporter leads to");
	g_hTeleportDelay = AutoExecConfig_CreateConVar("spawn_delay", "300", "Delay in Seconds to block teleport for a Player");
	
	AutoExecConfig_CleanFile();
	AutoExecConfig_ExecuteFile();
	
	HookEvent("player_death", onPlayerDeath);
	RegConsoleCmd("sm_ttr", timetoRespawnCommand);
	RegConsoleCmd("sm_enter", enterGameCommand);
	
	char error[255];
	g_DB = SQL_Connect(dbconfig, true, error, sizeof(error));
	SQL_SetCharset(g_DB, "utf8");
	
	char createTableQuery[1024];
	Format(createTableQuery, sizeof(createTableQuery), "CREATE TABLE IF NOT EXISTS t_rpg_spawndelay ( `playerid` VARCHAR(20) NOT NULL , `time` INT NOT NULL , PRIMARY KEY (`playerid`)) ENGINE = InnoDB;");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createTableQuery);
}

public Action onPlayerDeath(Handle event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (isValidClient(client)) {
		g_iPlayerDelay[client] = g_iTeleportDelay;
		PrintToChat(client, "[-T-] You can enter the game in %is again. Type !ttr to check the remaining time", g_iTeleportDelay);
	}
}

public Action enterGameCommand(int client, int args) {
	float pos[3];
	GetClientAbsOrigin(client, pos);
	if (!Zone_isPositionInZone("spawn_teleporter", pos[0], pos[1], pos[2])) {
		PrintToChat(client, "Move to the teleporter...");
		return Plugin_Handled;
	}
	if (g_iPlayerDelay[client] == 0)
		teleportPlayer(client);
	return Plugin_Handled;
}

public Action timetoRespawnCommand(int client, int args) {
	PrintToChat(client, "Time to teleport: %is", g_iPlayerDelay[client]);
	return Plugin_Handled;
}

public void OnConfigsExecuted() {
	g_fSpawnX = GetConVarFloat(g_hSpawnX);
	g_fSpawnY = GetConVarFloat(g_hSpawnY);
	g_fSpawnZ = GetConVarFloat(g_hSpawnZ);
	
	g_iTeleportDelay = GetConVarInt(g_hTeleportDelay);
}

public void OnClientPostAdminCheck(int client) {
	g_iPlayerDelay[client] = 0;
	g_bIsClientLoaded[client] = false;
	loadClient(client);
}

public void OnClientDisconnect(int client) {
	if (g_iPlayerDelay[client] <= 0)
		return;
	
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char saveQuery[256];
	Format(saveQuery, sizeof(saveQuery), "INSERT IGNORE INTO `t_rpg_spawndelay` (`playerid`, `time`) VALUES ('%s', '%i')", playerid, g_iPlayerDelay[client]);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, saveQuery);
	
	
}

public void loadClient(int client) {
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char findQuery[256];
	Format(findQuery, sizeof(findQuery), "SELECT time FROM t_rpg_spawndelay WHERE playerid = '%s';", playerid);
	SQL_TQuery(g_DB, SQLLoadPlayerCallback, findQuery, GetClientUserId(client));
}

public void SQLLoadPlayerCallback(Handle owner, Handle hndl, const char[] error, any data) {
	int client = GetClientOfUserId(data);
	if (!isValidClient(client))
		return;
	while (SQL_FetchRow(hndl)) {
		g_iPlayerDelay[client] = SQL_FetchInt(hndl, 0);
		
		char playerid[20];
		GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
		char cleanupQuery[256];
		Format(cleanupQuery, sizeof(cleanupQuery), "DELETE FROM t_rpg_spawndelay WHERE playerid = '%s';", playerid);
		SQL_TQuery(g_DB, SQLLoadPlayerCallback, cleanupQuery);
	}
	g_bIsClientLoaded[client] = true;
}

public void OnMapStart() {
	CreateTimer(1.0, refreshTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action refreshTimer(Handle Timer) {
	for (int i = 0; i < MAXPLAYERS; i++) {
		if (!rpg_hasGameStarted())
			continue;
		if (!isValidClient(i))
			continue;
		if (g_iPlayerDelay[i] > 0) {
			g_iPlayerDelay[i]--;
			char info[128];
			Format(info, sizeof(info), "> Teleport in %is", g_iPlayerDelay[i]);
			float pos[3];
			GetClientAbsOrigin(i, pos);
			if (Zone_isPositionInZone("spawn_teleporter", pos[0], pos[1], pos[2]))
				jobs_setCurrentInfo(i, info);
			
		}
		if (g_iPlayerDelay[i] == 1) {
			float pos[3];
			GetClientAbsOrigin(i, pos);
			if (Zone_isPositionInZone("spawn_teleporter", pos[0], pos[1], pos[2])) {
				jobs_setCurrentInfo(i, "> Teleport Rdy <");
				PrintToChat(i, "Type !enter or reenter the teleporter to join the game!!!");
			}
		}
		if (g_iPlayerDelay[i] == 0) {
			float pos[3];
			GetClientAbsOrigin(i, pos);
			if (Zone_isPositionInZone("spawn_teleporter", pos[0], pos[1], pos[2])) {
				teleportPlayer(i);
				jobs_setCurrentInfo(i, "");
			}
		}
	}
}

public int Zone_OnClientEntry(int client, char[] zone) {
	if (StrEqual(zone, "spawn_teleporter", false)) {
		if (g_iPlayerDelay[client] == 0) {
			teleportPlayer(client);
		}
	}
}

public void teleportPlayer(int client) {
	if (!isValidClient(client))
		return;
	if (!rpg_isClientLoaded(client))
		return;
	if (!rpg_hasGameStarted())
		return;
	if (!g_bIsClientLoaded[client])
		return;
	g_iPlayerDelay[client] = g_iTeleportDelay;
	float pos[3];
	pos[0] = g_fSpawnX;
	pos[1] = g_fSpawnY;
	pos[2] = g_fSpawnZ;
	TeleportEntity(client, pos, NULL_VECTOR, NULL_VECTOR);
}

public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, any data) {
	if (!StrEqual(error, ""))
		LogError(error);
} 