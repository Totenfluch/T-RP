#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <rpg_npc_core>

#pragma newdecls required

#define MAX_JOBS 256

Database g_DB;
char dbconfig[] = "gsxh_multiroot";

enum GlobalJobProperties {
	gJobId, 
	String:gJobname[128], 
	String:gJobdescription[512], 
	gMaxJobLevels, 
	gJobExperience, 
	float:gJobExperienceIncreasePercentage
}

int g_iLoadedJobs = 0;
int g_eLoadedJobs[MAX_JOBS][GlobalJobProperties];


enum playerJobProperties {
	String:pjJobname[128], 
	pjJobLevel, 
	pjJobExperience
}

int g_ePlayerJob[MAXPLAYERS + 1][playerJobProperties];


bool g_bProgressBarActive[MAXPLAYERS + 1];
int g_iProgressBarProgress[MAXPLAYERS + 1] =  { -1, ... };
int g_iProgressBarTarget[MAXPLAYERS + 1] =  { -1, ... };
char g_cProgressBarInfo[MAXPLAYERS + 1][64];

int g_iPlayerPrevButtons[MAXPLAYERS + 1];


public Plugin myinfo = 
{
	name = "RPG Jobs Core", 
	author = PLUGIN_AUTHOR, 
	description = "Adds Jobs to T-RPG", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart()
{
	char error[255];
	g_DB = SQL_Connect(dbconfig, true, error, sizeof(error));
	SQL_SetCharset(g_DB, "utf8");
	
	char createTableQuery[4096];
	Format(createTableQuery, sizeof(createTableQuery), "CREATE TABLE `t_rpg_jobs` ( `Id` BIGINT NULL AUTO_INCREMENT , `timestamp` TIMESTAMP on update CURRENT_TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP , `playerid` VARCHAR(20) NOT NULL , `playername` VARCHAR(36) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL , `jobname` VARCHAR(128) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL , `level` INT NOT NULL , `experience` INT NOT NULL , `flags` VARCHAR(64) NOT NULL , `special_flags` VARCHAR(64) NOT NULL , PRIMARY KEY (`Id`), UNIQUE (`playerid`)) ENGINE = InnoDB CHARSET=utf8 COLLATE utf8_bin;");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createTableQuery);
}

public void OnMapStart() {
	CreateTimer(0.1, refreshTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action refreshTimer(Handle Timer) {
	for (int client = 1; client < MAXPLAYERS; client++) {
		if (!isValidClient(client))
			continue;
		if (!g_bProgressBarActive[client])
			continue;
		if (++g_iProgressBarProgress[client] >= g_iProgressBarTarget[client] && g_iProgressBarTarget[client] != -1)
			completeProgressBar(client);
	}
}

public void OnClientAuthorized(int client) {
	loadClientJob(client);
	g_bProgressBarActive[client] = false;
	g_iProgressBarProgress[client] = -1;
	g_iProgressBarTarget[client] = -1;
	strcopy(g_cProgressBarInfo[client], 64, "");
}

public void loadClientJob(int client) {
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char loadJobQuery[512];
	Format(loadJobQuery, sizeof(loadJobQuery), "SELECT jobname,level,experience,flags,special_flags FROM t_rpg_jobs WHERE playerid = '%s';", playerid);
	SQL_TQuery(g_DB, SQLLoadJobQueryCallback, loadJobQuery, client);
}

public void registerJob(char jobname[128], char jobdescription[512], int maxJobLevels, int jobExperience, float jobExperienceIncreasePercentage) {
	strcopy(g_eLoadedJobs[g_iLoadedJobs][gJobname], 128, jobname);
	strcopy(g_eLoadedJobs[g_iLoadedJobs][gJobdescription], 512, jobdescription);
	g_eLoadedJobs[g_iLoadedJobs][gMaxJobLevels] = maxJobLevels;
	g_eLoadedJobs[g_iLoadedJobs][gJobExperience] = jobExperience;
	g_eLoadedJobs[g_iLoadedJobs][gJobExperienceIncreasePercentage] = jobExperienceIncreasePercentage;
	g_iLoadedJobs++;
}

public void leaveJob(int client){
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	char leaveJobQuery[1024];
	Format(leaveJobQuery, sizeof(leaveJobQuery), "DELETE FROM t_rpg_jobs WHERE playerid = '%s';", playerid);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, leaveJobQuery);
}

public void acceptJob(int client, char jobname[128]) {
	leaveJob(client);
	
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char playername[MAX_NAME_LENGTH + 8];
	GetClientName(client, playername, sizeof(playername));
	
	char clean_playername[MAX_NAME_LENGTH * 2 + 16];
	SQL_EscapeString(g_DB, playername, clean_playername, sizeof(clean_playername));
	
	char acceptJobQuery[1024];
	Format(acceptJobQuery, sizeof(acceptJobQuery), "INSERT INTO `t_rpg_jobs` (`Id`, `timestamp`, `playerid`, `playername`, `jobname`, `level`, `experience`, `flags`, `special_flags`) VALUES (NULL, CURRENT_TIMESTAMP, '%s', '%s', '%s', '1', '0', '', '');", playerid, clean_playername, jobname);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, acceptJobQuery);
	
	int jobId = findLoadedJobIdByName(jobname);
	if(jobId == -1)
		return;
	strcopy(g_ePlayerJob[client][pjJobname], 128, g_eLoadedJobs[jobId][gJobname]);
	g_ePlayerJob[client][pjJobLevel] = 1;
	g_ePlayerJob[client][pjJobExperience] = 0;
}

public void increaseExperience(int client, int amount, char jobname[128]){
	if (StrEqual(g_ePlayerJob[client][pjJobname], "")) return;
	
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	
	g_ePlayerJob[client][pjJobExperience] += amount;
	int jobId = findLoadedJobIdByName(jobname);
	if(jobId == -1)
		return;
	while((g_ePlayerJob[client][pjJobExperience] >= g_eLoadedJobs[jobId][gJobExperience] * (g_ePlayerJob[client][pjJobLevel] * g_eLoadedJobs[jobId][gJobExperienceIncreasePercentage])) && g_ePlayerJob[client][pjJobLevel] <= g_eLoadedJobs[jobId][gMaxJobLevels]){
		g_ePlayerJob[client][pjJobExperience] -= g_eLoadedJobs[jobId][gJobExperience] * (g_ePlayerJob[client][pjJobLevel] * g_eLoadedJobs[jobId][gJobExperienceIncreasePercentage]);
		g_ePlayerJob[client][pjJobLevel]++;
		triggerLevelUp(client, jobname);
	}
	
	char updateLevelQuery[512];
	Format(updateLevelQuery, sizeof(updateLevelQuery), "UPDATE t_rpg_jobs SET level = %i WHERE playerid = '%s'", g_ePlayerJob[client][pjJobLevel], playerid);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateLevelQuery);
	
	char updateExperienceQuery[512];
	Format(updateExperienceQuery, sizeof(updateExperienceQuery), "UPDATE t_rpg_jobs SET experience = %i WHERE playerid = '%s'", g_ePlayerJob[client][pjJobExperience], playerid);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateExperienceQuery);
}

public void triggerLevelUp(int client, char jobname[128]){
	// Notify observers
}

public void SQLLoadJobQueryCallback(Handle owner, Handle hndl, const char[] error, any data) {
	while (SQL_FetchRow(hndl)) {
		SQL_FetchStringByName(hndl, "jobname", g_ePlayerJob[data][pjJobname], 128);
		g_ePlayerJob[data][pjJobLevel] = SQL_FetchIntByName(hndl, "level");
		g_ePlayerJob[data][pjJobExperience] = SQL_FetchIntByName(hndl, "experience");
	}
}

public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, any data) {
	if (!StrEqual(error, ""))
		LogError(error);
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon, int &tickcount) {
	if (IsClientInGame(client) && IsPlayerAlive(client) && g_bProgressBarActive[client]) {
		if (!(g_iPlayerPrevButtons[client] & IN_FORWARD) && iButtons & IN_FORWARD)
			interruptProgressBar(client);
		if (!(g_iPlayerPrevButtons[client] & IN_BACK) && iButtons & IN_BACK)
			interruptProgressBar(client);
		if (!(g_iPlayerPrevButtons[client] & IN_LEFT) && iButtons & IN_LEFT)
			interruptProgressBar(client);
		if (!(g_iPlayerPrevButtons[client] & IN_RIGHT) && iButtons & IN_RIGHT)
			interruptProgressBar(client);
		if (!(g_iPlayerPrevButtons[client] & IN_DUCK) && iButtons & IN_DUCK)
			interruptProgressBar(client);
		
		g_iPlayerPrevButtons[client] = iButtons;
	}
	
}

public void startProgress(int client, float time, char info[64]) {
	SetEntPropFloat(client, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
	SetEntProp(client, Prop_Send, "m_iProgressBarDuration", time);
	g_bProgressBarActive[client] = true;
	g_iProgressBarProgress[client] = 0;
	time *= 10;
	int target = RoundToNearest(time);
	g_iProgressBarTarget[client] = target;
}

public void interruptProgressBar(int client) {
	g_bProgressBarActive[client] = false;
	g_iProgressBarProgress[client] = -1;
	g_iProgressBarTarget[client] = -1;
	strcopy(g_cProgressBarInfo[client], 64, "");
	PrintHintText(client, "Interrupted Action");
}

public void completeProgressBar(int client) {
	g_bProgressBarActive[client] = false;
	g_iProgressBarProgress[client] = -1;
	g_iProgressBarTarget[client] = -1;
	char info[64];
	strcopy(info, 64, g_cProgressBarInfo[client]);
	// FIRE ME TO EVERYONE DARLING with the info we need.... to do stuff.....
}

public int findLoadedJobIdByName(char jobname[128]){
	for (int i = 0; i < g_iLoadedJobs; i++){
		if(StrEqual(g_eLoadedJobs[i][gJobname], jobname))
			return i;
	}
	return -1;
}

stock bool isValidClient(int client) {
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client))
		return false;
	
	return true;
}


