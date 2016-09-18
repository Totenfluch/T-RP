#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <smlib>

#pragma newdecls required

char dbconfig[] = "gsxh_multiroot";
Database g_DB;


enum crimeProperties {
	cCrime,
	String:cFlags[64]
}

int g_ePlayerCrime[MAXPLAYERS + 1][crimeProperties];

public Plugin myinfo = 
{
	name = "tCrime",
	author = PLUGIN_AUTHOR,
	description = "Crime System for T-RP",
	version = PLUGIN_VERSION,
	url = "http://ggc-base.de"
};

public void OnPluginStart()
{
	char error[255];
	g_DB = SQL_Connect(dbconfig, true, error, sizeof(error));
	SQL_SetCharset(g_DB, "utf8");
	
	char CreateCrimeTableQuery[512];
	Format(CreateCrimeTableQuery, sizeof(CreateCrimeTableQuery), "CREATE TABLE IF NOT EXISTS `t_rpg_tcrime` ( `Id` BIGINT NULL DEFAULT NULL AUTO_INCREMENT , `timestamp` TIMESTAMP on update CURRENT_TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , `playername` VARCHAR(40) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL , `playerid` VARCHAR(20) NOT NULL , `crime` INT NOT NULL , `flags` VARCHAR(64) NOT NULL , PRIMARY KEY (`Id`, `playerid`)) ENGINE = InnoDB CHARSET=utf8 COLLATE utf8_bin;");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, CreateCrimeTableQuery);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	/*
		Get the crime amount of client
		@Param1 -> client index

		@return crime amount
	*/
	CreateNative("tCrime_getCrime", Native_getCrime);	
	
	/*
		Sets the Crime amount on client
		@Param1 -> client index
		@Param2 -> crime amount

		@return -
	*/
	CreateNative("tCrime_setCrime", Native_setCrime);	
	
	/*
		Adds the Crime amount on client
		@Param1 -> client index
		@Param2 -> crime amount

		@return -
	*/
	CreateNative("tCrime_addCrime", Native_addCrime);	
	
	/*
		Removes the Crime amount on client
		@Param1 -> client index
		@Param2 -> crime amount

		@return -
	*/
	CreateNative("tCrime_removeCrime", Native_removeCrime);	
	
	/*
		Adds flags to the client
		@Param1 -> client index
		@Param2 -> char flags[64]

		@return -
	*/
	CreateNative("tCrime_addFlags", Native_addFlags);
	
	/*
		Removes flags from the client
		@Param1 -> client index
		@Param2 -> char flags[64]

		@return -
	*/
	CreateNative("tCrime_removeFlags", Native_removeFlags);	
	
	/*
		Clears flags from the client
		@Param1 -> client index

		@return -
	*/
	CreateNative("tCrime_clearFlags", Native_clearFlags);	
	
	/*
		Sets flags from the client
		@Param1 -> client index

		@return -
	*/
	CreateNative("tCrime_setFlags", Native_setFlags);	
	
	/*
		Sets flags from the client
		@Param1 -> client index
		@Param2 -> char flagsbuffer[64]
		
		@return -
	*/
	CreateNative("tCrime_getFlags", Native_getFlags);	
}

public int Native_getCrime(Handle plugin, int numParams) {
	return g_ePlayerCrime[GetNativeCell(1)][cCrime];
}

public int Native_setCrime(Handle plugin, int numParams) {
	setCrime(GetNativeCell(1), GetNativeCell(2));
}

public int Native_addCrime(Handle plugin, int numParams) {
	increaseCrime(GetNativeCell(1), GetNativeCell(2));
}

public int Native_removeCrime(Handle plugin, int numParams) {
	decreaseCrime(GetNativeCell(1), GetNativeCell(2));
}

public int Native_addFlags(Handle plugin, int numParams) {
	char flagBuffer[64];
	GetNativeString(2, flagBuffer, sizeof(flagBuffer));
	
	addFlags(GetNativeCell(1), flagBuffer);
}

public int Native_removeFlags(Handle plugin, int numParams) {
	char flagBuffer[64];
	GetNativeString(2, flagBuffer, sizeof(flagBuffer));
	
	removeFlags(GetNativeCell(1), flagBuffer);
}

public int Native_setFlags(Handle plugin, int numParams) {
	char flagBuffer[64];
	GetNativeString(2, flagBuffer, sizeof(flagBuffer));
	
	setFlags(GetNativeCell(1), flagBuffer);
}

public int Native_clearFlags(Handle plugin, int numParams) {
	clearFlags(GetNativeCell(1));
}


public int Native_getFlags(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	char flags[64];
	strcopy(flags, 64, g_ePlayerCrime[client][cFlags]);
	SetNativeString(2, flags, sizeof(flags), false);
}

public void OnClientAuthorized(int client){
	g_ePlayerCrime[client][cCrime] = -1;
	strcopy(g_ePlayerCrime[client][cFlags], 64, "");
	
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char playername[MAX_NAME_LENGTH + 8];
	GetClientName(client, playername, sizeof(playername));
	
	char clean_playername[MAX_NAME_LENGTH * 2 + 16];
	SQL_EscapeString(g_DB, playername, clean_playername, sizeof(clean_playername));
	
	char insertPlayerQuery[512];
	Format(insertPlayerQuery, sizeof(insertPlayerQuery), "INSERT IGNORE INTO `t_rpg_tcrime` (`Id`, `timestamp`, `playername`, `playerid`, `crime`, `flags`) VALUES (NULL, CURRENT_TIMESTAMP, '%s', '%s', '0', '');", clean_playername, playerid);
	SQL_TQuery(g_DB, SQLLoadCrimeCallback, insertPlayerQuery, client);
	
	CreateTimer(1.0, loadCrime, client);
}

public void OnClientDisconnect(int client){
	g_ePlayerCrime[client][cCrime] = -1;
	strcopy(g_ePlayerCrime[client][cFlags], 64, "");
}

public Action loadCrime(Handle Timer, int client){
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char LoadCrimeQuery[512];
	Format(LoadCrimeQuery, sizeof(LoadCrimeQuery), "SELECT crime,flags FROM t_rpg_tcrime WHERE playerid = '%s'", playerid);
	SQL_TQuery(g_DB, SQLLoadCrimeCallback, LoadCrimeQuery, client);
}

public void SQLLoadCrimeCallback(Handle owner, Handle hndl, const char[] error, any client) {
	while (SQL_FetchRow(hndl)) {
		SQL_FetchStringByName(hndl, "flags", g_ePlayerCrime[client][cFlags], 64);
		g_ePlayerCrime[client][cCrime] = SQL_FetchIntByName(hndl, "crime");
	}
}

public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, any data) {
	if (!StrEqual(error, ""))
		LogError(error);
}

public void increaseCrime(int client, int amount){
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	g_ePlayerCrime[client][cCrime] += amount;
	
	char updateCrimeQuery[512];
	Format(updateCrimeQuery, sizeof(updateCrimeQuery), "UPDATE t_rpg_tcrime SET crime = %i WHERE playerid = '%s'", g_ePlayerCrime[client][cCrime], playerid);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateCrimeQuery);
}

public void decreaseCrime(int client, int amount){
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	g_ePlayerCrime[client][cCrime] -= amount;
	
	char updateCrimeQuery[512];
	Format(updateCrimeQuery, sizeof(updateCrimeQuery), "UPDATE t_rpg_tcrime SET crime = %i WHERE playerid = '%s'", g_ePlayerCrime[client][cCrime], playerid);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateCrimeQuery);
}

public void setCrime(int client, int amount){
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	g_ePlayerCrime[client][cCrime] = amount;
	
	char updateCrimeQuery[512];
	Format(updateCrimeQuery, sizeof(updateCrimeQuery), "UPDATE t_rpg_tcrime SET crime = %i WHERE playerid = '%s'", g_ePlayerCrime[client][cCrime], playerid);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateCrimeQuery);
}

public void addFlags(int client, char flags[64]){
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char finalFlags[64];
	Format(finalFlags, sizeof(finalFlags), "%s%s", g_ePlayerCrime[client][cFlags], flags);
	strcopy(g_ePlayerCrime[client][cFlags], 64, finalFlags);
	
	char updateFlagsQuery[512];
	Format(updateFlagsQuery, sizeof(updateFlagsQuery), "UPDATE t_rpg_tcrime SET flags = %s WHERE playerid = '%s'", g_ePlayerCrime[client][cFlags], playerid);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateFlagsQuery);
}

public void removeFlags(int client, char flags[64]){
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	ReplaceString(g_ePlayerCrime[client][cFlags], 64, flags, "", true);
	
	char updateFlagsQuery[512];
	Format(updateFlagsQuery, sizeof(updateFlagsQuery), "UPDATE t_rpg_tcrime SET flags = %s WHERE playerid = '%s'", g_ePlayerCrime[client][cFlags], playerid);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateFlagsQuery);
}

public void clearFlags(int client){
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	strcopy(g_ePlayerCrime[client][cFlags], 64, "");
	
	char updateFlagsQuery[512];
	Format(updateFlagsQuery, sizeof(updateFlagsQuery), "UPDATE t_rpg_tcrime SET flags = %s WHERE playerid = '%s'", g_ePlayerCrime[client][cFlags], playerid);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateFlagsQuery);
}

public void setFlags(int client, char flags[64]){
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	strcopy(g_ePlayerCrime[client][cFlags], 64, flags);
	
	char updateFlagsQuery[512];
	Format(updateFlagsQuery, sizeof(updateFlagsQuery), "UPDATE t_rpg_tcrime SET flags = %s WHERE playerid = '%s'", g_ePlayerCrime[client][cFlags], playerid);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateFlagsQuery);
}


stock bool isValidClient(int client) {
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client))
		return false;
	
	return true;
}