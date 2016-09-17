#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <rpg_npc_core>

#pragma newdecls required

char my_npcType[128] = "weapon_vendor";

int g_iLastInteractedWith[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Weapon Vendor for T-RP", 
	author = PLUGIN_AUTHOR, 
	description = "Adds Weapon Vendors to the npc core of T-RP", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnClientDisconnect(int client) {
	g_iLastInteractedWith[client] = -1;
}

public void OnPluginStart() {
	npc_registerNpcType(my_npcType);
}

public void OnNpcInteract(int client, char npcType[64], char UniqueId[128], int entIndex) {
	if (!StrEqual(my_npcType, npcType))
		return;
	g_iLastInteractedWith[client] = entIndex;
	Handle menu = CreateMenu(weaponBuyHandler);
	SetMenuTitle(menu, "Buy from my Store!");
	AddMenuItem(menu, "ak47", "A Mighty Ak47");
	AddMenuItem(menu, "usps", "A Silent Usp");
	AddMenuItem(menu, "glock", "...Shitty Glock");
	AddMenuItem(menu, "AWP", "Allmighty AWP!");
	
	DisplayMenu(menu, client, 60);
}

public int weaponBuyHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		float playerPos[3];
		float entPos[3];
		if (!isValidClient(client))
			return;
		if (!IsValidEntity(g_iLastInteractedWith[client]))
			return;
		GetClientAbsOrigin(client, playerPos);
		GetEntPropVector(g_iLastInteractedWith[client], Prop_Data, "m_vecOrigin", entPos);
		if (GetVectorDistance(playerPos, entPos) > 100.0)
			return;
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "ak47")) {
			GivePlayerItem(client, "weapon_ak47");
		} else if (StrEqual(cValue, "usps")) {
			GivePlayerItem(client, "weapon_usp_silencer");
		} else if (StrEqual(cValue, "glock")) {
			GivePlayerItem(client, "weapon_glock");
		} else if (StrEqual(cValue, "AWP")) {
			GivePlayerItem(client, "weapon_awp");
		}
	}
}

stock bool isValidClient(int client) {
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client))
		return false;
	
	return true;
}
