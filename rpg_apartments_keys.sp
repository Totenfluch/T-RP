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
#include <rpg_apartments>
#include <rpg_inventory_core>
#include <tConomy>
#include <rpg_interact>

#pragma newdecls required
char g_cInteraction[64] = "Give Apartment Keys";

public Plugin myinfo = 
{
	name = "[T-RP] Apartment Keys", 
	author = PLUGIN_AUTHOR, 
	description = "Adds Keys to the Apartments Core", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart() {  }

public void OnMapStart() {
	interact_registerInteract(g_cInteraction);
}

stock bool isValidClient(int client) {
	return (1 <= client <= MaxClients && IsClientInGame(client));
}

public void OnPlayerInteract(int client, int target, char interaction[64]) {
	if (!StrEqual(g_cInteraction, interaction))
		return;
	
	if (inventory_hasPlayerItem(client, "Apartment Key"))
		aparments_allowPlayer(client, target);
	else
		PrintToChat(client, "[-T-] You don't have a key");
} 