#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <tCrime>
#include <rpg_jobs_core>
#include <autoexecconfig>

#pragma newdecls required

Handle g_hCrimeForKill;
int g_iCrimeForKill;

Handle g_hCrimeForDamage;
float g_fCrimeForDamage;

int g_iSprite;

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
	
	AutoExecConfig_SetFile("rpg_crimehandler");
	AutoExecConfig_SetCreateFile(true);
	
	g_hCrimeForKill = AutoExecConfig_CreateConVar("rpg_crime_for_kill", "1000", "Crime you get for a Kill");
	g_hCrimeForDamage = AutoExecConfig_CreateConVar("rpg_crime_for_damage", "4.0", "Damage done * Value = Crime");
	
	AutoExecConfig_CleanFile();
	AutoExecConfig_ExecuteFile();
}

public void OnConfigsExecuted() {
	g_iCrimeForKill = GetConVarInt(g_hCrimeForKill);
	g_fCrimeForDamage = GetConVarFloat(g_hCrimeForDamage);
}

public void OnMapStart() {
	g_iSprite = PrecacheModel("materials/sprites/laser.vmt");
}

public void onPlayerHurt(Handle event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int hurtdmg = GetEventInt(event, "dmg_health");
	
	if (victim == attacker)
		return;
	
	if (!isValidClient(attacker))
		return;
	
	char weapon[64];
	GetClientWeapon(attacker, weapon, sizeof(weapon));
	
	int crime = RoundToNearest(hurtdmg * g_fCrimeForDamage);
	tCrime_addCrime(attacker, crime);
}

public void onPlayerDeath(Handle event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "attacker"));
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!isValidClient(client))
		return;
	
	if (client == victim)
		return;
	
	bool witnessed = false;
	for (int i = 1; i < MAXPLAYERS; i++) {
		if (!isValidClient(i))
			continue;
		if (i == client || i == victim)
			continue;
		if (isWitness(i, client)) {
			PrintToChat(i, "[-T-] You have witnessed %N killing %N - Auto Reported[BETA only]", client, victim);
			witnessed = true;
		}
	}
	if (witnessed)
		tCrime_addCrime(client, g_iCrimeForKill);
}

stock bool isValidClient(int client) {
	return (1 <= client <= MaxClients && IsClientInGame(client));
}

public bool isWitness(int client, int target) {
	// Witness Position and Angles
	float playerPos[3];
	float playerAngles[3];
	GetClientEyePosition(client, playerPos);
	GetClientAbsAngles(client, playerAngles);
	
	
	// Killer Position and Angles
	float targetPos[3];
	float targetAngles[3];
	GetClientEyePosition(target, targetPos);
	GetClientAbsAngles(target, targetAngles);
	
	// Vector between Witness and Killer
	float vectorBetweenPlayers[3];
	MakeVectorFromPoints(targetPos, playerPos, vectorBetweenPlayers);
	
	// Angles of the Vector between Witness and Killer
	float beamAngles[3];
	GetVectorAngles(vectorBetweenPlayers, beamAngles);
	
	// Trace Ray from Witness with the Angles between Witness and Killer
	Handle trace = TR_TraceRayFilterEx(targetPos, beamAngles, MASK_VISIBLE, RayType_Infinite, TraceRayNoPlayers, client);
	
	// Check if there is something between Killer and Witness
	if (TR_DidHit(trace)) {
		// Vector of the Hit Vector if something is between them
		float hOrigin[3];
		float beam2Vector[3];
		TR_GetEndPosition(hOrigin, trace);
		MakeVectorFromPoints(targetPos, hOrigin, beam2Vector);
		CloseHandle(trace);
		// Check if the Vector hit after the Killer or before
		// before? -> Couldn't have witnessed crime
		// after? -> Could have wtinessed crime
		/*int color[4];
		color[0] = 255;
		color[1] = 0;
		color[2] = 0;
		color[3] = 255;
		TE_SetupBeamPoints(targetPos, hOrigin, g_iSprite, 0, 0, 0, 5.0, 10.0, 10.0, 1, 0.0, color, 0);
		TE_SendToAll();
		color[0] = 0;
		color[1] = 255;
		targetPos[2] += 10;
		playerPos[2] += 10;
		TE_SetupBeamPoints(targetPos, playerPos, g_iSprite, 0, 0, 0, 5.0, 10.0, 10.0, 1, 0.0, color, 0);
		TE_SendToAll();*/
		if (GetVectorLength(vectorBetweenPlayers, true) < GetVectorLength(beam2Vector, true)) {
			// after
			//PrintToChatAll("Did hit (after) %.2f --- %.2f", GetVectorLength(vectorBetweenPlayers, true), GetVectorLength(beam2Vector, true));
			return true;
		} else {
			// before
			//PrintToChatAll("Did hit (before) %.2f --- %.2f", GetVectorLength(vectorBetweenPlayers, true), GetVectorLength(beam2Vector, true));
			return false;
		}
	}
	PrintToChatAll("Did not hit");
	CloseHandle(trace);
	// Didn't hit at all - Distance is clear between both - could have witnessed
	return true;
}

public bool TraceRayNoPlayers(int entity, int mask, any data) {
	if (entity == data || (entity >= 1 && entity <= MaxClients))
		return false;
	return true;
} 