#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <rpg_jail>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "Damagecontroller for T-RP", 
	author = PLUGIN_AUTHOR, 
	description = "Controls the Damage for T-RP", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart() {
	for (int i = 1; i < MAXPLAYERS; i++)
	if (isValidClient(i))
		SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientPutInServer(int client) {
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client) {
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &bweapon, float damageForce[3], const float damagePosition[3])
{
	if (!isValidClient(victim))
		return Plugin_Continue;
	
	if (!isValidClient(attacker))
		return Plugin_Continue;
	
	char weaponName[64];
	GetClientWeapon(attacker, weaponName, sizeof(weaponName));
	
	if (StrContains(weaponName, "knife") != -1) {
		damage = 0.0;
		return Plugin_Changed;
	} else if (jail_isInJail(attacker)) {
		damage = 0.0;
		return Plugin_Changed;
	} else {
		damage *= 0.3;
		return Plugin_Changed;
	}
}
stock bool isValidClient(int client) {
	return (1 <= client <= MaxClients && IsClientInGame(client));
}
