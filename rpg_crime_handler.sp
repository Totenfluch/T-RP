#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <tCrime>
#include <rpg_jobs_core>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "Crime Handler for T-RP",
	author = PLUGIN_AUTHOR,
	description = "Adds crime for bad activitys of T-RP",
	version = PLUGIN_VERSION,
	url = "http://ggc-base.de"
};

public void OnPluginStart(){
	HookEvent("player_death", onPlayerDeath);
	HookEvent("player_hurt", onPlayerHurt);
}

public void onPlayerHurt(Handle event, const char[] name, bool dontBroadcast){
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int hurtdmg = GetEventInt(event, "dmg_health");
	
	if(jobs_isActiveJob(attacker, "Police"))
		return;
		
	tCrime_addCrime(attacker, hurtdmg/4);
}

public void onPlayerDeath(Handle event, const char[] name, bool dontBroadcast){
	int client = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(jobs_isActiveJob(client, "Police"))
		return;
		
	tCrime_addCrime(client, 400);
}





