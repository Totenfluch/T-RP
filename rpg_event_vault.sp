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
#include <smlib>
#include <emitsoundany>
#include <rpg_jobs_core>
#include <rpg_inventory_core>
#include <devzones>
#include <tStocks>

#pragma newdecls required

#define MAX_BOMB_TIME 30
#define MAX_SAW_TIME 300

int g_iGateRef = -1;
int g_iMoney1Ref = -1;
int g_iBombEnt = -1;
int g_iMoney2Ref = -1;

int g_iGlow = -1;
int g_iBombTimeLeft = -1;

int g_iExplosionSprite = -1;

int g_iTablesawRef = -1;
int g_iSawTimeLeft = -1;

int g_iPlayerPrevButtons[MAXPLAYERS + 1];

bool g_bEventOver = false;
int g_iEventOverSince;
bool doorState = false;

public Plugin myinfo = 
{
	name = "[T-RP] Vault Event", 
	author = PLUGIN_AUTHOR, 
	description = "Adds the Vault Event for T-RP", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart() {
	HookEvent("round_start", onRoundStart);
}

public void onRoundStart(Handle event, const char[] name, bool dontBroadcast) {
	setupEvent();
	doorState = false;
}

public void OnMapStart() {
	g_iGateRef = -1;
	g_iMoney1Ref = -1;
	g_iBombEnt = -1;
	g_iMoney2Ref = -1;
	g_iGlow = -1;
	g_iBombTimeLeft = -1;
	g_iExplosionSprite = -1;
	g_iTablesawRef = -1;
	g_iSawTimeLeft = -1;
	g_bEventOver = false;
	
	g_iGlow = PrecacheModel("sprites/ledglow.vmt");
	PrecacheSoundAny("UI/beep07.wav", true);
	PrecacheSoundAny("ambient/explosions/explode_8.wav", true);
	CreateTimer(1.0, refreshTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	g_iExplosionSprite = PrecacheModel("sprites/sprite_fire01.vmt");
}

public void clearEvent() {
	int gateEnt = EntRefToEntIndex(g_iGateRef);
	int money1Ent = EntRefToEntIndex(g_iMoney1Ref);
	int bombEnt = EntRefToEntIndex(g_iBombEnt);
	int money2Ent = EntRefToEntIndex(g_iMoney2Ref);
	int tablesawEnt = EntRefToEntIndex(g_iTablesawRef);
	if (IsValidEntity(gateEnt))
		AcceptEntityInput(gateEnt, "kill");
	if (IsValidEntity(money1Ent))
		AcceptEntityInput(money1Ent, "kill");
	if (IsValidEntity(bombEnt))
		AcceptEntityInput(bombEnt, "kill");
	if (IsValidEntity(money2Ent))
		AcceptEntityInput(money2Ent, "kill");
	if (IsValidEntity(tablesawEnt))
		AcceptEntityInput(tablesawEnt, "kill");
	gateEnt = -1;
	money1Ent = -1;
	bombEnt = -1;
	money2Ent = -1;
	g_iBombTimeLeft = -1;
	tablesawEnt = -1;
	g_iSawTimeLeft = -1;
	g_bEventOver = false;
	g_iEventOverSince = 0;
	if (findVaultDoor() != -1) {
		SetVariantString("vault_close_idle");
		AcceptEntityInput(findVaultDoor(), "SetAnimation");
		doorState = false;
	}
}

public void resetEvent() {
	clearEvent();
	for (int i = 1; i < MAXPLAYERS; i++) {
		if (!isValidClient(i))
			continue;
		if (Zone_IsClientInZone(i, "vault_event")) {
			// TODO: Teleport out
		}
	}
	setupEvent();
}

public void setupEvent() {
	/* Create Gate */
	int gateEnt = CreateEntityByName("prop_dynamic_override");
	if (gateEnt == -1)
		return;
	char modelPath[128];
	Format(modelPath, sizeof(modelPath), "models/props_c17/gate_door01a.mdl");
	PrecacheModel("models/props_c17/gate_door01a.mdl", true);
	SetEntityModel(gateEnt, modelPath);
	DispatchKeyValue(gateEnt, "Solid", "6");
	SetEntProp(gateEnt, Prop_Send, "m_nSolidType", 6);
	SetEntProp(gateEnt, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_NONE);
	
	float gatePos[3];
	gatePos[0] = -2015.54;
	gatePos[1] = -4177.96;
	gatePos[2] = -90.96;
	
	float gateAngles[3];
	gateAngles[1] = 90.0;
	
	TeleportEntity(gateEnt, gatePos, gateAngles, NULL_VECTOR);
	
	Entity_SetGlobalName(gateEnt, "Vault Gate");
	g_iGateRef = EntIndexToEntRef(gateEnt);
	
	SetVariantString("idle");
	AcceptEntityInput(gateEnt, "SetAnimation");
	
	/* Create Money Pallet */
	int money1 = CreateEntityByName("prop_dynamic_override");
	if (money1 == -1)
		return;
	Format(modelPath, sizeof(modelPath), "models/props/cs_assault/moneypallet03.mdl");
	PrecacheModel("models/props/cs_assault/moneypallet03.mdl", true);
	SetEntityModel(money1, modelPath);
	DispatchKeyValue(money1, "Solid", "6");
	SetEntProp(money1, Prop_Send, "m_nSolidType", 6);
	SetEntProp(money1, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_NONE);
	
	float moneyPos[3];
	moneyPos[0] = -2076.75;
	moneyPos[1] = -4326.45;
	moneyPos[2] = -139.96;
	
	float moneyAngles[3];
	moneyAngles[1] = 69.55;
	
	TeleportEntity(money1, moneyPos, moneyAngles, NULL_VECTOR);
	
	Entity_SetGlobalName(money1, "Vault Money");
	g_iMoney1Ref = EntIndexToEntRef(money1);
	
	SetVariantString("idle");
	AcceptEntityInput(money1, "SetAnimation");
	
	int money2 = CreateEntityByName("prop_dynamic_override");
	if (money2 == -1)
		return;
	Format(modelPath, sizeof(modelPath), "models/props/cs_assault/moneypallet03.mdl");
	PrecacheModel("models/props/cs_assault/moneypallet03.mdl", true);
	SetEntityModel(money2, modelPath);
	DispatchKeyValue(money2, "Solid", "6");
	SetEntProp(money2, Prop_Send, "m_nSolidType", 6);
	SetEntProp(money2, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_NONE);
	
	
	moneyPos[0] = -1942.74;
	moneyPos[1] = -4376.36;
	moneyPos[2] = -139.96;
	
	moneyAngles[1] = 114.14;
	
	TeleportEntity(money2, moneyPos, moneyAngles, NULL_VECTOR);
	
	Entity_SetGlobalName(money2, "Vault Money");
	g_iMoney2Ref = EntIndexToEntRef(money2);
	
	SetVariantString("idle");
	AcceptEntityInput(money2, "SetAnimation");
	g_bEventOver = false;
}

public void announceRobbery(int client) {
	char robString[64];
	Format(robString, sizeof(robString), "%N tries to rob the Bank!!!", client);
	PrintToChatAll(robString, client);
	PrintToChatAll(robString, client);
	PrintToChatAll(robString, client);
	for (int i = 1; i < MAXPLAYERS; i++)
	if (isValidClient(i))
		showHudMsg(i, robString, 255, 0, 0, 0.0, 0.5, 5.0);
}

public void setupSaw(int client) {
	announceRobbery(client);
	/*[Measure] Got Point 1 at X:-2058.26 Y:-4047.40 Z:-112.18
	[Measure] Got Point 2 at X:-2057.73 Y:-4047.40 Z:-74.34*/
	/* Create Saw */
	int sawEnt = CreateEntityByName("prop_dynamic_override");
	if (sawEnt == -1)
		return;
	
	char modelPath[128];
	Format(modelPath, sizeof(modelPath), "models/props/cs_militia/circularsaw01.mdl");
	PrecacheModel(modelPath, true);
	SetEntityModel(sawEnt, modelPath);
	DispatchKeyValue(sawEnt, "Solid", "6");
	SetEntProp(sawEnt, Prop_Send, "m_nSolidType", 6);
	SetEntProp(sawEnt, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_NONE);
	
	float bombPos[3];
	bombPos[0] = -2058.26;
	bombPos[1] = -4047.40;
	bombPos[2] = -112.18;
	
	float bombAngles[3];
	bombAngles[1] = 180.0; // Korrekt
	bombAngles[2] = 90.0; // Korrekt
	bombAngles[0] = 270.0;
	
	TeleportEntity(sawEnt, bombPos, bombAngles, NULL_VECTOR);
	
	Entity_SetGlobalName(sawEnt, "Door Saw");
	g_iTablesawRef = EntIndexToEntRef(sawEnt);
	
	SetVariantString("idle");
	AcceptEntityInput(sawEnt, "SetAnimation");
	
	g_iSawTimeLeft = MAX_SAW_TIME;
}

public void setupBomb(int client) {
	announceRobbery(client);
	/* Create Bomb */
	int bombEnt = CreateEntityByName("prop_dynamic_override");
	if (bombEnt == -1)
		return;
	char modelPath[128];
	Format(modelPath, sizeof(modelPath), "models/weapons/w_c4_planted.mdl");
	PrecacheModel(modelPath, true);
	SetEntityModel(bombEnt, modelPath);
	DispatchKeyValue(bombEnt, "Solid", "6");
	SetEntProp(bombEnt, Prop_Send, "m_nSolidType", 6);
	SetEntProp(bombEnt, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_NONE);
	
	float bombPos[3];
	bombPos[0] = -2037.24;
	bombPos[1] = -4174.99;
	bombPos[2] = -91.96;
	
	float bombAngles[3];
	bombAngles[1] = 180.0; // Korrekt
	bombAngles[2] = 90.0; // Korrekt
	bombAngles[0] = 270.0;
	
	TeleportEntity(bombEnt, bombPos, bombAngles, NULL_VECTOR);
	
	Entity_SetGlobalName(bombEnt, "Vault Bomb");
	g_iBombEnt = EntIndexToEntRef(bombEnt);
	
	SetVariantString("idle");
	AcceptEntityInput(bombEnt, "SetAnimation");
	
	g_iBombTimeLeft = MAX_BOMB_TIME;
}

public Action refreshTimer(Handle Timer) {
	if (g_bEventOver)
		g_iEventOverSince++;
	if (g_iEventOverSince == 7200)
		resetEvent();
	if (g_iBombEnt != -1)
		if (IsValidEdict(g_iBombEnt))
		if (IsValidEntity(EntRefToEntIndex(g_iBombEnt)))
		bombBeep();
	if (IsValidEdict(g_iTablesawRef)) {
		if (IsValidEntity(EntRefToEntIndex(g_iTablesawRef))) {
			if (g_iSawTimeLeft > 0)
				g_iSawTimeLeft--;
			if (g_iSawTimeLeft % 60 == 0 || g_iSawTimeLeft == 30)
				PrintToChatAll("[-T-] %i seconds until the Vault is breached!!", g_iSawTimeLeft);
			if (g_iSawTimeLeft == 0) {
				int tablesawEnt = EntRefToEntIndex(g_iTablesawRef);
				if (IsValidEntity(tablesawEnt))
					AcceptEntityInput(tablesawEnt, "kill");
				tablesawEnt = -1;
				g_iTablesawRef = -1;
				if (findVaultDoor() != -1) {
					SetVariantString("vault_open");
					AcceptEntityInput(findVaultDoor(), "SetAnimation");
					doorState = true;
				}
			}
		}
	}
}

public int findVaultDoor() {
	int entity = 0;
	while ((entity = FindEntityByClassname(entity, "prop_dynamic")) != INVALID_ENT_REFERENCE) {
		char uniqueId[64];
		GetEntPropString(entity, Prop_Data, "m_iName", uniqueId, sizeof(uniqueId));
		if (StrEqual(uniqueId, "vault_door_01")) {
			return entity;
		}
	}
	return -1;
}

public void bombBeep() {
	float bombPos[3];
	bombPos[0] = -2037.24;
	bombPos[1] = -4168.99;
	bombPos[2] = -91.96;
	
	TE_SetupGlowSprite(bombPos, g_iGlow, 0.5, 1.0, 235);
	TE_SendToAll();
	
	EmitAmbientSoundAny("UI/beep07.wav", bombPos, _, _, _, _, _, _);
	
	if (g_iBombTimeLeft > 0)
		g_iBombTimeLeft--;
	if (g_iBombTimeLeft == 0)
		bombExplosion();
}

public void bombExplosion() {
	float bombPos[3];
	bombPos[0] = -2037.24;
	bombPos[1] = -4168.99;
	bombPos[2] = -91.96;
	
	EmitAmbientSoundAny("ambient/explosions/explode_8.wav", bombPos, _, _, _, _, _, _);
	TE_SetupExplosion(bombPos, g_iExplosionSprite, 150.0, 144, 0, 80, 1200);
	TE_SendToAll();
	
	
	int explosionParticles = CreateEntityByName("info_particle_system");
	DispatchKeyValue(explosionParticles, "start_active", "0");
	DispatchKeyValue(explosionParticles, "effect_name", "explosion_hegrenade_dirt");
	DispatchSpawn(explosionParticles);
	ActivateEntity(explosionParticles);
	TeleportEntity(explosionParticles, bombPos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(explosionParticles, "Start");
	CreateTimer(3.0, clearEffect, EntIndexToEntRef(explosionParticles));
	
	if (IsValidEdict(g_iBombEnt))
		if (IsValidEntity(EntRefToEntIndex(g_iBombEnt)))
		AcceptEntityInput(EntRefToEntIndex(g_iBombEnt), "kill");
	if (IsValidEdict(g_iGateRef))
		if (IsValidEntity(EntRefToEntIndex(g_iGateRef)))
		AcceptEntityInput(EntRefToEntIndex(g_iGateRef), "kill");
	g_bEventOver = true;
}

int g_iLastMoneyTarget[MAXPLAYERS + 1];
public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon, int &tickcount) {
	if (IsClientInGame(client) && IsPlayerAlive(client)) {
		if (!(g_iPlayerPrevButtons[client] & IN_USE) && iButtons & IN_USE) {
			int ent = getClientViewObject(client);
			if (!IsValidEntity(ent)) {
				g_iPlayerPrevButtons[client] = iButtons;
				return;
			}
			if (HasEntProp(ent, Prop_Data, "m_iName") && HasEntProp(ent, Prop_Data, "m_iGlobalname")) {
				float pos[3];
				GetEntPropVector(ent, Prop_Data, "m_vecOrigin", pos);
				float ppos[3];
				GetClientAbsOrigin(client, ppos);
				if (GetVectorDistance(ppos, pos) < 100.0) {
					char entName[256];
					Entity_GetGlobalName(ent, entName, sizeof(entName));
					if (StrEqual(entName, ""))
						GetEntPropString(ent, Prop_Data, "m_iName", entName, sizeof(entName));
					if (StrEqual(entName, "Vault Gate")) {
						if (!IsValidEntity(EntRefToEntIndex(g_iBombEnt))) {
							if (inventory_hasPlayerItem(client, "c4")) {
								if (getPoliceCount() >= 3) {
									jobs_startProgressBar(client, 600, "Plant Bomb");
								} else {
									PrintToChat(client, "[-T-] Not enough Police Officers online");
								}
							}
						}
					} else if (StrEqual(entName, "Vault Money")) {
						if (IsValidEntity(ent)) {
							jobs_startProgressBar(client, 300, "Steal Vault Money");
							g_iLastMoneyTarget[client] = EntIndexToEntRef(ent);
						}
					} else if (!doorState && StrEqual(entName, "vault_door_01")) {
						if (!IsValidEntity(EntRefToEntIndex(g_iTablesawRef))) {
							if (getPoliceCount() >= 3) {
								if (inventory_hasPlayerItem(client, "Tablesaw")) {
									if (inventory_removePlayerItems(client, "Tablesaw", 1, "Robbing Bank"))
										setupSaw(client);
								}
							} else {
								PrintToChat(client, "[-T-] Not enough Police Officers online");
							}
						} else {
							PrintToChat(client, "[-T-] Breach is already in progress");
						}
						
					}
					
					
					/* else if (StrEqual(entName, "vault_door_01")) {
						if (!doorState) {
							SetVariantString("vault_open");
							AcceptEntityInput(ent, "SetAnimation");
							doorState = true;
						} else {
							SetVariantString("vault_close");
							AcceptEntityInput(ent, "SetAnimation");
							doorState = false;
						}
					}*/
				}
			}
		}
		g_iPlayerPrevButtons[client] = iButtons;
	}
}

public void jobs_OnProgressBarInterrupted(int client, char info[64]) {
	g_iLastMoneyTarget[client] = -1;
}

public void jobs_OnProgressBarFinished(int client, char info[64]) {
	if (StrEqual(info, "Steal Vault Money")) {
		if (IsValidEdict(g_iLastMoneyTarget[client])) {
			if (IsValidEntity(EntRefToEntIndex(g_iLastMoneyTarget[client]))) {
				int amount = GetRandomInt(10, 15);
				for (int i = 0; i < amount; i++)
				inventory_givePlayerItem(client, "Stolen Money", 2500, "", "Criminal", "Stolen", 3, "Stolen from Vault");
				AcceptEntityInput(EntRefToEntIndex(g_iLastMoneyTarget[client]), "kill");
			}
		}
	} else if (StrEqual(info, "Plant Bomb")) {
		if (inventory_hasPlayerItem(client, "c4")) {
			if (getPoliceCount() >= 3) {
				if (inventory_removePlayerItems(client, "c4", 1, "planted c4")) {
					setupBomb(client);
				} else {
					PrintToChat(client, "[-T-] You dont have c4 anymore....");
				}
			} else {
				PrintToChat(client, "[-T-] Not enough Police Officers online");
			}
		}
	}
}

public Action clearEffect(Handle Timer, any ent) {
	int iEnt = EntRefToEntIndex(ent);
	AcceptEntityInput(iEnt, "kill");
}

public int getPoliceCount() {
	int count = 0;
	for (int i = 1; i < MAXPLAYERS; i++)
	if (isValidClient(i))
		if (jobs_isActiveJob(i, "Police"))
		count++;
	return count;
}

public void showHudMsg(int client, char[] message, int r, int g, int b, float x, float y, float timeout) {
	SetHudTextParams(x, y, timeout, r, g, b, 255, 0, 0.0, 0.0, 0.0);
	ShowHudText(client, -1, message);
} 