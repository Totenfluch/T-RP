#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <devzones>

// configuration
#define ZONE_PREFIX "apartment_"
//End


float zone_pos[MAXPLAYERS + 1][3];
Handle g_hClientTimers[MAXPLAYERS + 1] =  { INVALID_HANDLE, ... };

public Plugin myinfo = 
{
	name = "SM DEV Zones - NoEntry for RP", 
	author = "Franc1sco franug - Totenfluch", 
	description = "Usaged to block Apartment entry", 
	version = "2.0", 
	url = "http://ggc-base.de"
};

public void OnClientDisconnect(int client)
{
	if (g_hClientTimers[client] != INVALID_HANDLE)
		KillTimer(g_hClientTimers[client]);
	g_hClientTimers[client] = INVALID_HANDLE;
}

public void Zone_OnClientEntry(int client, char[] zone) {
	if (StrContains(zone, ZONE_PREFIX, false) == 0) {
		int zoneId;
		if ((zoneId = getLoadedIdFromApartmentId(zone)) != -1) {
			int ownedId;
			if ((ownedId = ApartmentIdToOwnedId(zoneId)) != -1) {
				char playerid[20];
				GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
				if (StrContains(ownedApartment[ownedId][oaAllowed_players], playerid) == -1 && !StrEqual(ownedApartment[ownedId][oaPlayerid], playerid)) {
					Zone_GetZonePosition(zone, false, zone_pos[client]);
					g_hClientTimers[client] = CreateTimer(0.1, Timer_Repeat, client, TIMER_REPEAT);
					PrintToChat(client, "You can't enter %s", ownedApartment[ownedId][oaApartmentName]);
				}
			}
		}
	}
}

public void Zone_OnClientLeave(int client, char[] zone)
{
	if (StrContains(zone, ZONE_PREFIX, false) == 0)
	{
		if (g_hClientTimers[client] != INVALID_HANDLE)
			KillTimer(g_hClientTimers[client]);
		g_hClientTimers[client] = INVALID_HANDLE;
	}
}

public Action Timer_Repeat(Handle timer, any client)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client))
	{
		if (g_hClientTimers[client] != INVALID_HANDLE)
			KillTimer(g_hClientTimers[client]);
		g_hClientTimers[client] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	float clientloc[3];
	GetClientAbsOrigin(client, clientloc);
	
	KnockbackSetVelocity(client, zone_pos[client], clientloc, 300.0);
	return Plugin_Continue;
}

public void KnockbackSetVelocity(int client, const float startpoint[3], const float endpoint[3], float magnitude)
{
	// Create vector from the given starting and ending points.
	float vector[3];
	MakeVectorFromPoints(startpoint, endpoint, vector);
	
	// Normalize the vector (equal magnitude at varying distances).
	NormalizeVector(vector, vector);
	
	// Apply the magnitude by scaling the vector (multiplying each of its components).
	ScaleVector(vector, magnitude);
	
	
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vector);
}
