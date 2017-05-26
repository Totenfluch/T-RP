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
#include <emitsoundany>

#pragma newdecls required

int g_iInternalCooldown[2048];

public Plugin myinfo = 
{
	name = "[T-RP] Furniture: Piano", 
	author = PLUGIN_AUTHOR, 
	description = "adds sound for the Piano", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart()
{
	AddFileToDownloadsTable("sound/rp/elise2.mp3");
	PrecacheSoundAny("rp/elise2.mp3", true);
}

public void OnMapStart() {
	AddFileToDownloadsTable("sound/rp/elise2.mp3");
	PrecacheSoundAny("rp/elise2.mp3", true);
	CreateTimer(5.0, refreshTimer, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

public void furniture_OnFurnitureInteract(int entity, int client, char name[64], char lfBuf[64], char flags[8], char ownerId[20], int durability) {
	if (!StrEqual(name, "Piano"))
		return;
	
	if (g_iInternalCooldown[entity] != 0)
		return;
	g_iInternalCooldown[entity] = 32;
	
	float ObjectOrigin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", ObjectOrigin);
	// https://forums.alliedmods.net/showthread.php?p=737647
	EmitAmbientSoundAny("rp/elise2.mp3", ObjectOrigin, entity, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, _, _); // 2 -> 2 - Small Radius - Sound range is about 800 units at max volume.
}

public Action refreshTimer(Handle Timer) {
	for (int i = 0; i < 2048; i++) {
		if (g_iInternalCooldown[i] == 0)
			continue;
		else
			g_iInternalCooldown[i]--;
	}
}




