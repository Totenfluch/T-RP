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
#include <tConomy>
#include <smlib>
#include <tCrime>
#include <rpg_jobs_core>
#include <tStocks>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[T-RP] HUD", 
	author = PLUGIN_AUTHOR, 
	description = "Adds a HUD for T-RP", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart() {
	RegConsoleCmd("sm_testbar", cmdTestBar);
}

public void OnMapStart() {
	CreateTimer(0.2, updateHUD, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(1.0, updatePrintText, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action updatePrintText(Handle Timer) {
	for (int client = 1; client < MAXPLAYERS; client++) {
		if (!isValidClient(client))
			continue;
		
		showAllHudMessages(client);
	}
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
			if (StrContains(jobname, "Apple") != -1)
				ReplaceString(jobname, sizeof(jobname), "Apple ", "", false);
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

void showAllHudMessages(int client) {
	showHudMsg(client, "by ggc-base.de", 0, 188, 212, 0.01, 0.01, 1.05);
	//showHudMsg(client, "Donator: No", 							103, 58, 183, 	0.01, 0.05, 1.05);
	//showHudMsg(client, "In Steam Group: No", 					63, 81, 181, 	0.01,  0.1, 1.05);
}

public void showHudMsg(int client, char[] message, int r, int g, int b, float x, float y, float timeout) {
	SetHudTextParams(x, y, timeout, r, g, b, 255, 0, 0.0, 0.0, 0.0);
	ShowHudText(client, -1, message);
}

public bool isValidRef(int ref) {
	int index = EntRefToEntIndex(ref);
	if (index > MaxClients && IsValidEntity(index)) {
		return true;
	}
	return false;
} 