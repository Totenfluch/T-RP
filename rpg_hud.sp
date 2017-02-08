#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <tConomy>
#include <smlib>
#include <tCrime>
#include <rpg_jobs_core>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "HUD for T-RP", 
	author = PLUGIN_AUTHOR, 
	description = "Adds a HUD for T-RP", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart() {
	RegConsoleCmd("sm_testbar", cmdTestBar);
}

public void OnMapStart() {
	CreateTimer(0.2, updateHUD, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action updateHUD(Handle Timer) {
	for (int client = 1; client < MAXPLAYERS; client++) {
		if (!isValidClient(client))
			continue;
		if (jobs_isInProgressBar(client))
			continue;
		
		
		char printHudString[1024];
		if (GetClientAimTarget(client, true) > -1) {
			int target = GetClientAimTarget(client, true);
			float tpos[3];
			GetClientAbsOrigin(target, tpos);
			float pos[3];
			GetClientAbsOrigin(client, pos);
			if (GetVectorDistance(tpos, pos) < 300.0)
				Format(printHudString, sizeof(printHudString), "<font size='16'>Target: %N\n", target);
			else
				Format(printHudString, sizeof(printHudString), "<font size='16'>Target: Out of Range\n");
			/*} else if (GetClientAimTarget(client, false) > -1) {
			int ent = GetClientAimTarget(client, false);
			if (HasEntProp(ent, Prop_Data, "m_iName") && HasEntProp(ent, Prop_Data, "m_iGlobalname")) {
				char entName[256];
				Entity_GetGlobalName(ent, entName, sizeof(entName));
				//GetEntPropString(ent, Prop_Data, "m_iGlobalName", entName, sizeof(entName));
				Format(printHudString, sizeof(printHudString), "<font size='16'>Target: %s\n", entName);
			}*/
		} else {
			Format(printHudString, sizeof(printHudString), "<font size='16'>Target: none\n");
		}
		
		int money = tConomy_getCurrency(client);
		Format(printHudString, sizeof(printHudString), "%sMoney: %i ~ ", printHudString, money);
		
		int crime = tCrime_getCrime(client);
		if (crime > 0)
			Format(printHudString, sizeof(printHudString), "%sCrime: %i\n", printHudString, crime);
		else
			Format(printHudString, sizeof(printHudString), "%sCrime: 0\n", printHudString);
		
		char jobname[128];
		jobs_getActiveJob(client, jobname);
		
		if (StrEqual(jobname, ""))
			Format(printHudString, sizeof(printHudString), "%sJob: none\n", printHudString);
		else {
			Format(printHudString, sizeof(printHudString), "%sJob: %s | Level: %i | XP: %i/%i\n", printHudString, jobname, jobs_getLevel(client), jobs_getExperience(client), jobs_getExperienceForNextLevel(client));
		}
		
		char info[128];
		jobs_getCurrentInfo(client, info);
		if (!StrEqual(info, ""))
			Format(printHudString, sizeof(printHudString), "%s%s\n", printHudString, info);
		
		
		PrintHintText(client, printHudString);
	}
}

public Action cmdTestBar(int client, int args) {
	char cmdBuffer[64];
	GetCmdArg(client, cmdBuffer, sizeof(cmdBuffer));
	int time = StringToInt(cmdBuffer);
	jobs_startProgressBar(client, time, "testBar");
}



stock bool isValidClient(int client) {
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client))
		return false;
	
	return true;
}

