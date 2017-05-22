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
#include <rpg_npc_core>
#include <tConomy>
#include <rpg_inventory_core>
#include <autoexecconfig>
#include <hl_gangs>
#include <smlib>
#include <multicolors>

#pragma newdecls required

char bulletDiscountName[64] = "Get Discounts for Bullets at the Bulletvendor";
char my_npcType[128] = "Bullet Vendor";
int g_iGenericBulletCost = 500;
float g_fDiscountPerLevel = 0.03;

int g_iLastInteractedWith[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[T-RP] Npc: Bullet Vendor", 
	author = PLUGIN_AUTHOR, 
	description = "Adds the Bullet Vendor for T-RP", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnClientDisconnect(int client) {
	g_iLastInteractedWith[client] = -1;
}

public void OnPluginStart() {
	npc_registerNpcType(my_npcType);
}

public void OnMapStart() {
	Gangs_RegisterFeature(bulletDiscountName, 10, 100, 1.10, false);
}

public void OnNpcInteract(int client, char npcType[64], char UniqueId[128], int entIndex) {
	if (!StrEqual(my_npcType, npcType))
		return;
	g_iLastInteractedWith[client] = entIndex;
	
	showTopPanelToClient(client);
}

public void showTopPanelToClient(int client) {
	Menu BulletMenu = CreateMenu(BulletMenuHandler);
	SetMenuTitle(BulletMenu, "Bullet Vendor");
	char displayText[64];
	Format(displayText, sizeof(displayText), "Generic Bullet (%i)", g_iGenericBulletCost);
	if (tConomy_getCurrency(client) >= g_iGenericBulletCost) {
		AddMenuItem(BulletMenu, "bullet", displayText);
	} else {
		AddMenuItem(BulletMenu, "x", displayText, ITEMDRAW_DISABLED);
	}
	DisplayMenu(BulletMenu, client, 30);
}

public int BulletMenuHandler(Handle menu, MenuAction action, int client, int item) {
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
		if (StrEqual(cValue, "bullet")) {
			char weapon[64];
			if (tConomy_getCurrency(client) >= g_iGenericBulletCost) {
				int windex = Client_GetActiveWeapon(client);
				if (windex == INVALID_ENT_REFERENCE) {
					CPrintToChat(client, "[-T-] {red}Invalid Weapon");
					return;
				} else {
					Entity_GetClassName(windex, weapon, sizeof(weapon));
					if (StrContains(weapon, "knife") != -1) {
						CPrintToChat(client, "[-T-] {red}A Knife doesn't need ammo");
						return;
					}
				}
				int newClip = GetEntProp(windex, Prop_Send, "m_iPrimaryReserveAmmoCount");
				if (Gangs_HasGang(client) && Gangs_getFeatureLevel(client, bulletDiscountName) > 0) {
					char discountReason[256];
					Format(discountReason, sizeof(discountReason), "Bought Generic Bullet with Gang Discount (%i Percent)", RoundToNearest(float(Gangs_getFeatureLevel(client, bulletDiscountName)) * g_fDiscountPerLevel * 100.0));
					tConomy_removeCurrency(client, RoundToNearest(float(g_iGenericBulletCost) * (1.0 - (float(Gangs_getFeatureLevel(client, bulletDiscountName)) * g_fDiscountPerLevel))), discountReason);
				} else {
					tConomy_removeCurrency(client, g_iGenericBulletCost, "Bought Generic Bullet");
				}
				SetEntProp(windex, Prop_Send, "m_iPrimaryReserveAmmoCount", newClip + 1);
			}
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

stock bool isValidClient(int client) {
	return (1 <= client <= MaxClients && IsClientInGame(client));
} 