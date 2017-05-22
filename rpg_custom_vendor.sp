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
#include <rpg_jobs_core>

#pragma newdecls required

#define MAX_VENDORS 12
#define MAX_ITEMS 128

enum ItemCollection {
	String:iItemname[128], 
	iWeight, 
	String:iFlags[64], 
	/*
	* i -> Invisible (doesn't show in inventory)
	* n -> Doesn't use a Player inventory slot
	* u -> Unique
	* l -> locked (can't use)
	* v -> VIP only
	*/
	String:iCategory[64], 
	String:iCategory2[64], 
	String:iJob[64], 
	iJobLevel, 
	iRarity, 
	bool:iBuyOrSell,  // Buy true
	iItemPrice, 
	String:iVendor[128],
	iVipFlag
}


int g_iLoadedItems;
int g_eLoadedItemCollection[MAX_ITEMS][ItemCollection];

int g_iDifferentNpcs;
char g_cNpcNames[MAX_VENDORS][128];

int g_iLastInteractedWith[MAXPLAYERS + 1];
char g_cLastNpcType[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[T-RP] Custom Vendors", 
	author = PLUGIN_AUTHOR, 
	description = "Adds custom Vendors with keyvalue files for T-RP", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart() {
	loadConfig();
}

public void OnMapStart() {
	loadConfig();
}

public void clearConfig() {
	g_iDifferentNpcs = 0;
	g_iLoadedItems = 0;
	for (int x = 0; x < MAX_ITEMS; x++) {
		g_eLoadedItemCollection[x][iWeight] = -1;
		g_eLoadedItemCollection[x][iRarity] = -1;
		g_eLoadedItemCollection[x][iBuyOrSell] = true;
		g_eLoadedItemCollection[x][iItemPrice] = -1;
		strcopy(g_eLoadedItemCollection[x][iItemname], 128, "");
		strcopy(g_eLoadedItemCollection[x][iFlags], 64, "");
		strcopy(g_eLoadedItemCollection[x][iCategory], 64, "");
		strcopy(g_eLoadedItemCollection[x][iCategory2], 64, "");
		strcopy(g_eLoadedItemCollection[x][iVendor], 128, "");
	}
	for (int i = 0; i < MAX_VENDORS; i++)
	strcopy(g_cNpcNames[i], 128, "");
}


public bool loadConfig() {
	clearConfig();
	
	KeyValues kv = new KeyValues("rpg_custom_vendor");
	kv.ImportFromFile("addons/sourcemod/configs/rpg_custom_vendor.txt");
	
	if (!kv.GotoFirstSubKey())
		return false;
	
	
	char buffer[128];
	do
	{
		kv.GetSectionName(buffer, sizeof(buffer));
		strcopy(g_eLoadedItemCollection[g_iLoadedItems][iItemname], 128, buffer);
		
		char tempVars[64];
		kv.GetString("flags", tempVars, 64, "");
		strcopy(g_eLoadedItemCollection[g_iLoadedItems][iFlags], 64, tempVars);
		
		kv.GetString("category", tempVars, 64, "");
		strcopy(g_eLoadedItemCollection[g_iLoadedItems][iCategory], 64, tempVars);
		
		kv.GetString("category2", tempVars, 64, "");
		strcopy(g_eLoadedItemCollection[g_iLoadedItems][iCategory2], 64, tempVars);
		
		kv.GetString("weight", tempVars, 64, "0");
		g_eLoadedItemCollection[g_iLoadedItems][iWeight] = StringToInt(tempVars);
		
		kv.GetString("rarity", tempVars, 64, "1");
		g_eLoadedItemCollection[g_iLoadedItems][iRarity] = StringToInt(tempVars);
		
		kv.GetString("price", tempVars, 64, "1337");
		g_eLoadedItemCollection[g_iLoadedItems][iItemPrice] = StringToInt(tempVars);
		
		kv.GetString("buy", tempVars, 64, "1");
		g_eLoadedItemCollection[g_iLoadedItems][iBuyOrSell] = StringToInt(tempVars) == 1;
		
		kv.GetString("job", tempVars, 64, "");
		strcopy(g_eLoadedItemCollection[g_iLoadedItems][iJob], 64, tempVars);
		
		kv.GetString("level", tempVars, 64, "0");
		g_eLoadedItemCollection[g_iLoadedItems][iJobLevel] = StringToInt(tempVars);
		
		kv.GetString("vipflag", tempVars, 64, "-1");
		g_eLoadedItemCollection[g_iLoadedItems][iVipFlag] = StringToInt(tempVars);
		
		char vendorTemp[128];
		kv.GetString("vendor", vendorTemp, 128, "Custom Vendor");
		if (tryToRegisterNewNpc(vendorTemp))
			strcopy(g_cNpcNames[g_iDifferentNpcs++], 128, vendorTemp);
		strcopy(g_eLoadedItemCollection[g_iLoadedItems][iVendor], 128, vendorTemp);
		
		
		g_iLoadedItems++;
		
	} while (kv.GotoNextKey());
	
	delete kv;
	return true;
}

public void OnNpcInteract(int client, char npcType[64], char UniqueId[128], int entIndex) {
	if (!isVendorPartOfPlugin(npcType))
		return;
	g_iLastInteractedWith[client] = entIndex;
	strcopy(g_cLastNpcType[client], 128, npcType);
	openVendorMenu(client, npcType);
}

public bool tryToRegisterNewNpc(char npcName[128]) {
	bool contained = false;
	if (StrEqual(npcName, ""))
		return false;
	for (int i = 0; i < MAX_VENDORS; i++) {
		if (StrEqual(npcName, g_cNpcNames[i]))
			contained = true;
	}
	if (!contained)
		npc_registerNpcType(npcName);
	return !contained;
}

public bool isVendorPartOfPlugin(char npcType[64]) {
	for (int i = 0; i < MAX_VENDORS; i++)
	if (StrEqual(g_cNpcNames[i], npcType))
		return true;
	return false;
}

stock bool isValidClient(int client) {
	return (1 <= client <= MaxClients && IsClientInGame(client));
}

public void openVendorMenu(int client, char npcType[64]) {
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
	
	Handle menu = CreateMenu(openVendorMenuHandler);
	for (int i = 0; i < g_iLoadedItems; i++) {
		if (StrEqual(npcType, g_eLoadedItemCollection[i][iVendor])) {
			char cId[8];
			IntToString(i, cId, sizeof(cId));
			char menuDisplay[64];
			Format(menuDisplay, sizeof(menuDisplay), "%s %s (%i)", g_eLoadedItemCollection[i][iBuyOrSell] ? "Buy":"Sell", g_eLoadedItemCollection[i][iItemname], g_eLoadedItemCollection[i][iItemPrice]);
			
			if (g_eLoadedItemCollection[i][iBuyOrSell])
				AddMenuItem(menu, cId, menuDisplay, tConomy_getCurrency(client) >= g_eLoadedItemCollection[i][iItemPrice] ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
			else {
				char itemName2[128];
				strcopy(itemName2, sizeof(itemName2), g_eLoadedItemCollection[i][iItemname]);
				AddMenuItem(menu, cId, menuDisplay, inventory_hasPlayerItem(client, itemName2) ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
			}
		}
	}
	char menuTitle[64];
	Format(menuTitle, sizeof(menuTitle), "%s", npcType);
	SetMenuTitle(menu, menuTitle);
	DisplayMenu(menu, client, 60);
}

public int openVendorMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char info[8];
		GetMenuItem(menu, item, info, sizeof(info));
		int id = StringToInt(info);
		Handle menu2 = CreateMenu(vendorItemMenuHandler);
		char menuTitle2[64];
		Format(menuTitle2, sizeof(menuTitle2), "%s %s", g_eLoadedItemCollection[id][iBuyOrSell] ? "Buy":"Sell", g_eLoadedItemCollection[id][iItemname]);
		SetMenuTitle(menu2, menuTitle2);
		char display[64];
		Format(display, sizeof(display), "Price: %i", g_eLoadedItemCollection[id][iItemPrice]);
		AddMenuItem(menu2, "x", display, ITEMDRAW_DISABLED);
		if (g_eLoadedItemCollection[id][iBuyOrSell]) {
			bool hasMoney = tConomy_getCurrency(client) >= g_eLoadedItemCollection[id][iItemPrice];
			char jobName[128];
			strcopy(jobName, sizeof(jobName), g_eLoadedItemCollection[id][iJob]);
			bool hasJob = jobs_isActiveJob(client, jobName) || StrEqual(jobName, "");
			bool hasJobLevel = (jobs_getLevel(client) >= g_eLoadedItemCollection[id][iJobLevel]) || (g_eLoadedItemCollection[id][iJobLevel] == 0);
			if (!hasJob || !hasJobLevel) {
				char requiresJobString[64];
				Format(requiresJobString, sizeof(requiresJobString), "Requires Job: %s (lvl %i)", jobName, g_eLoadedItemCollection[id][iJobLevel]);
				AddMenuItem(menu2, "x", requiresJobString, ITEMDRAW_DISABLED);
			}
			if(g_eLoadedItemCollection[id][iVipFlag] != -1){
				char requireVip[64];
				Format(requireVip, sizeof(requireVip), "Requires VIP (%i)", g_eLoadedItemCollection[id][iVipFlag]);
				AddMenuItem(menu2, "x", requireVip, ITEMDRAW_DISABLED);
			}
			int isVipFlagValid = g_eLoadedItemCollection[id][iVipFlag] != -1;
			int hasVipFlag = true;
			if(isVipFlagValid){
				hasVipFlag = CheckCommandAccess(client, "sm_vipcheck", (1 << g_eLoadedItemCollection[id][iVipFlag]), true);
			}
			
			AddMenuItem(menu2, info, "Confirm Purchase", hasMoney && hasJob && hasJobLevel && hasVipFlag ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
		} else {
			char itemName2[128];
			strcopy(itemName2, sizeof(itemName2), g_eLoadedItemCollection[id][iItemname]);
			AddMenuItem(menu2, info, "Sell", inventory_hasPlayerItem(client, itemName2) ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
			AddMenuItem(menu2, info, "Sell All", inventory_getPlayerItemAmount(client, itemName2) > 1 ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
		}
		DisplayMenu(menu2, client, 60);
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public int vendorItemMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char info[8];
		char displayText[32];
		int style = 0;
		GetMenuItem(menu, item, info, sizeof(info), style, displayText, sizeof(displayText));
		int id = StringToInt(info);
		char itemName[128];
		strcopy(itemName, sizeof(itemName), g_eLoadedItemCollection[id][iItemname]);
		
		char reason[256];
		Format(reason, sizeof(reason), "%s %s %s %s for %i", g_eLoadedItemCollection[id][iBuyOrSell] ? "Bought":"Sold", g_eLoadedItemCollection[id][iItemname], g_eLoadedItemCollection[id][iBuyOrSell] ? "from":"to", g_eLoadedItemCollection[id][iVendor], g_eLoadedItemCollection[id][iItemPrice]);
		
		if (g_eLoadedItemCollection[id][iBuyOrSell]) {
			if (tConomy_getCurrency(client) >= g_eLoadedItemCollection[id][iItemPrice]) {
				char flags[64];
				char category[64];
				char category2[64];
				strcopy(flags, sizeof(flags), g_eLoadedItemCollection[id][iFlags]);
				strcopy(category, sizeof(category), g_eLoadedItemCollection[id][iCategory]);
				strcopy(category2, sizeof(category2), g_eLoadedItemCollection[id][iCategory2]);
				
				if (inventory_givePlayerItem(client, itemName, g_eLoadedItemCollection[id][iWeight], flags, category, category2, g_eLoadedItemCollection[id][iRarity], reason))
					tConomy_removeCurrency(client, g_eLoadedItemCollection[id][iItemPrice], reason);
			}
		} else {
			if (inventory_hasPlayerItem(client, itemName)) {
				if (StrEqual(displayText, "Sell All")) {
					int amount = inventory_getPlayerItemAmount(client, itemName);
					Format(reason, sizeof(reason), "%s (%i times)", reason, amount);
					if (inventory_removePlayerItems(client, itemName, amount, reason))
						tConomy_addCurrency(client, g_eLoadedItemCollection[id][iItemPrice] * amount, reason);
				} else {
					if (inventory_removePlayerItems(client, itemName, 1, reason))
						tConomy_addCurrency(client, g_eLoadedItemCollection[id][iItemPrice], reason);
				}
			}
		}
		if (isValidClient(client))
			openVendorMenu(client, g_cLastNpcType[client]);
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}
