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
#include <tCrime>
#include <smlib>
#include <map_workshop_functions>
#include <autoexecconfig>
#include <devzones>

#pragma newdecls required

#define MAX_JAILS 128

char dbconfig[] = "gsxh_multiroot";
Database g_DB;

enum jailProperties {
	Float:gXPos, 
	Float:gYPos, 
	Float:gZPos, 
	bool:gIsActive
}

int g_eJailSpawnPoints[MAX_JAILS][jailProperties];
int g_iLoadedJail = 0;
//int g_iActiveJail = 0;

Handle g_hJailExitX;
float g_fJailExitX;

Handle g_hJailExitY;
float g_fJailExitY;

Handle g_hJailExitZ;
float g_fJailExitZ;

Handle g_hMaxDistanceToJail;
float g_fMaxDistanceToJail;

enum playerProperties {
	ppCell_number, 
	ppTimes_in_jail, 
	ppTime_spent_in_jail, 
	String:ppFlags[255]
}
int g_ePlayerData[MAXPLAYERS + 1][playerProperties];

bool g_bIsInJail[MAXPLAYERS + 1];

int g_iBlueGlow;

public Plugin myinfo = 
{
	name = "[T-RP] Jail Core", 
	author = PLUGIN_AUTHOR, 
	description = "adds Jails to the T-RP", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_jailcells", addJailCells, ADMFLAG_ROOT, "Opens the Menu to add Jail Cells");
	RegConsoleCmd("sm_jstats", getJailStats, "lists stats");
	
	char error[255];
	g_DB = SQL_Connect(dbconfig, true, error, sizeof(error));
	SQL_SetCharset(g_DB, "utf8");
	
	AutoExecConfig_SetFile("rpg_jail");
	AutoExecConfig_SetCreateFile(true);
	
	g_hJailExitX = AutoExecConfig_CreateConVar("jail_ExitPositionX", "-2920.29", "X-Position where the Players exit the Jail");
	g_hJailExitY = AutoExecConfig_CreateConVar("jail_ExitPositionY", "-276.88", "X-Position where the Players exit the Jail");
	g_hJailExitZ = AutoExecConfig_CreateConVar("jail_ExitPositionZ", "-50.79", "X-Position where the Players exit the Jail");
	g_hMaxDistanceToJail = AutoExecConfig_CreateConVar("jail_maxDistance", "300.0", "Max Distance Player can have to jail before getting teleported back");
	
	AutoExecConfig_CleanFile();
	AutoExecConfig_ExecuteFile();
	
	char createTableQuery[4096];
	Format(createTableQuery, sizeof(createTableQuery), "CREATE TABLE IF NOT EXISTS t_rpg_jail (`Id`BIGINT NOT NULL AUTO_INCREMENT, `playerid`VARCHAR(20)NOT NULL, `playername`VARCHAR(64)CHARACTER SET utf8 COLLATE utf8_bin NOT NULL, `cell_number`INT NOT NULL, `times_in_jail`INT NOT NULL, `time_spent_in_jail`INT NOT NULL, `flags`VARCHAR(255)NOT NULL, PRIMARY KEY(`Id`), UNIQUE KEY `playerid` (`playerid`))ENGINE = InnoDB CHARSET = utf8 COLLATE utf8_bin;");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createTableQuery);
}


public void OnConfigsExecuted() {
	g_fJailExitX = GetConVarFloat(g_hJailExitX);
	g_fJailExitY = GetConVarFloat(g_hJailExitY);
	g_fJailExitZ = GetConVarFloat(g_hJailExitZ);
	
	g_fMaxDistanceToJail = GetConVarFloat(g_hMaxDistanceToJail);
}

public Action getJailStats(int client, int args) {
	char out[512];
	Format(out, sizeof(out), "JStats: CN: %i | TIM: %i | TSIJ: %i | FL: %s | IS: %d", g_ePlayerData[client][ppCell_number], g_ePlayerData[client][ppTimes_in_jail], g_ePlayerData[client][ppTime_spent_in_jail], g_ePlayerData[client][ppFlags], g_bIsInJail[client]);
	PrintToConsole(client, out);
	
	for (int i = 0; i < g_iLoadedJail; i++)
	PrintToConsole(client, "P:%i (%.2f | %.2f | %.2f)", i, g_eJailSpawnPoints[i][gXPos], g_eJailSpawnPoints[i][gYPos], g_eJailSpawnPoints[i][gZPos]);
	
	return Plugin_Handled;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	/*
		Puts a client in jail
		
		@Param1 -> int initiator
		@Param2 -> int target <- goes to jail
		
		@return none
	*/
	CreateNative("jail_putInJail", Native_putInJail);
	
	/*
		frees a client from jail
		
		@Param1 -> int client
		
		@return none
	*/
	CreateNative("jail_freeFromJail", Native_freeFromJail);
	
	/*
		checks if a client is in jail
		
		@Param1 -> int client
		
		@return true or false
	*/
	CreateNative("jail_isInJail", Native_isInJail);
}

public int Native_putInJail(Handle plugin, int numParams) {
	int initiator = GetNativeCell(1);
	int target = GetNativeCell(2);
	putInJail(initiator, target);
}

public int Native_freeFromJail(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	free(client);
}

public int Native_isInJail(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	return g_bIsInJail[client];
}

public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, any data) {
	if (!StrEqual(error, ""))
		LogError(error);
}

public void OnClientPostAdminCheck(int client) {
	g_bIsInJail[client] = false;
	
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char playername[MAX_NAME_LENGTH + 8];
	GetClientName(client, playername, sizeof(playername));
	char clean_playername[MAX_NAME_LENGTH * 2 + 16];
	SQL_EscapeString(g_DB, playername, clean_playername, sizeof(clean_playername));
	
	char addPlayerQuery[2048];
	Format(addPlayerQuery, sizeof(addPlayerQuery), "INSERT IGNORE INTO `t_rpg_jail` (`Id`, `playerid`, `playername`, `cell_number`, `times_in_jail`, `time_spent_in_jail`, `flags`) VALUES (NULL, '%s', '%s', '-1', '0', '0', '');", playerid, clean_playername);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, addPlayerQuery);
	fetchClientData(client);
}

public void OnClientDisconnect(int client) {
	g_ePlayerData[client][ppCell_number] = -1;
	g_ePlayerData[client][ppTimes_in_jail] = -1;
	g_ePlayerData[client][ppTime_spent_in_jail] = -1;
	strcopy(g_ePlayerData[client][ppFlags], 255, "");
	g_bIsInJail[client] = false;
}

public void putInJail(int initiator, int target) {
	if (!isValidClient(initiator) || !isValidClient(target))
		return;
	if (tCrime_getCrime(target) <= 0)
		return;
	
	char playerid[20];
	GetClientAuthId(target, AuthId_Steam2, playerid, sizeof(playerid));
	
	g_bIsInJail[target] = true;
	int cell = GetRandomInt(0, (g_iLoadedJail - 1));
	
	increaseTimesInJail(target);
	
	char putInJailQuery[512];
	Format(putInJailQuery, sizeof(putInJailQuery), "UPDATE t_rpg_jail SET cell_number = %i WHERE playerid = '%s';", cell, playerid);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, putInJailQuery);
	
	putInCell(target, cell);
}

public void putInCell(int client, int cellnumber) {
	g_bIsInJail[client] = true;
	float jailpos[3];
	jailpos[0] = g_eJailSpawnPoints[cellnumber][gXPos];
	jailpos[1] = g_eJailSpawnPoints[cellnumber][gYPos];
	jailpos[2] = g_eJailSpawnPoints[cellnumber][gZPos];
	g_ePlayerData[client][ppCell_number] = cellnumber;
	TeleportEntity(client, jailpos, NULL_VECTOR, NULL_VECTOR);
}

public void free(int client) {
	escape(client);
	
	float pos[3];
	pos[0] = g_fJailExitX;
	pos[1] = g_fJailExitY;
	pos[2] = g_fJailExitZ;
	TeleportEntity(client, pos, NULL_VECTOR, NULL_VECTOR);
}

public void escape(int client) {
	g_bIsInJail[client] = false;
	g_ePlayerData[client][ppCell_number] = -1;
	
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char freeClientQuery[512];
	Format(freeClientQuery, sizeof(freeClientQuery), "UPDATE t_rpg_jail SET cell_number = -1 WHERE playerid = '%s';", playerid);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, freeClientQuery);
}

public void OnMapStart() {
	g_iLoadedJail = 0;
	g_iBlueGlow = PrecacheModel("sprites/blueglow1.vmt");
	loadJailSpawnPoints();
	CreateTimer(1.0, refreshTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action refreshTimer(Handle Timer) {
	for (int i = 1; i < MAXPLAYERS; i++) {
		if (!isValidClient(i))
			continue;
		if (g_bIsInJail[i] && g_ePlayerData[i][ppCell_number] != -1) {
			if (tCrime_getCrime(i) <= 0)
				free(i);
			if (getDistanceToJail(i) > g_fMaxDistanceToJail)
				putInCell(i, g_ePlayerData[i][ppCell_number]);
			increaseJailTime(i);
		}
		if (g_bIsInJail[i] && g_ePlayerData[i][ppCell_number] == -1)
			free(i);
	}
}

public float getDistanceToJail(int client) {
	float clientPos[3];
	GetClientAbsOrigin(client, clientPos);
	
	float jailpos[3];
	if (g_ePlayerData[client][ppCell_number] == -1)
		return 0.0;
	jailpos[0] = g_eJailSpawnPoints[g_ePlayerData[client][ppCell_number]][gXPos];
	jailpos[1] = g_eJailSpawnPoints[g_ePlayerData[client][ppCell_number]][gYPos];
	jailpos[2] = g_eJailSpawnPoints[g_ePlayerData[client][ppCell_number]][gZPos];
	
	return GetVectorDistance(clientPos, jailpos);
}

public void increaseJailTime(int client) {
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char updateJailTimeQuery[512];
	Format(updateJailTimeQuery, sizeof(updateJailTimeQuery), "UPDATE t_rpg_jail SET time_spent_in_jail = time_spent_in_jail + 1 WHERE playerid = '%s'", playerid);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateJailTimeQuery);
}

public void increaseTimesInJail(int client) {
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char updateCrimeQuery[512];
	Format(updateCrimeQuery, sizeof(updateCrimeQuery), "UPDATE t_rpg_jail SET times_in_jail = times_in_jail + 1 WHERE playerid = '%s'", playerid);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateCrimeQuery);
}

public void fetchClientData(int client) {
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char fetchClientDataQuery[1024];
	Format(fetchClientDataQuery, sizeof(fetchClientDataQuery), "SELECT playerid,playername,cell_number,times_in_jail,time_spent_in_jail,flags FROM t_rpg_jail WHERE playerid = '%s'", playerid);
	SQL_TQuery(g_DB, SQLFetchClientDataCallback, fetchClientDataQuery, client);
}

public void SQLFetchClientDataCallback(Handle owner, Handle hndl, const char[] error, any client) {
	while (SQL_FetchRow(hndl)) {
		g_ePlayerData[client][ppCell_number] = SQL_FetchIntByName(hndl, "cell_number");
		g_ePlayerData[client][ppTimes_in_jail] = SQL_FetchIntByName(hndl, "times_in_jail");
		g_ePlayerData[client][ppTime_spent_in_jail] = SQL_FetchIntByName(hndl, "time_spent_in_jail");
		SQL_FetchStringByName(hndl, "flags", g_ePlayerData[client][ppFlags], 255);
		if (g_ePlayerData[client][ppCell_number] != -1)
			putInCell(client, g_ePlayerData[client][ppCell_number]);
	}
}

public void loadJailSpawnPoints()
{
	char sRawMap[PLATFORM_MAX_PATH];
	char sMap[64];
	GetCurrentMap(sRawMap, sizeof(sRawMap));
	RemoveMapPath(sRawMap, sMap, sizeof(sMap));
	
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/rpg_Jail/%s.txt", sMap);
	
	Handle hFile = OpenFile(sPath, "r");
	
	char sBuffer[512];
	char sDatas[3][32];
	
	if (hFile != INVALID_HANDLE)
	{
		while (ReadFileLine(hFile, sBuffer, sizeof(sBuffer)))
		{
			ExplodeString(sBuffer, ";", sDatas, 3, 32);
			
			g_eJailSpawnPoints[g_iLoadedJail][gXPos] = StringToFloat(sDatas[0]);
			g_eJailSpawnPoints[g_iLoadedJail][gYPos] = StringToFloat(sDatas[1]);
			g_eJailSpawnPoints[g_iLoadedJail][gZPos] = StringToFloat(sDatas[2]);
			
			g_iLoadedJail++;
		}
		
		CloseHandle(hFile);
	}
	PrintToServer("Loaded %i Jail Spawn Points", g_iLoadedJail);
}

public void saveJailSpawnPoints()
{
	char sRawMap[PLATFORM_MAX_PATH];
	char sMap[64];
	GetCurrentMap(sRawMap, sizeof(sRawMap));
	RemoveMapPath(sRawMap, sMap, sizeof(sMap));
	
	CreateDirectory("configs/rpg_Jail", 511);
	
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/rpg_Jail/%s.txt", sMap);
	
	
	
	Handle hFile = OpenFile(sPath, "w");
	
	if (hFile != INVALID_HANDLE)
	{
		for (int i = 0; i < g_iLoadedJail; i++) {
			WriteFileLine(hFile, "%.2f;%.2f;%.2f;", g_eJailSpawnPoints[i][gXPos], g_eJailSpawnPoints[i][gYPos], g_eJailSpawnPoints[i][gZPos]);
		}
		
		CloseHandle(hFile);
	}
	
	if (!FileExists(sPath))
		LogError("Couldn't save item spawns to  file: \"%s\".", sPath);
}

public void AddJailPoints(int client)
{
	float pos[3];
	GetClientAbsOrigin(client, pos);
	
	TE_SetupGlowSprite(pos, g_iBlueGlow, 10.0, 1.0, 235);
	TE_SendToAll();
	
	g_eJailSpawnPoints[g_iLoadedJail][gXPos] = pos[0];
	g_eJailSpawnPoints[g_iLoadedJail][gYPos] = pos[1];
	g_eJailSpawnPoints[g_iLoadedJail][gZPos] = pos[2];
	g_iLoadedJail++;
	
	PrintToChat(client, "Added new jail cell at %.2f:%.2f:%.2f, for type: rpg_Jail", pos[0], pos[1], pos[2]);
	saveJailSpawnPoints();
}


public Action addJailCells(int client, int args) {
	addJailCellsMenu(client, args);
	return Plugin_Handled;
}

public Action addJailCellsMenu(int client, int args)
{
	char JailText[64];
	
	Format(JailText, sizeof(JailText), "Spawn: Jail (%i)", g_iLoadedJail);
	
	Handle panel = CreatePanel();
	SetPanelTitle(panel, "Add a Spawnpoint");
	DrawPanelText(panel, "x-x-x-x-x-x-x-x-x-x");
	DrawPanelItem(panel, JailText);
	DrawPanelText(panel, "-------------");
	DrawPanelItem(panel, "Show Spawns");
	DrawPanelItem(panel, "Close");
	DrawPanelText(panel, "x-x-x-x-x-x-x-x-x-x");
	
	
	SendPanelToClient(panel, client, addJailCellsMenuHandler, 30);
	
	CloseHandle(panel);
	return Plugin_Handled;
}

public int addJailCellsMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		if (item == 1) {
			AddJailPoints(client);
			addJailCellsMenu(client, 0);
		} else if (item == 2) {
			ShowSpawns();
			addJailCellsMenu(client, 0);
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void ShowSpawns() {
	for (int i = 0; i < g_iLoadedJail; i++) {
		float pos[3];
		pos[0] = g_eJailSpawnPoints[i][gXPos];
		pos[1] = g_eJailSpawnPoints[i][gYPos];
		pos[2] = g_eJailSpawnPoints[i][gZPos];
		TE_SetupGlowSprite(pos, g_iBlueGlow, 10.0, 1.0, 235);
		TE_SendToAll();
	}
}

stock bool isValidClient(int client) {
	return (1 <= client <= MaxClients && IsClientInGame(client));
}

public int Zone_OnClientEntry(int client, char[] zone) {
	if (StrEqual(zone, "JailExit")) {
		if (g_bIsInJail[client] && g_ePlayerData[client][ppCell_number] != -1) {
			tCrime_addCrime(client, tCrime_getCrime(client));
			escape(client);
		}
	}
} 