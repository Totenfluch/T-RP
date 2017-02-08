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

public void OnPluginStart() {
	HookEvent("player_death", onPlayerDeath);
	HookEvent("player_hurt", onPlayerHurt);
}

public void onPlayerHurt(Handle event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int hurtdmg = GetEventInt(event, "dmg_health");
	
	char weapon[64];
	GetClientWeapon(attacker, weapon, sizeof(weapon));
	
	if (victim == attacker)
		return;
	
	if (!isValidClient(attacker))
		return;
	
	if (jobs_isActiveJob(attacker, "Police")) {
		if (!StrEqual(weapon, "weapon_taser"))
			if (isValidClient(victim))
			if (attacker != victim)
			if (tCrime_getCrime(victim) == 0)
			KickClient(attacker, "RDM");
		
		return;
	}
	
	
	tCrime_addCrime(attacker, hurtdmg / 4);
}

public void onPlayerDeath(Handle event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "attacker"));
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!isValidClient(client))
		return;
	
	if (client == victim)
		return;
	
	if (jobs_isActiveJob(client, "Police")) {
		if (isValidClient(victim)) {
			if (client != victim)
				if (tCrime_getCrime(victim) == 0)
				KickClient(client, "RDM");
		}
		return;
	}
	
	
	tCrime_addCrime(client, 2000);
}

stock bool isValidClient(int client) {
	return (1 <= client <= MaxClients && IsClientInGame(client));
}





