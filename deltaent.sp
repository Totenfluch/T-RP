#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>

public Plugin myinfo = {
	name = "DeltaEnt", author = "KoSSoLaX",
	description = "DeltaEnt - Hard fix",
	version = "1.0.0", url = "https://www.ts-x.eu"
};

bool g_bConnected[65];

#define THRESHOLD 1024
#define TIMER 20.0
//#define DEBUG

public void OnPluginStart() {
	for (int i = THRESHOLD; i <= 2048; i++) {
		if( !IsValidEdict(i) || !IsValidEntity(i) )
			continue;
		SDKHook(i, SDKHook_SetTransmit, Transmit);
	}
	for (int i = 1; i <= MaxClients; i++) {
		if( !IsValidEdict(i) || !IsClientInGame(i) )
			continue;
		g_bConnected[i] = true;
	}

#if defined DEBUG
		PrintToChatAll("Current entity count: %d", GetEntityCount());
#endif
}
public void OnEntityCreated(int entity, const char[] classname) {
	if( entity >= THRESHOLD )
		SDKHook(entity, SDKHook_SetTransmit, Transmit);
}
public void OnClientPutInServer(int client) {
	CreateTimer(TIMER, Late_Connect, client);
}
public void OnClientDisconnect(int client) {
	g_bConnected[client] = false;
}
public Action Transmit(int ent, int client) {
	if( g_bConnected[client] == false )
		return Plugin_Handled;
	return Plugin_Continue;
}
public Action Late_Connect(Handle timer, any client) {
	if( IsValidEdict(client) && IsClientInGame(client) ) {
		g_bConnected[client] = true;
		
#if defined DEBUG
		PrintToChat(client, "Current entity count: %d", GetEntityCount());
#endif
	}
}
