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
#include <smlib>
#include <rpg_npc_core>
#include <multicolors>
#include <tStocks>

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
	Float:gJobExperienceIncreasePercentage
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

char g_cPlayerJobInfo[MAXPLAYERS + 1][128];

Handle g_hOnJobAccepted;
Handle g_hOnJobQuit;
Handle g_hOnJobLevelUp;
Handle g_hOnProgressBarFinished;
Handle g_hOnProgressBarInterrupted;

public Plugin myinfo = 
{
	name = "[T-RP] Jobs Core", 
	author = PLUGIN_AUTHOR, 
	description = "Adds Jobs to T-RPG", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart()
{
	char error[255];
	g_DB = SQL_Connect(dbconfig, true, error, sizeof(error));
	SQL_SetCharset(g_DB, "utf8");
	
	char createTableQuery[4096];
	Format(createTableQuery, sizeof(createTableQuery), "CREATE TABLE IF NOT EXISTS `t_rpg_jobs` ( `Id` BIGINT NOT NULL AUTO_INCREMENT , `timestamp` TIMESTAMP on update CURRENT_TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP , `playerid` VARCHAR(20) NOT NULL , `playername` VARCHAR(36) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL , `jobname` VARCHAR(128) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL , `level` INT NOT NULL , `experience` INT NOT NULL , `flags` VARCHAR(64) NOT NULL , `special_flags` VARCHAR(64) NOT NULL , PRIMARY KEY (`Id`), UNIQUE (`playerid`, `jobname`)) ENGINE = InnoDB CHARSET=utf8 COLLATE utf8_bin;");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createTableQuery);
	
	Format(createTableQuery, sizeof(createTableQuery), "CREATE TABLE IF NOT EXISTS `t_rpg_jobs_cooldowns` ( `playerid` VARCHAR(20) NOT NULL , `startcd` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , `endcd` TIMESTAMP NOT NULL , PRIMARY KEY (`playerid`)) ENGINE = InnoDB;");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createTableQuery);
	
	RegAdminCmd("sm_givexp", cmdGiveXp, ADMFLAG_ROOT, "Gives XP for the currently Active Job");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	/*
		Register a new job - do this OnPluginStart
		
		@Param1 -> char jobname[128]
		@Param2 -> char jobdescription[512]
		@Param3 -> int maxJobLevels
		@Param4 -> int jobExperiencePerLevel
		@Param5 -> float jobExperienceIncreasePercentagePerLevel
		
		
		@return none
	*/
	CreateNative("jobs_registerJob", Native_registerJob);
	
	/*
		Gets a clients job
		
		@Param1 -> int client
		@Param2 -> char jobBuffer[128]
		
		@return none
	*/
	CreateNative("jobs_getActiveJob", Native_getActiveJob);
	
	/*
		Check if the given job is the Active
		
		@Param1 -> int client
		@Param2 -> char job[128]
		
		@return true or false
	*/
	CreateNative("jobs_isActiveJob", Native_isActiveJob);
	
	/*
		Get current Job experience
		
		@Param1 -> int client
		
		@return job_experience
	*/
	CreateNative("jobs_getExperience", Native_getExperience);
	
	/*
		add to current job experience
		
		@Param1 -> int client
		@Param2 -> int amount
		@Param3- > char jobname[128];
		
		@return none
	*/
	CreateNative("jobs_addExperience", Native_addExperience);
	
	/*
		removes experience from the client
		
		@Param1 -> int client
		@Param2 -> int amount
		@Param3- > char jobname[128];
		
		@return none
	*/
	CreateNative("jobs_removeExperience", Native_removeExperience);
	
	/*
		Gets the Experience needed for the next level
		
		@Param1 -> int client
		
		@return none
	*/
	CreateNative("jobs_getExperienceForNextLevel", Native_getExperienceForNextLevel);
	
	/*
		Get current Job level
		
		@Param1 -> int client
		
		@return int current_job_level
	*/
	CreateNative("jobs_getLevel", Native_getLevel);
	
	/*
		Starts the progressbar
		
		@Param1 -> int client
		@Param2 -> float time
		@Param3 -> char info[64]
		
		@return none
	*/
	CreateNative("jobs_startProgressBar", Native_startProgressBar);
	
	/*
		Stops the progressbar
		
		@Param1 -> int client
		
		@return none
	*/
	CreateNative("jobs_stopProgressBar", Native_stopProgressBar);
	
	/*
		Returns if the Progressbar is active
		
		@Param1 -> int client
		
		@return true or false
	*/
	CreateNative("jobs_isInProgressBar", Native_isInProgressBar);
	
	/*
		Gives a Job to a client
		
		@Param1 -> int client
		@Param2 -> char jobname[128]
		
		@return none
	*/
	CreateNative("jobs_giveJob", Native_giveJob);
	
	/*
		Quits the current job of the client
		
		@Param1 -> int client
		@Param2 -> char jobname[128]
		
		@return none
	*/
	CreateNative("jobs_quitJob", Native_quitJob);
	
	/*
		Sets the Client Job info
		
		@Param1 -> int client
		@Param2 -> char info[128]
		
		@return none
	*/
	CreateNative("jobs_setCurrentInfo", Native_setCurrentInfo);
	
	/*
		Get the Client Job info
		
		@Param1 -> int client
		@Param2 -> char info[128]
		
		@return none
	*/
	CreateNative("jobs_getCurrentInfo", Native_getCurrentInfo);
	
	/*
		Forward on Job Accepted
		
		@Param1 -> int client
		@Param3 -> char jobname[128]
		
		@return -
	*/
	g_hOnJobAccepted = CreateGlobalForward("jobs_OnJobAccepted", ET_Ignore, Param_Cell, Param_String);
	
	/*
		Forward on Job Quit
		
		@Param1 -> int client
		@Param3 -> char jobname[128]
		
		@return -
	*/
	g_hOnJobQuit = CreateGlobalForward("jobs_OnJobQuit", ET_Ignore, Param_Cell, Param_String);
	
	/*
		Forward on Client job levelup
		
		@Param1 -> int client
		@Param2 -> int newLevel
		@Param3 -> char jobname[128]
		
		@return -
	*/
	g_hOnJobLevelUp = CreateGlobalForward("jobs_OnJobLevelUp", ET_Ignore, Param_Cell, Param_Cell, Param_String);
	
	/*
		Forward on Client ProgressBarFinished
		
		@Param1 -> int client
		@Param3 -> char info[64]
		
		@return -
	*/
	g_hOnProgressBarFinished = CreateGlobalForward("jobs_OnProgressBarFinished", ET_Ignore, Param_Cell, Param_String);
	
	/*
		Forward on Client ProgressBarInterrupted
		
		@Param1 -> int client
		@Param2 -> char info[64]
		
		@return -
	*/
	g_hOnProgressBarInterrupted = CreateGlobalForward("jobs_OnProgressBarInterrupted", ET_Ignore, Param_Cell, Param_String);
	
}

public int Native_registerJob(Handle plugin, int numParams) {
	char jobname[128];
	GetNativeString(1, jobname, sizeof(jobname));
	char jobdescription[512];
	GetNativeString(2, jobdescription, sizeof(jobdescription));
	int maxJobLevel = GetNativeCell(3);
	int jobExperiencePerLevel = GetNativeCell(4);
	float jobExperienceIncreasePercentagePerLevel = GetNativeCell(5);
	registerJob(jobname, jobdescription, maxJobLevel, jobExperiencePerLevel, jobExperienceIncreasePercentagePerLevel);
}

public int Native_getActiveJob(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	SetNativeString(2, g_ePlayerJob[client][pjJobname], 128);
}

public int Native_isActiveJob(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	char jobBuffer[128];
	GetNativeString(2, jobBuffer, sizeof(jobBuffer));
	return StrEqual(jobBuffer, g_ePlayerJob[client][pjJobname]);
}

public int Native_getExperience(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	return g_ePlayerJob[client][pjJobExperience];
}

public int Native_addExperience(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	int amount = GetNativeCell(2);
	char jobBuffer[128];
	GetNativeString(3, jobBuffer, sizeof(jobBuffer));
	increaseExperience(client, amount, jobBuffer);
}

public int Native_removeExperience(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	int amount = GetNativeCell(2);
	char jobBuffer[128];
	GetNativeString(3, jobBuffer, sizeof(jobBuffer));
	decreaseExperience(client, amount, jobBuffer);
}

public int Native_getLevel(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	return g_ePlayerJob[client][pjJobLevel];
}

public int Native_startProgressBar(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	int time = GetNativeCell(2);
	char info[64];
	GetNativeString(3, info, sizeof(info));
	startProgress(client, time, info);
}

public int Native_stopProgressBar(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	interruptProgressBar(client);
}

public int Native_isInProgressBar(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	return g_bProgressBarActive[client];
}

public int Native_giveJob(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	char jobName[128];
	GetNativeString(2, jobName, sizeof(jobName));
	acceptJob(client, jobName);
}

public int Native_quitJob(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	leaveJob(client);
}

public int Native_getExperienceForNextLevel(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	if (StrEqual(g_ePlayerJob[client][pjJobname], ""))
		return -1;
	
	char jobname[128];
	strcopy(jobname, 128, g_ePlayerJob[client][pjJobname]);
	int jobId = findLoadedJobIdByName(jobname);
	if (jobId == -1)
		return -1;
	
	if (g_ePlayerJob[client][pjJobLevel] >= g_eLoadedJobs[jobId][gMaxJobLevels])
		return 0;
	
	float level = float(g_ePlayerJob[client][pjJobLevel]);
	int iExperienceNeeded = RoundToNearest(g_eLoadedJobs[jobId][gJobExperience] * (Pow(level, g_eLoadedJobs[jobId][gJobExperienceIncreasePercentage])));
	
	return iExperienceNeeded;
}

public int Native_setCurrentInfo(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	char info[128];
	GetNativeString(2, info, sizeof(info));
	strcopy(g_cPlayerJobInfo[client], 128, info);
}

public int Native_getCurrentInfo(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	SetNativeString(2, g_cPlayerJobInfo[client], 128);
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
		char progressBarPrint[512];
		float split = g_iProgressBarTarget[client] / 50.0;
		float fill = 0.0;
		int bars = 50;
		
		while (fill < g_iProgressBarProgress[client]) {
			fill += split;
			bars--;
		}
		
		while (bars-- > 0)
			Format(progressBarPrint, sizeof(progressBarPrint), "%s|", progressBarPrint);
		
		
		int diff = g_iProgressBarTarget[client] - g_iProgressBarProgress[client];
		float timeLeft = diff / 10.0;
		
		Format(progressBarPrint, sizeof(progressBarPrint), "<font size='16'>%s\n~~~~~~~~~ | %.2f | ~~~~~~~~~\n%s\n%s</font>", progressBarPrint, timeLeft, progressBarPrint, g_cProgressBarInfo[client]);
		PrintHintText(client, progressBarPrint);
		if (++g_iProgressBarProgress[client] >= g_iProgressBarTarget[client] && g_iProgressBarTarget[client] != -1)
			completeProgressBar(client);
	}
}

public void OnClientAuthorized(int client) {
	resetJob(client);
	loadClientJob(client);
	g_bProgressBarActive[client] = false;
	g_iProgressBarProgress[client] = -1;
	g_iProgressBarTarget[client] = -1;
	strcopy(g_cProgressBarInfo[client], 64, "");
	strcopy(g_cPlayerJobInfo[client], 64, "");
}

public void loadClientJob(int client) {
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char loadJobQuery[512];
	Format(loadJobQuery, sizeof(loadJobQuery), "SELECT jobname,level,experience,flags,special_flags FROM t_rpg_jobs WHERE playerid = '%s' AND flags != 'i';", playerid);
	SQL_TQuery(g_DB, SQLLoadJobQueryCallback, loadJobQuery, GetClientUserId(client));
}

public void registerJob(char jobname[128], char jobdescription[512], int maxJobLevels, int jobExperience, float jobExperienceIncreasePercentage) {
	for (int i = 0; i < g_iLoadedJobs; i++)
	if (StrEqual(g_eLoadedJobs[i][gJobname], jobname))
		return;
	
	
	strcopy(g_eLoadedJobs[g_iLoadedJobs][gJobname], 128, jobname);
	strcopy(g_eLoadedJobs[g_iLoadedJobs][gJobdescription], 512, jobdescription);
	g_eLoadedJobs[g_iLoadedJobs][gMaxJobLevels] = maxJobLevels;
	g_eLoadedJobs[g_iLoadedJobs][gJobExperience] = jobExperience;
	g_eLoadedJobs[g_iLoadedJobs][gJobExperienceIncreasePercentage] = jobExperienceIncreasePercentage;
	g_iLoadedJobs++;
}

public void leaveJob(int client) {
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	char leaveJobQuery[1024];
	//Format(leaveJobQuery, sizeof(leaveJobQuery), "DELETE FROM t_rpg_jobs WHERE playerid = '%s';", playerid);
	Format(leaveJobQuery, sizeof(leaveJobQuery), "UPDATE t_rpg_jobs SET flags = 'i' WHERE playerid = '%s' AND jobname = '%s';", playerid, g_ePlayerJob[client][pjJobname]);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, leaveJobQuery);
	
	Call_StartForward(g_hOnJobQuit);
	Call_PushCell(client);
	Call_PushString(g_ePlayerJob[client][pjJobname]);
	Call_Finish();
	
	resetJob(client);
}

public void resetJob(int client) {
	strcopy(g_ePlayerJob[client][pjJobname], 128, "");
	g_ePlayerJob[client][pjJobLevel] = -1;
	g_ePlayerJob[client][pjJobExperience] = -1;
}

public void acceptJob(int client, char jobname[128]) {
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char deleteOldDataQuery[512];
	Format(deleteOldDataQuery, sizeof(deleteOldDataQuery), "DELETE FROM t_rpg_jobs_cooldowns WHERE endcd < CURRENT_TIMESTAMP();");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, deleteOldDataQuery);
	
	char findCooldownQuery[512];
	Format(findCooldownQuery, sizeof(findCooldownQuery), "SELECT TIMEDIFF(endcd, CURRENT_TIMESTAMP()) as timeleft FROM t_rpg_jobs_cooldowns WHERE playerid = '%s';", playerid);
	
	DataPack prepInfos;
	prepInfos = CreateDataPack();
	prepInfos.WriteCell(GetClientUserId(client));
	prepInfos.WriteString(jobname);
	
	SQL_TQuery(g_DB, SQLFindCooldownQuery, findCooldownQuery, prepInfos);
}

public void SQLFindCooldownQuery(Handle owner, Handle hndl, const char[] error, DataPack prepInfos) {
	prepInfos.Reset();
	int client = GetClientOfUserId(prepInfos.ReadCell());
	char jobname[128];
	prepInfos.ReadString(jobname, sizeof(jobname));
	if (!isValidClient(client))
		return;
	
	bool canAcceptJob = true;
	while (SQL_FetchRow(hndl)) {
		char timediff[64];
		SQL_FetchStringByName(hndl, "timeleft", timediff, sizeof(timediff));
		PrintToChat(client, "[-T-] You have to wait %s until you can take another job", timediff);
		canAcceptJob = false;
	}
	
	if (canAcceptJob)
		performAcceptJob(client, jobname);
}

public void performAcceptJob(int client, char jobname[128]) {
	leaveJob(client);
	
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char playername[MAX_NAME_LENGTH + 8];
	GetClientName(client, playername, sizeof(playername));
	
	char clean_playername[MAX_NAME_LENGTH * 2 + 16];
	SQL_EscapeString(g_DB, playername, clean_playername, sizeof(clean_playername));
	
	char acceptJobQuery[1024];
	Format(acceptJobQuery, sizeof(acceptJobQuery), "INSERT IGNORE INTO `t_rpg_jobs` (`Id`, `timestamp`, `playerid`, `playername`, `jobname`, `level`, `experience`, `flags`, `special_flags`) VALUES (NULL, CURRENT_TIMESTAMP, '%s', '%s', '%s', '1', '0', '', '');", playerid, clean_playername, jobname);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, acceptJobQuery);
	
	Format(acceptJobQuery, sizeof(acceptJobQuery), "UPDATE t_rpg_jobs SET flags = '' WHERE playerid = '%s' AND jobname = '%s';", playerid, jobname);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, acceptJobQuery);
	
	
	int jobId = findLoadedJobIdByName(jobname);
	if (jobId == -1)
		return;
	
	strcopy(g_ePlayerJob[client][pjJobname], 128, jobname);
	g_ePlayerJob[client][pjJobLevel] = 1;
	g_ePlayerJob[client][pjJobExperience] = 0;
	
	Call_StartForward(g_hOnJobAccepted);
	Call_PushCell(client);
	Call_PushString(g_ePlayerJob[client][pjJobname]);
	Call_Finish();
	
	int cooldown = 60;
	if (isVipRank2(client)) {
		cooldown = 20;
	} else if (isVipRank1(client)) {
		cooldown = 30;
	}
	
	char setCooldownQuery[1024];
	Format(setCooldownQuery, sizeof(setCooldownQuery), "INSERT IGNORE INTO `t_rpg_jobs_cooldowns` (`playerid`, `startcd`, `endcd`) VALUES ('%s', CURRENT_TIMESTAMP, TIMESTAMPADD(MINUTE,%i,CURRENT_TIMESTAMP))", playerid, cooldown);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, setCooldownQuery);
	loadClientJob(client);
}

public void increaseExperience(int client, int amount, char jobname[128]) {
	if (StrEqual(g_ePlayerJob[client][pjJobname], ""))return;
	if (!StrEqual(g_ePlayerJob[client][pjJobname], jobname))return;
	
	if (isVipRank2(client)) {
		amount = RoundToFloor(amount * 1.05);
	} else if (isVipRank1(client)) {
		amount = RoundToFloor(amount * 1.03);
	}
	
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	
	g_ePlayerJob[client][pjJobExperience] += amount;
	int jobId = findLoadedJobIdByName(jobname);
	if (jobId == -1)
		return;
	
	float level = float(g_ePlayerJob[client][pjJobLevel]);
	int iExperienceNeeded = RoundToNearest(g_eLoadedJobs[jobId][gJobExperience] * (Pow(level, g_eLoadedJobs[jobId][gJobExperienceIncreasePercentage])));
	
	while ((g_ePlayerJob[client][pjJobExperience] >= iExperienceNeeded) && g_ePlayerJob[client][pjJobLevel] <= g_eLoadedJobs[jobId][gMaxJobLevels]) {
		g_ePlayerJob[client][pjJobExperience] -= iExperienceNeeded;
		g_ePlayerJob[client][pjJobLevel]++;
		level = float(g_ePlayerJob[client][pjJobLevel]);
		iExperienceNeeded = RoundToNearest(g_eLoadedJobs[jobId][gJobExperience] * (Pow(level, g_eLoadedJobs[jobId][gJobExperienceIncreasePercentage])));
		triggerLevelUp(client, jobname);
	}
	
	CPrintToChat(client, "{olive}[%s] {green}Gained {olive}%i{green} experience!", g_ePlayerJob[client][pjJobname], amount);
	
	char updateLevelQuery[512];
	Format(updateLevelQuery, sizeof(updateLevelQuery), "UPDATE t_rpg_jobs SET level = %i WHERE playerid = '%s' AND jobname = '%s';", g_ePlayerJob[client][pjJobLevel], playerid, g_ePlayerJob[client][pjJobname]);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateLevelQuery);
	
	char updateExperienceQuery[512];
	Format(updateExperienceQuery, sizeof(updateExperienceQuery), "UPDATE t_rpg_jobs SET experience = %i WHERE playerid = '%s' AND jobname = '%s';", g_ePlayerJob[client][pjJobExperience], playerid, g_ePlayerJob[client][pjJobname]);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateExperienceQuery);
}

public void decreaseExperience(int client, int amount, char jobname[128]) {
	if (StrEqual(g_ePlayerJob[client][pjJobname], ""))return;
	if (!StrEqual(g_ePlayerJob[client][pjJobname], jobname))return;
	
	g_ePlayerJob[client][pjJobExperience] -= amount;
	
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char updateExperienceQuery[512];
	Format(updateExperienceQuery, sizeof(updateExperienceQuery), "UPDATE t_rpg_jobs SET experience = %i WHERE playerid = '%s' AND jobname = '%s';", g_ePlayerJob[client][pjJobExperience], playerid, g_ePlayerJob[client][pjJobname]);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateExperienceQuery);
}

public void triggerLevelUp(int client, char jobname[128]) {
	CPrintToChat(client, "{olive}[%s] {green}You have reached Level: {purple}%i{green}!", g_ePlayerJob[client][pjJobname], g_ePlayerJob[client][pjJobLevel]);
	Call_StartForward(g_hOnJobLevelUp);
	Call_PushCell(client);
	Call_PushCell(g_ePlayerJob[client][pjJobLevel]);
	Call_PushString(jobname);
	Call_Finish();
}

public void SQLLoadJobQueryCallback(Handle owner, Handle hndl, const char[] error, any data) {
	int client = GetClientOfUserId(data);
	while (SQL_FetchRow(hndl)) {
		SQL_FetchStringByName(hndl, "jobname", g_ePlayerJob[client][pjJobname], 128);
		g_ePlayerJob[client][pjJobLevel] = SQL_FetchIntByName(hndl, "level");
		g_ePlayerJob[client][pjJobExperience] = SQL_FetchIntByName(hndl, "experience");
	}
}

public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, any data) {
	if (!StrEqual(error, ""))
		LogError(error);
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon, int &tickcount) {
	if (IsClientInGame(client) && IsPlayerAlive(client) && g_bProgressBarActive[client]) {
		if (iButtons & IN_FORWARD)
			interruptProgressBar(client);
		if (iButtons & IN_BACK)
			interruptProgressBar(client);
		if (iButtons & IN_MOVELEFT)
			interruptProgressBar(client);
		if (iButtons & IN_MOVERIGHT)
			interruptProgressBar(client);
		if (iButtons & IN_DUCK)
			interruptProgressBar(client);
		if (iButtons & IN_JUMP)
			interruptProgressBar(client);
		
		g_iPlayerPrevButtons[client] = iButtons;
	}
	
}

public void startProgress(int client, int time, char info[64]) {
	if (!(GetEntityFlags(client) & FL_ONGROUND))
		return;
	//SetEntPropFloat(client, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
	//SetEntProp(client, Prop_Send, "m_iProgressBarDuration", time);
	if (g_bProgressBarActive[client])
		return;
	strcopy(g_cProgressBarInfo[client], 64, info);
	g_bProgressBarActive[client] = true;
	g_iProgressBarProgress[client] = 0;
	//time *= 10;
	//int target = RoundToNearest(time);
	g_iProgressBarTarget[client] = time;
	//PrintHintText(client, "\n\n<font size='18'>%s</font>", info);
}

public void interruptProgressBar(int client) {
	Call_StartForward(g_hOnProgressBarInterrupted);
	Call_PushCell(client);
	Call_PushString(g_cProgressBarInfo[client]);
	Call_Finish();
	
	
	g_bProgressBarActive[client] = false;
	g_iProgressBarProgress[client] = -1;
	g_iProgressBarTarget[client] = -1;
	strcopy(g_cProgressBarInfo[client], 64, "");
	//SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
}

public void completeProgressBar(int client) {
	Call_StartForward(g_hOnProgressBarFinished);
	Call_PushCell(client);
	Call_PushString(g_cProgressBarInfo[client]);
	Call_Finish();
	
	g_bProgressBarActive[client] = false;
	g_iProgressBarProgress[client] = -1;
	g_iProgressBarTarget[client] = -1;
	//SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
	char info[64];
	strcopy(info, 64, "");
}

public int findLoadedJobIdByName(char jobname[128]) {
	for (int i = 0; i < g_iLoadedJobs; i++) {
		if (StrEqual(g_eLoadedJobs[i][gJobname], jobname))
			return i;
	}
	return -1;
}

public Action cmdGiveXp(int client, int args) {
	if (args < 2) {
		ReplyToCommand(client, "[-T-] Usage: sm_givexp <target> <amount>");
		return Plugin_Handled;
	}
	
	char tempExperienceString[64];
	GetCmdArg(2, tempExperienceString, sizeof(tempExperienceString));
	
	int tempexperience = StringToInt(tempExperienceString);
	if (tempexperience < -1000000 || tempexperience > 1000000) {
		ReplyToCommand(client, "Invalid Amount | < -1000000 || > 1000000");
		return Plugin_Handled;
	}
	
	char pattern[MAX_NAME_LENGTH + 8];
	char buffer[MAX_NAME_LENGTH + 8];
	GetCmdArg(1, pattern, sizeof(pattern));
	int targets[64];
	bool ml = false;
	
	int count = ProcessTargetString(pattern, client, targets, sizeof(targets), COMMAND_FILTER_ALIVE, buffer, sizeof(buffer), ml);
	
	if (count <= 0)
		ReplyToCommand(client, "Invalid or Bad Target");
	else {
		for (int i = 0; i < count; i++) {
			int target = targets[i];
			char job[128];
			strcopy(job, sizeof(job), g_ePlayerJob[target][pjJobname]);
			if (tempexperience >= 0)
				increaseExperience(target, tempexperience, job);
			else
				decreaseExperience(target, tempexperience, job);
		}
	}
	
	return Plugin_Handled;
} 