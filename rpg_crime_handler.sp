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
	g_hCrimeForDamage = AutoExecConfig_CreateConVar("rpg_crime_for_damage", "0.25", "Damage done * Value = Crime");
	
	AutoExecConfig_CleanFile();
	AutoExecConfig_ExecuteFile();
}

public void OnConfigsExecuted() {
	g_iCrimeForKill = GetConVarInt(g_hCrimeForKill);
	g_fCrimeForDamage = GetConVarFloat(g_hCrimeForDamage);
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
	
	if (jobs_isActiveJob(client, "Police")) {
		if (isValidClient(victim)) {
			if (client != victim)
				if (tCrime_getCrime(victim) == 0)
				KickClient(client, "RDM");
		}
		return;
	}
	

	bool witnessed = false;
	for (int i = 1; i < MAXPLAYERS; i++){
		if(!isValidClient(i))
			continue;
		if(i == client || i == victim)
			continue;
		if(isWitness(i, client)){
			PrintToChat(i, "[-T-] You have witnessed %N killing %N - Auto Reported[BETA only]", client, victim);
			witnessed = true;
		}
	}
	if(witnessed)
		tCrime_addCrime(client, g_iCrimeForKill);
}

stock bool isValidClient(int client) {
	return (1 <= client <= MaxClients && IsClientInGame(client));
}

public bool isWitness(int client, int target){
	// Witness Position and Angles
	float playerPos[3];
	float playerAngles[3];
	GetClientAbsOrigin(client, playerPos);
	GetClientAbsAngles(client, playerAngles);
	
	
	// Killer Position and Angles
	float targetPos[3];
	float targetAngles[3];
	GetClientAbsOrigin(target, targetPos);
	GetClientAbsAngles(target, targetAngles);
	
	// Vector between Witness and Killer
	float vectorBetweenPlayers[3];
	MakeVectorFromPoints(targetPos, playerPos, vectorBetweenPlayers);
	
	// Angles of the Vector between Witness and Killer
	float beamAngles[3];
	GetVectorAngles(vectorBetweenPlayers, beamAngles);
	
	// Trace Ray from Witness with the Angles between Witness and Killer
	Handle trace = TR_TraceRayFilterEx(playerPos, beamAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
	
	// Check if there is something between Killer and Witness
	if (TR_DidHit(trace)){
		// Vector of the Hit Vector if something is between them
		float hOrigin[3];
		float beam2Vector[3];
		TR_GetEndPosition(hOrigin, trace);
		MakeVectorFromPoints(targetPos, hOrigin, beam2Vector);
		CloseHandle(trace);
		
		// Check if the Vector hit after the Killer or before
		// before? -> Couldn't have witnessed crime
		// after? -> Could have wtinessed crime
		if(GetVectorLength(vectorBetweenPlayers, true) < GetVectorLength(beam2Vector, true))
			// after
			return true;
		else
			// before
			return false;
	}
	
	CloseHandle(trace);
	// Didn't hit at all - Distance is clear between both - could have witnessed
	return true;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask) {
	return (entity > GetMaxClients());
}