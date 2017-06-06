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
#include <sdkhooks>
#include <rpg_jail>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[T-RP] Damagecontroller", 
	author = PLUGIN_AUTHOR, 
	description = "Controls the Damage for T-RP", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart() {
	for (int i = 1; i < MAXPLAYERS; i++)
	if (isValidClient(i))
		SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientPutInServer(int client) {
	if (isValidClient(client))
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client) {
	if (isValidClient(client))
		SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &bweapon, float damageForce[3], const float damagePosition[3]) {
	if (!isValidClient(victim))
		return Plugin_Continue;
	
	if (damagetype & DMG_FALL) {
		int health = GetClientHealth(victim);
		if (damage >= health) {
			damage = float(health) - 1.0;
			return Plugin_Changed;
		}
	}
	
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
		damage *= 0.5;
		return Plugin_Changed;
	}
}
stock bool isValidClient(int client) {
	return (1 <= client <= MaxClients && IsClientInGame(client));
}
