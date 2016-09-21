
#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <rpg_jobs_core>
#include <multicolors>
#include <tConomy>
#include <tCrime>
#include <smlib>

#pragma newdecls required

#define MAX_PLANTS 3

char dbconfig[] = "missions";
Database g_DB;

public Plugin myinfo = 
{
	name = "", 
	author = PLUGIN_AUTHOR, 
	description = "", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

enum plantProperties {
	String:pOwner[20], 
	pState, 
	pTime, 
	String:pFlags[64], 
	Float:pPos_x, 
	Float:pPos_y, 
	Float:pPos_z
}

int g_ePlayerPlants[MAXPLAYERS + 1][MAX_PLANTS][plantProperties];
int g_iPlayerSeeds[MAXPLAYERS + 1];
int g_iPlayerPlanted[MAXPLAYERS + 1];


public void OnPluginStart() {
	RegConsoleCmd("sm_plant", cmdPlantCommand, "plants drugs");
	
	char error[255];
	g_DB = SQL_Connect(dbconfig, true, error, sizeof(error));
	SQL_SetCharset(g_DB, "utf8");
	
	char CreateTableQuery[4096];
	Format(CreateTableQuery, sizeof(CreateTableQuery), "CREATE TABLE IF NOT EXISTS t_rpg_drugs` ( `playerid` VARCHAR(20) NOT NULL , `state` INT NOT NULL , `time` INT NOT NULL , `flags` VARCHAR(64) NOT NULL , `pos_x` FLOAT NOT NULL , `pos_y` FLOAT NOT NULL , `pos_z` FLOAT NOT NULL ) ENGINE = InnoDB CHARSET=utf8 COLLATE utf8_bin;");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, CreateTableQuery);
}

public void OnMapStart() {
	loadPlants();
}

public void loadPlants() {
	char loadPlantsQuery[512];
	Format(loadPlantsQuery, sizeof(loadPlantsQuery), "SELECT playerid,state,time,flags,pos_x,pos_y,pos_z FROM t_rpg_drugs;");
	SQL_TQuery(g_DB, SQLLoadPlantsQuery, loadPlantsQuery);
}

public void SQLLoadPlantsQuery(Handle owner, Handle hndl, const char[] error, any data) {
	while (SQL_FetchRow(hndl)) {
		char plantowner[20];
		SQL_FetchStringByName(hndl, "playerid", plantowner, sizeof(plantowner));
		int state = SQL_FetchIntByName(hndl, "state");
		int time = SQL_FetchIntByName(hndl, "time");
		char flags[64];
		SQL_FetchStringByName(hndl, "flags", flags, sizeof(flags));
		float pos[3];
		pos[0] = SQL_FetchFloatByName(hndl, "pos_x");
		pos[1] = SQL_FetchFloatByName(hndl, "pos_y");
		pos[2] = SQL_FetchFloatByName(hndl, "pos_z");
		// Spawn plants
	}
}

public Action cmdPlantCommand(int client, int args) {
	if (g_iPlayerSeeds[client] > 0)
		g_iPlayerSeeds[client]--;
	else
		return Plugin_Handled;
	
	float pos[3];
	GetClientAbsOrigin(client, pos);
	
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char createPlantQuery[512];
	Format(createPlantQuery, sizeof(createPlantQuery), "INSERT INTO `t_rpg_drugs` (`playerid`, `state`, `time`, `flags`, `pos_x`, `pos_y`, `pos_z`) VALUES ('%s', '0', '0', '', '%.2f', '%f.2', '%f.2');", playerid, pos[0], pos[1], pos[2]);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createPlantQuery);
	
	int drugPlant = CreateEntityByName("prop_dynamic_override");
	PrecacheModel("models/props/de_inferno/bushgreensmall.mdl", true);
	SetEntityModel(drugPlant, "models/props/de_inferno/bushgreensmall.mdl");
	DispatchKeyValue(drugPlant, "Solid", "6");
	SetEntProp(drugPlant, Prop_Send, "m_nSolidType", 6);
	DispatchSpawn(drugPlant);
	TeleportEntity(drugPlant, pos, NULL_VECTOR, NULL_VECTOR);
	
	strcopy(g_ePlayerPlants[client][g_iPlayerPlanted[client]][pOwner], 20, playerid);
	g_ePlayerPlants[client][g_iPlayerPlanted[client]][pState] = 0;
	g_ePlayerPlants[client][g_iPlayerPlanted[client]][pTime] = 0;
	g_ePlayerPlants[client][g_iPlayerPlanted[client]][pPos_x] = pos[0];
	g_ePlayerPlants[client][g_iPlayerPlanted[client]][pPos_y] = pos[1];
	g_ePlayerPlants[client][g_iPlayerPlanted[client]][pPos_z] = pos[2];
	g_iPlayerPlanted[client]++;
	return Plugin_Handled;
}


stock bool isValidClient(int client) {
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client))
		return false;
	
	return true;
}

public int getClientFromAuth2(char[] auth2) {
	for (int i = 1; i < MAXPLAYERS; i++) {
		if (isValidClient(i)) {
			char playerid[20];
			GetClientAuthId(i, AuthId_Steam2, playerid, sizeof(playerid));
			if (StrEqual(auth2, playerid)) {
				return i;
			}
		}
	}
	return -1;
}

public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, any data) {
	if (!StrEqual(error, ""))
		LogError(error);
}
