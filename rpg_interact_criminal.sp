#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <rpg_inventory_core>
#include <rpg_jobs_core>
#include <rpg_interact>
#include <tConomy>
#include <tCrime>
#include <smlib>

#pragma newdecls required

bool g_bIsZiptied[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Criminal Interact for T-RP", 
	author = PLUGIN_AUTHOR, 
	description = "Adds Criminal Interactions for T-RP", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart() {
	HookEvent("player_spawn", onPlayerSpawn);
}

public void OnClientPostAdminCheck(int client) {
	g_bIsZiptied[client] = false;
}

public void OnMapStart() {
	interact_registerInteract("Criminal Actions");
	interact_registerInteract("Try to free");
}

int g_iPlayerTarget[MAXPLAYERS + 1];
public void OnPlayerInteract(int client, int target, char interact[64]) {
	if (StrEqual(interact, "Criminal Actions")) {
		Menu m = CreateMenu(criminalInteractionsMenuHandler);
		SetMenuTitle(m, "Do something Criminal...");
		AddMenuItem(m, "steal", "Steal Money");
		AddMenuItem(m, "ziptie", "Ziptie Player", inventory_hasPlayerItem(client, "ziptie") ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
		DisplayMenu(m, client, 30);
		g_iPlayerTarget[client] = target;
	} else if (StrEqual(interact, "Try to free")) {
		if (g_bIsZiptied[target]) {
			g_iPlayerTarget[client] = target;
			jobs_startProgressBar(client, 10, "Free Player");
		} else
			PrintToChat(client, "[-T-] %N doesn't need to be freed", target);
	}
}

public int criminalInteractionsMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		
		if (StrEqual(cValue, "steal")) {
			if (isValidClient(g_iPlayerTarget[client]))
				PrintToChat(g_iPlayerTarget[client], "[-T-] %N tries to steal your money!!!!", client);
			jobs_startProgressBar(client, 75, "Steal Money");
		} else if (StrEqual(cValue, "ziptie")) {
			jobs_startProgressBar(client, 15, "Ziptie Player");
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void jobs_OnProgressBarFinished(int client, char info[64]) {
	if (!StrEqual(info, "Steal Money") && !StrEqual(info, "Ziptie Player") && !StrEqual(info, "Free Player"))
		return;
	
	float ppos[3];
	float tpos[3];
	GetClientAbsOrigin(client, ppos);
	if (isValidClient(g_iPlayerTarget[client]))
		GetClientAbsOrigin(g_iPlayerTarget[client], tpos);
	else
		return;
	if (GetVectorDistance(ppos, tpos) > 150.0) {
		PrintToChat(client, "[-T-] Target is too far away...");
		return;
	}
	
	if (StrEqual(info, "Steal Money")) {
		int amount = RoundToNearest(tConomy_getCurrency(g_iPlayerTarget[client]) / 10.0);
		char reason[256];
		Format(reason, sizeof(reason), "Stolen from %N", g_iPlayerTarget[client]);
		tConomy_addCurrency(client, amount, reason);
		Format(reason, sizeof(reason), "Stolen by %N", client);
		tConomy_removeCurrency(g_iPlayerTarget[client], amount, reason);
		tCrime_addCrime(client, amount * 2);
	} else if (StrEqual(info, "Ziptie Player")) {
		if (inventory_removePlayerItems(client, "ziptie", 1, "Ziptied Player")) {
			ziptiePlayer(g_iPlayerTarget[client], client);
			tCrime_addCrime(client, 100);
		}
	} else if (StrEqual(info, "Free Player")) {
		unzipPlayer(g_iPlayerTarget[client], client);
	}
}

public void ziptiePlayer(int client, int initiator) {
	if (!isValidClient(client))
		return;
	g_bIsZiptied[client] = true;
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 0.0);
	SetEntityMoveType(client, MOVETYPE_NONE);
	PrintToChat(client, "[-T-] You were Ziptied by %N", initiator);
	SetEntityRenderColor(client, 255, 0, 0, 255);
}

public void unzipPlayer(int client, int initiator) {
	if (!isValidClient(client))
		return;
	g_bIsZiptied[client] = false;
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
	SetEntityMoveType(client, MOVETYPE_WALK);
	PrintToChat(client, "[-T-] You were freed by %N", initiator);
	SetEntityRenderColor(client, 255, 255, 255, 255);
}

stock bool isValidClient(int client) {
	return (1 <= client <= MaxClients && IsClientInGame(client));
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) {
	char wName[128];
	GetClientWeapon(client, wName, sizeof(wName));
	if ((buttons & IN_ATTACK2)) {
		int Target = GetClientAimTarget(client, true);
		
		if (isValidClient(Target) && g_bIsZiptied[client]) {
			float distance = Entity_GetDistance(client, Target);
			distance = Math_UnitsToMeters(distance);
			
			if ((5 > distance) && !Client_IsLookingAtWall(client, Entity_GetDistance(client, Target) + 40.0)) {
				float origin[3];
				GetClientAbsOrigin(client, origin);
				float origin2[3];
				GetClientAbsOrigin(Target, origin2);
				origin2[2] += 5.0;
				float location[3];
				GetClientEyePosition(client, location);
				float ang[3];
				GetClientEyeAngles(client, ang);
				float location2[3];
				location2[0] = (location[0] + (100 * ((Cosine(DegToRad(ang[1]))) * (Cosine(DegToRad(ang[0]))))));
				location2[1] = (location[1] + (100 * ((Sine(DegToRad(ang[1]))) * (Cosine(DegToRad(ang[0]))))));
				ang[0] -= (2 * ang[0]);
				location2[2] = origin[2] += 5.0;
				
				TeleportEntity(Target, location2, NULL_VECTOR, NULL_VECTOR);
				if (IsPlayerStuck(Target))
					TeleportEntity(Target, origin2, NULL_VECTOR, NULL_VECTOR);
				
			}
		}
	}
}

stock bool IsPlayerStuck(int client) {
	float vecMin[3];
	float vecMax[3];
	float vecOrigin[3];
	
	GetClientMins(client, vecMin);
	GetClientMaxs(client, vecMax);
	
	GetClientAbsOrigin(client, vecOrigin);
	
	TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_PLAYERSOLID, TraceRayDontHitPlayerAndWorld);
	return TR_GetEntityIndex() != -1;
}

public bool TraceRayDontHitPlayerAndWorld(int entityhit, int mask) {
	return (entityhit < 1 || entityhit > MaxClients);
}

public Action onPlayerSpawn(Handle event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!isValidClient(client))
		return;
	if (!IsPlayerAlive(client))
		return;
	SetEntityRenderColor(client, 255, 255, 255, 255);
} 