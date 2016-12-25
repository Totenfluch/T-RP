#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <tConomy>
#include <rpg_inventory_core>
#include <rpg_npc_core>
#include <autoexecconfig>

#pragma newdecls required

char my_npcType[128] = "Backpack Vendor";
int g_iLastInteractedWith[MAXPLAYERS + 1];


Handle g_hTinyBackpackCost;
int g_iTinyBackpackCost;

Handle g_hSmallBackpackCost;
int g_iSmallBackpackCost;

Handle g_hSMediumBackpackCost;
int g_iMediumBackpackCost;

Handle g_hLargeBackpackCost;
int g_iLargeBackpackCost;

Handle g_hBigBackpackCost;
int g_iBigBackpackCost;

Handle g_hEnormousBackpackCost;
int g_iEnormousBackpackCost;

Handle g_hGiganticBackpackCost;
int g_iGiganticBackpackCost;

public Plugin myinfo = 
{
	name = "T-RP Backpack Vendor", 
	author = PLUGIN_AUTHOR, 
	description = "Adds the backpack vendor to T-RP", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart() {
	npc_registerNpcType(my_npcType);
	
	AutoExecConfig_SetFile("rpg_npc_backpackvendor");
	AutoExecConfig_SetCreateFile(true);
	
	g_hTinyBackpackCost = AutoExecConfig_CreateConVar("rpg_tinyBackpack", "15000", "Price of the tiny backpack");
	g_hSmallBackpackCost = AutoExecConfig_CreateConVar("rpg_smallBackpack", "20000", "Price of the small backpack");
	g_hSMediumBackpackCost = AutoExecConfig_CreateConVar("rpg_mediumBackpack", "25000", "Price of the medium backpack");
	g_hLargeBackpackCost = AutoExecConfig_CreateConVar("rpg_largeBackpack", "30000", "Price of the large backpack");
	g_hBigBackpackCost = AutoExecConfig_CreateConVar("rpg_bigBackpack", "35000", "Price of the big backpack");
	g_hEnormousBackpackCost = AutoExecConfig_CreateConVar("rpg_enormousBackpack", "40000", "Price of the enormous backpack");
	g_hGiganticBackpackCost = AutoExecConfig_CreateConVar("rpg_giganticBackpack", "50000", "Price of the gigantic backpack");
	
	AutoExecConfig_CleanFile();
	AutoExecConfig_ExecuteFile();
}

public void OnConfigsExecuted() {
	g_iTinyBackpackCost = GetConVarInt(g_hTinyBackpackCost);
	g_iSmallBackpackCost = GetConVarInt(g_hSmallBackpackCost);
	g_iMediumBackpackCost = GetConVarInt(g_hSMediumBackpackCost);
	g_iLargeBackpackCost = GetConVarInt(g_hLargeBackpackCost);
	g_iBigBackpackCost = GetConVarInt(g_hBigBackpackCost);
	g_iEnormousBackpackCost = GetConVarInt(g_hEnormousBackpackCost);
	g_iGiganticBackpackCost = GetConVarInt(g_hGiganticBackpackCost);
}

public void OnNpcInteract(int client, char npcType[64], char UniqueId[128], int entIndex) {
	if (!StrEqual(my_npcType, npcType))
		return;
	g_iLastInteractedWith[client] = entIndex;
	showTopPanelToClient(client);
}

public void showTopPanelToClient(int client) {
	Menu BackpackMenu = CreateMenu(BackpackMenuHandler);
	SetMenuTitle(BackpackMenu, "Backpack Vendor");
	char displayText[64];
	Format(displayText, sizeof(displayText), "Tiny Backpack (%i)", g_iTinyBackpackCost);
	if (tConomy_getCurrency(client) >= g_iTinyBackpackCost && !inventory_hasPlayerItem(client, "Tiny Backpack")) {
		AddMenuItem(BackpackMenu, "tiny", displayText);
	} else {
		AddMenuItem(BackpackMenu, "x", displayText, ITEMDRAW_DISABLED);
	}
	
	Format(displayText, sizeof(displayText), "Small Backpack (%i)", g_iSmallBackpackCost);
	if (tConomy_getCurrency(client) >= g_iSmallBackpackCost && !inventory_hasPlayerItem(client, "Small Backpack")) {
		AddMenuItem(BackpackMenu, "small", displayText);
	} else {
		AddMenuItem(BackpackMenu, "x", displayText, ITEMDRAW_DISABLED);
	}
	
	Format(displayText, sizeof(displayText), "Medium Backpack (%i)", g_iMediumBackpackCost);
	if (tConomy_getCurrency(client) >= g_iMediumBackpackCost && !inventory_hasPlayerItem(client, "Medium Backpack") && inventory_hasPlayerItem(client, "Small Backpack")) {
		AddMenuItem(BackpackMenu, "medium", displayText);
	} else {
		AddMenuItem(BackpackMenu, "x", displayText, ITEMDRAW_DISABLED);
	}
	
	Format(displayText, sizeof(displayText), "Large Backpack (%i)", g_iLargeBackpackCost);
	if (tConomy_getCurrency(client) >= g_iLargeBackpackCost && !inventory_hasPlayerItem(client, "Large Backpack") && inventory_hasPlayerItem(client, "Medium Backpack")) {
		AddMenuItem(BackpackMenu, "large", displayText);
	} else {
		AddMenuItem(BackpackMenu, "x", displayText, ITEMDRAW_DISABLED);
	}
	
	Format(displayText, sizeof(displayText), "Big Backpack (%i)", g_iBigBackpackCost);
	if (tConomy_getCurrency(client) >= g_iBigBackpackCost && !inventory_hasPlayerItem(client, "Big Backpack") && inventory_hasPlayerItem(client, "Large Backpack")) {
		AddMenuItem(BackpackMenu, "big", displayText);
	} else {
		AddMenuItem(BackpackMenu, "x", displayText, ITEMDRAW_DISABLED);
	}
	
	Format(displayText, sizeof(displayText), "Enormous Backpack (%i)", g_iEnormousBackpackCost);
	if (tConomy_getCurrency(client) >= g_iEnormousBackpackCost && !inventory_hasPlayerItem(client, "Enormous Backpack") && inventory_hasPlayerItem(client, "Big Backpack")) {
		AddMenuItem(BackpackMenu, "enormous", displayText);
	} else {
		AddMenuItem(BackpackMenu, "x", displayText, ITEMDRAW_DISABLED);
	}
	
	Format(displayText, sizeof(displayText), "Gigantic Backpack (%i)", g_iGiganticBackpackCost);
	if (tConomy_getCurrency(client) >= g_iGiganticBackpackCost && !inventory_hasPlayerItem(client, "Gigantic Backpack") && inventory_hasPlayerItem(client, "Enormous Backpack")) {
		AddMenuItem(BackpackMenu, "gigantic", displayText);
	} else {
		AddMenuItem(BackpackMenu, "x", displayText, ITEMDRAW_DISABLED);
	}
	
	DisplayMenu(BackpackMenu, client, 60);
}

public int BackpackMenuHandler(Handle menu, MenuAction action, int client, int item) {
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
		if (StrEqual(cValue, "tiny")) {
			if (tConomy_getCurrency(client) >= g_iTinyBackpackCost) {
				if (inventory_givePlayerItem(client, "Tiny Backpack", 1, "uin", "Backpack", "Upgrade", 1, "Bought from Backpack Vendor"))
					tConomy_removeCurrency(client, g_iTinyBackpackCost, "Bought Tiny Backpack");
			}
		} else if (StrEqual(cValue, "small")) {
			if (tConomy_getCurrency(client) >= g_iSmallBackpackCost) {
				if (inventory_givePlayerItem(client, "Small Backpack", 1, "uin", "Backpack", "Upgrade", 1, "Bought from Backpack Vendor"))
					tConomy_removeCurrency(client, g_iSmallBackpackCost, "Bought Tiny Backpack");
			}
		} else if (StrEqual(cValue, "medium")) {
			if (tConomy_getCurrency(client) >= g_iMediumBackpackCost) {
				if (inventory_givePlayerItem(client, "Medium Backpack", 1, "uin", "Backpack", "Upgrade", 1, "Bought from Backpack Vendor"))
					tConomy_removeCurrency(client, g_iMediumBackpackCost, "Bought Medium Backpack");
			}
		} else if (StrEqual(cValue, "large")) {
			if (tConomy_getCurrency(client) >= g_iLargeBackpackCost) {
				if (inventory_givePlayerItem(client, "Large Backpack", 1, "uin", "Backpack", "Upgrade", 1, "Bought from Backpack Vendor"))
					tConomy_removeCurrency(client, g_iLargeBackpackCost, "Bought Large Backpack");
			}
		} else if (StrEqual(cValue, "big")) {
			if (tConomy_getCurrency(client) >= g_iBigBackpackCost) {
				if (inventory_givePlayerItem(client, "Big Backpack", 1, "uin", "Backpack", "Upgrade", 1, "Bought from Backpack Vendor"))
					tConomy_removeCurrency(client, g_iBigBackpackCost, "Bought Big Backpack");
			}
		} else if (StrEqual(cValue, "enormous")) {
			if (tConomy_getCurrency(client) >= g_iEnormousBackpackCost) {
				if (inventory_givePlayerItem(client, "Enormous Backpack", 1, "uin", "Backpack", "Upgrade", 1, "Bought from Backpack Vendor"))
					tConomy_removeCurrency(client, g_iEnormousBackpackCost, "Bought Enormous Backpack");
			}
		} else if (StrEqual(cValue, "gigantic")) {
			if (tConomy_getCurrency(client) >= g_iGiganticBackpackCost) {
				if (inventory_givePlayerItem(client, "Gigantic Backpack", 1, "uin", "Backpack", "Upgrade", 1, "Bought from Backpack Vendor"))
					tConomy_removeCurrency(client, g_iGiganticBackpackCost, "Bought Gigantic Backpack");
			}
		}
	}
}

stock bool isValidClient(int client) {
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client))
		return false;
	
	return true;
}
