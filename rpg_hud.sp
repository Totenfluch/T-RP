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

public void OnPluginStart() {  }

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
			Format(printHudString, sizeof(printHudString), "<font size='16'>Target: %N\n", target);
		} else if (GetClientAimTarget(client, false) > -1) {
			int ent = GetClientAimTarget(client, false);
			if (HasEntProp(ent, Prop_Data, "m_iName") && HasEntProp(ent, Prop_Data, "m_iGlobalname")) {
				char entName[256];
				Entity_GetGlobalName(ent, entName, sizeof(entName));
				//GetEntPropString(ent, Prop_Data, "m_iGlobalName", entName, sizeof(entName));
				Format(printHudString, sizeof(printHudString), "<font size='16'>Target: %s\n", entName);
			}
		} else {
			Format(printHudString, sizeof(printHudString), "<font size='16'>Target: none\n");
		}
		
		int money = tConomy_getCurrency(client);
		Format(printHudString, sizeof(printHudString), "%sMoney: %i\n", printHudString, money);
		
		char jobname[128];
		jobs_getActiveJob(client, jobname);
		
		if (StrEqual(jobname, ""))
			Format(printHudString, sizeof(printHudString), "%sJob: none\n", printHudString);
		else {
			Format(printHudString, sizeof(printHudString), "%sJob: %s | Level: %i | XP: %i/%i\n", printHudString, jobname, jobs_getLevel(client), jobs_getExperience(client), jobs_getExperienceForNextLevel(client));
		}
		
		int crime = tCrime_getCrime(client);
		if (crime > 0)
			Format(printHudString, sizeof(printHudString), "%sCrime: %i</font>", printHudString, crime);
		else
			Format(printHudString, sizeof(printHudString), "%sCrime: 0</font>", printHudString);
		PrintHintText(client, printHudString);
	}
}

stock bool isValidClient(int client) {
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client))
		return false;
	
	return true;
}

