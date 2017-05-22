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
#include <autoexecconfig>
#include <smlib>
#include <emitsoundany>
#include <multicolors>
#include <tConomy>

#pragma newdecls required

#define MAX_Item 1024

enum Item {
	Float:gXPos, 
	Float:gYPos, 
	Float:gZPos, 
	bool:gIsActive, 
	gAuraRef, 
	gItemRef, 
	gAmount
}

int g_eActiveItems[MAX_Item][Item];
int g_iActiveItem = 0;
int g_iRunningId;


Handle g_hItemPath;
char g_cItemPath[255];

Handle g_hPickupSoundPath;
char g_cPickupSoundPath[255];

Handle g_hAuraPath;
char g_cAuraPath[255];

Handle g_hPickupEffectPath;
char g_cPickupEffectPath[255];

Handle g_hSoundMode;
int g_iSoundMode;

Handle g_hChatTag;
char g_cChatTag[64];

Handle g_hModelScale;
float g_fModelScale;

Handle g_hZAxisOffset;
float g_fZAxisOffset;


public Plugin myinfo = 
{
	name = "[T-RP] Lootdrop", 
	author = PLUGIN_AUTHOR, 
	description = "Lootdrop for T-RP", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart() {
	AutoExecConfig_SetFile("rpg_lootdrop");
	AutoExecConfig_SetCreateFile(true);
	
	g_hItemPath = AutoExecConfig_CreateConVar("rpg_itemPath", "models/props_cmh/coinpile.mdl", "Itempath of Item Spawn");
	g_hAuraPath = AutoExecConfig_CreateConVar("rpg_auraPath", "", "Particle Name of Aura (optional)");
	g_hPickupEffectPath = AutoExecConfig_CreateConVar("rpg_PickupEffectPath", "", "Particle Name of Pickup Effect (optional)");
	g_hPickupSoundPath = AutoExecConfig_CreateConVar("rpg_PickupSoundPath", "", "Sound to play when item is picked up");
	g_hSoundMode = AutoExecConfig_CreateConVar("rpg_soundMode", "2", "1 -> To Client on Pickup | 2 -> Ambient sound from Position | 3 -> Sound to all");
	g_hChatTag = AutoExecConfig_CreateConVar("rpg_chatTag", "-T-", "Chattag to append in front of all prints");
	g_hModelScale = AutoExecConfig_CreateConVar("rpg_modelScale", "1.3", "Scales the Model (Not working for all models!)");
	g_hZAxisOffset = AutoExecConfig_CreateConVar("rpg_zAxisOffset", "30.0", "Moves the Item Up and Down (can be negative)");
	
	AutoExecConfig_CleanFile();
	AutoExecConfig_ExecuteFile();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	/*
		Spawns a pile of money
		
		@Param1 -> float posX
		@Param2 -> float posY
		@Param3 -> float posZ
		@Param4 -> int amount
		
		
		@return entity Id
	*/
	CreateNative("rpg_spawnMoneyLoot", Native_spawnMoneyLoot);
}

public int Native_spawnMoneyLoot(Handle plugin, int numParams) {
	float pos[3];
	pos[0] = GetNativeCell(1);
	pos[1] = GetNativeCell(2);
	pos[2] = GetNativeCell(3);
	int amount = GetNativeCell(4);
	return spawnItem(pos, amount);
}

public void OnConfigsExecuted() {
	GetConVarString(g_hItemPath, g_cItemPath, sizeof(g_cItemPath));
	PrecacheModel(g_cItemPath, true);
	GetConVarString(g_hAuraPath, g_cAuraPath, sizeof(g_cAuraPath));
	GetConVarString(g_hPickupEffectPath, g_cPickupEffectPath, sizeof(g_cPickupEffectPath));
	GetConVarString(g_hPickupSoundPath, g_cPickupSoundPath, sizeof(g_cPickupSoundPath));
	g_iSoundMode = GetConVarInt(g_hSoundMode);
	GetConVarString(g_hChatTag, g_cChatTag, sizeof(g_cChatTag));
	g_fModelScale = GetConVarFloat(g_hModelScale);
	g_fZAxisOffset = GetConVarFloat(g_hZAxisOffset);
}

public void OnMapStart() {
	g_iRunningId = 0;
}

public int createTrigger(float pos[3], char sItemName[8]) {
	float fMiddle[3];
	int iEnt = CreateEntityByName("trigger_multiple");
	
	DispatchKeyValue(iEnt, "spawnflags", "64");
	Format(sItemName, sizeof(sItemName), "%s", sItemName);
	DispatchKeyValue(iEnt, "targetname", sItemName);
	DispatchKeyValue(iEnt, "wait", "0");
	
	DispatchSpawn(iEnt);
	ActivateEntity(iEnt);
	SetEntProp(iEnt, Prop_Data, "m_spawnflags", 64);
	
	TeleportEntity(iEnt, pos, NULL_VECTOR, NULL_VECTOR);
	SetEntityModel(iEnt, g_cItemPath);
	
	float fMins[3];
	float fMaxs[3];
	
	fMins[0] = 30.0;
	fMins[1] = 30.0;
	fMins[2] = 30.0;
	fMaxs[0] = 30.0;
	fMaxs[1] = 30.0;
	fMaxs[2] = 30.0;
	
	
	// Have the mins always be negative
	fMins[0] = fMins[0] - fMiddle[0];
	if (fMins[0] > 0.0)
		fMins[0] *= -1.0;
	fMins[1] = fMins[1] - fMiddle[1];
	if (fMins[1] > 0.0)
		fMins[1] *= -1.0;
	fMins[2] = fMins[2] - fMiddle[2];
	if (fMins[2] > 0.0)
		fMins[2] *= -1.0;
	
	// And the maxs always be positive
	fMaxs[0] = fMaxs[0] - fMiddle[0];
	if (fMaxs[0] < 0.0)
		fMaxs[0] *= -1.0;
	fMaxs[1] = fMaxs[1] - fMiddle[1];
	if (fMaxs[1] < 0.0)
		fMaxs[1] *= -1.0;
	fMaxs[2] = fMaxs[2] - fMiddle[2];
	if (fMaxs[2] < 0.0)
		fMaxs[2] *= -1.0;
	
	SetEntPropVector(iEnt, Prop_Send, "m_vecMins", fMins);
	SetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", fMaxs);
	SetEntProp(iEnt, Prop_Send, "m_nSolidType", 2);
	
	int iEffects = GetEntProp(iEnt, Prop_Send, "m_fEffects");
	iEffects |= 32;
	SetEntProp(iEnt, Prop_Send, "m_fEffects", iEffects);
	
	HookSingleEntityOutput(iEnt, "OnStartTouch", EntOut_OnStartTouch);
}

public int spawnItem(float pos[3], int amount) {
	int id = g_iRunningId++;
	g_iRunningId = g_iRunningId % 1024;
	int eventEnt = CreateEntityByName("prop_dynamic_override");
	if (eventEnt == -1)
		return -1;
	char modelPath[128];
	Format(modelPath, sizeof(modelPath), g_cItemPath);
	SetEntityModel(eventEnt, modelPath);
	//DispatchKeyValue(eventEnt, "Solid", "6");
	//SetEntProp(eventEnt, Prop_Send, "m_nSolidType", 6);
	//SetEntProp(eventEnt, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_PUSHAWAY);
	char cId[8];
	IntToString(id, cId, sizeof(cId));
	SetEntPropString(eventEnt, Prop_Data, "m_iName", cId);
	SetEntPropFloat(eventEnt, Prop_Send, "m_flModelScale", g_fModelScale);
	DispatchSpawn(eventEnt);
	
	g_eActiveItems[id][gAmount] = amount;
	
	g_eActiveItems[id][gXPos] = pos[0];
	g_eActiveItems[id][gYPos] = pos[1];
	g_eActiveItems[id][gZPos] = pos[2];
	pos[2] += g_fZAxisOffset;
	TeleportEntity(eventEnt, pos, NULL_VECTOR, NULL_VECTOR);
	Entity_SetGlobalName(eventEnt, "EventItem");
	pos[2] -= g_fZAxisOffset;
	GiveEntityAura(eventEnt, g_cAuraPath, pos);
	
	int m_iRotator = CreateEntityByName("func_rotating");
	DispatchKeyValueVector(m_iRotator, "origin", pos);
	DispatchKeyValue(m_iRotator, "targetname", "Item");
	DispatchKeyValue(m_iRotator, "maxspeed", "200");
	DispatchKeyValue(m_iRotator, "friction", "0");
	DispatchKeyValue(m_iRotator, "dmg", "0");
	DispatchKeyValue(m_iRotator, "solid", "0");
	DispatchKeyValue(m_iRotator, "spawnflags", "64");
	DispatchSpawn(m_iRotator);
	
	SetVariantString("!activator");
	AcceptEntityInput(eventEnt, "SetParent", m_iRotator, m_iRotator);
	AcceptEntityInput(m_iRotator, "Start");
	
	SetEntPropEnt(eventEnt, Prop_Send, "m_hEffectEntity", m_iRotator);
	
	HookSingleEntityOutput(eventEnt, "OnStartTouch", EntOut_OnStartTouch);
	
	createTrigger(pos, cId);
	g_eActiveItems[id][gItemRef] = EntIndexToEntRef(eventEnt);
	
	g_eActiveItems[id][gIsActive] = true;
	g_iActiveItem++;
	
	return eventEnt;
}

public void EntOut_OnStartTouch(const char[] output, int caller, int activator, float delay) {
	if (activator < 1 || activator > MaxClients || !IsClientInGame(activator) || !IsPlayerAlive(activator))
		return;
	
	char cItemId[255];
	GetEntPropString(caller, Prop_Data, "m_iName", cItemId, sizeof(cItemId));
	int ItemId = StringToInt(cItemId);
	if (ItemId == -1)
		return;
	AcceptEntityInput(caller, "kill");
	g_eActiveItems[ItemId][gIsActive] = false;
	
	AcceptEntityInput(EntRefToEntIndex(g_eActiveItems[ItemId][gItemRef]), "kill");
	g_iActiveItem--;
	
	tConomy_addCurrency(activator, g_eActiveItems[ItemId][gAmount], "Picked up Loot");
	
	float pos[3];
	GetClientAbsOrigin(activator, pos);
	
	if (!StrEqual(g_cPickupSoundPath, "")) {
		if (g_iSoundMode == 1)
			EmitSoundToClientAny(activator, g_cPickupSoundPath, activator, SNDCHAN_STATIC, _, _, 1.0, SNDPITCH_NORMAL);
		else if (g_iSoundMode == 2)
			EmitAmbientSoundAny(g_cPickupSoundPath, pos, _, _, _, _, _, _);
		else
			EmitSoundToAllAny(g_cPickupSoundPath, activator, SNDCHAN_STATIC, _, _, 1.0, SNDPITCH_NORMAL);
	}
	
	CPrintToChat(activator, "[%s] You Picked up some loot...", g_cChatTag);
	triggerEffect(pos, g_cPickupEffectPath, 2.5);
}

stock void GiveEntityAura(any ent, char aura[255], float position[3]) {
	if (StrEqual(aura, ""))
		return;
	int AuraEntity = CreateEntityByName("info_particle_system");
	DispatchKeyValue(AuraEntity, "start_active", "0");
	DispatchKeyValue(AuraEntity, "effect_name", aura);
	DispatchSpawn(AuraEntity);
	TeleportEntity(AuraEntity, position, NULL_VECTOR, NULL_VECTOR);
	ActivateEntity(AuraEntity);
	SetVariantString("!activator");
	AcceptEntityInput(AuraEntity, "SetParent", ent, AuraEntity, 0);
	CreateTimer(0.25, Timer_Run, AuraEntity);
}

stock void triggerEffect(float pos[3], char effect[255], float duration) {
	if (StrEqual(effect, ""))
		return;
	int spawnEffect = CreateEntityByName("info_particle_system");
	DispatchKeyValue(spawnEffect, "start_active", "0");
	DispatchKeyValue(spawnEffect, "effect_name", effect);
	DispatchSpawn(spawnEffect);
	ActivateEntity(spawnEffect);
	TeleportEntity(spawnEffect, pos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(spawnEffect, "Start");
	CreateTimer(duration, clearEffect, EntIndexToEntRef(spawnEffect));
}

public Action clearEffect(Handle Timer, any ent) {
	int iEnt = EntRefToEntIndex(ent);
	if (IsValidEdict(iEnt))
		if (IsValidEntity(iEnt))
		AcceptEntityInput(iEnt, "kill");
}

public Action Timer_Run(Handle Timer, any ent) {
	if (ent > 0 && IsValidEntity(ent)) {
		AcceptEntityInput(ent, "Start");
	}
} 