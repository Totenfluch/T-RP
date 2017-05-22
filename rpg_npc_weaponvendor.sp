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

#pragma newdecls required

char my_npcType[128] = "License Weapon Vendor";

int g_iLastInteractedWith[MAXPLAYERS + 1];

/* Generic */
Handle g_hKevlarPrice;
int g_iKevlarPrice;

Handle g_hHelmetKevlarPrice;
int g_iHelmetKevlarPrice;

Handle g_hFlashbangPrice;
int g_iFlashbangPrice;

Handle g_hGrenadePrice;
int g_iGrenadePrice;

Handle g_hSmokegrenadePrice;
int g_iSmokegrenadePrice;

/* PISTOL VALUES */
Handle g_hUspValue;
int g_iUspValue;

Handle g_hP2000Value;
int g_iP2000Value;

Handle g_hGlockValue;
int g_iGlockValue;

Handle g_hP250Value;
int g_iP250Value;

Handle g_hDeagleValue;
int g_iDeagleValue;

Handle g_hDualsValue;
int g_iDualsValue;

Handle g_hFivesevenValue;
int g_iFivesevenValue;

Handle g_hTecValue;
int g_iTecValue;

Handle g_hCzValue;
int g_iCzValue;


/* SMG VALUES */
Handle g_hMac10Value;
int g_iMac10Value;

Handle g_hMp7Value;
int g_iMp7Value;

Handle g_hMp9Value;
int g_iMp9Value;

Handle g_hUmp45Value;
int g_iUmp45Value;

Handle g_hBizonValue;
int g_iBizonValue;

Handle g_hP90Value;
int g_iP90Value;

/* Shotgun Values */
Handle g_hNovaValue;
int g_iNovaValue;

Handle g_hXM1014Value;
int g_iXM1014Value;

Handle g_hSawedValue;
int g_iSawedValue;

Handle g_hMag7Value;
int g_iMag7Value;

/* Rifles Menu */
Handle g_hGalilValue;
int g_iGalilValue;

Handle g_hFamasValue;
int g_iFamasValue;

Handle g_hSg553Value;
int g_iSg553Value;

Handle g_hAUGValue;
int g_iAUGValue;

Handle g_hM4A4Value;
int g_iM4A4Value;

Handle g_hM4A1SValue;
int g_iM4A1SValue;

Handle g_hAk47Value;
int g_iAk47Value;

/* Special Weapons */
Handle g_hAwpValue;
int g_iAwpValue;

Handle g_hScoutValue;
int g_iScoutValue;

Handle g_hG3SG1Value;
int g_iG3SG1Value;

Handle g_hScar20Value;
int g_iScar20Value;

Handle g_hM249Value;
int g_iM249Value;

Handle g_hNegevValue;
int g_iNegevValue;

public Plugin myinfo = 
{
	name = "[T-RP] Npc: License Weapon Vendor", 
	author = PLUGIN_AUTHOR, 
	description = "Adds a License Weapon Vendors to the npc core of T-RP", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnClientDisconnect(int client) {
	g_iLastInteractedWith[client] = -1;
}

public void OnPluginStart() {
	npc_registerNpcType(my_npcType);
	
	AutoExecConfig_SetFile("rpg_npc_weaponvendor");
	AutoExecConfig_SetCreateFile(true);
	
	g_hKevlarPrice = AutoExecConfig_CreateConVar("rpg_weaponhandler_kevlar", "350", "Price of the kevlar in menu");
	g_hHelmetKevlarPrice = AutoExecConfig_CreateConVar("rpg_weaponhandler_helmetkevlar", "350", "Price of the helmetkevlar in menu");
	g_hFlashbangPrice = AutoExecConfig_CreateConVar("rpg_weaponhandler_flashbang", "350", "Price of the flashbang in menu");
	g_hGrenadePrice = AutoExecConfig_CreateConVar("rpg_weaponhandler_grenade", "400", "Price of the grenade in menu");
	g_hSmokegrenadePrice = AutoExecConfig_CreateConVar("rpg_weaponhandler_smoke", "500", "Price of the smoke in menu");
	
	
	g_hUspValue = AutoExecConfig_CreateConVar("rpg_usp", "100", "Price of the usp in menu");
	g_hP2000Value = AutoExecConfig_CreateConVar("rpg_weaponhandler_p2000", "100", "Price of the p2000 in menu");
	g_hGlockValue = AutoExecConfig_CreateConVar("rpg_weaponhandler_glock", "200", "Price of the glock in menu");
	g_hP250Value = AutoExecConfig_CreateConVar("rpg_weaponhandler_p250", "250", "Price of the p250 in menu");
	g_hDeagleValue = AutoExecConfig_CreateConVar("rpg_weaponhandler_deagle", "250", "Price of the deagle in menu");
	g_hDualsValue = AutoExecConfig_CreateConVar("rpg_weaponhandler_duals", "300", "Price of the duals in menu");
	g_hFivesevenValue = AutoExecConfig_CreateConVar("rpg_weaponhandler_fiveseven", "300", "Price of the fiveseven in menu");
	g_hTecValue = AutoExecConfig_CreateConVar("rpg_weaponhandler_tec9", "350", "Price of the tec9 in menu");
	g_hCzValue = AutoExecConfig_CreateConVar("rpg_weaponhandler_cz", "350", "Price of the cz in menu");
	
	g_hMac10Value = AutoExecConfig_CreateConVar("rpg_weaponhandler_mac10", "300", "Price of the Mac10 in menu");
	g_hMp7Value = AutoExecConfig_CreateConVar("rpg_weaponhandler_mp7", "350", "Price of the Mp7 in menu");
	g_hMp9Value = AutoExecConfig_CreateConVar("rpg_weaponhandler_mp9", "350", "Price of the Mp9 in menu");
	g_hUmp45Value = AutoExecConfig_CreateConVar("rpg_weaponhandler_ump45", "350", "Price of the Ump45 in menu");
	g_hBizonValue = AutoExecConfig_CreateConVar("rpg_weaponhandler_bizon", "400", "Price of the Bizon in menu");
	g_hP90Value = AutoExecConfig_CreateConVar("rpg_weaponhandler_p90", "500", "Price of the P90 in menu");
	
	g_hNovaValue = AutoExecConfig_CreateConVar("rpg_weaponhandler_nova", "500", "Price of the nova in menu");
	g_hXM1014Value = AutoExecConfig_CreateConVar("rpg_weaponhandler_xm1014", "600", "Price of the XM1014 in menu");
	g_hSawedValue = AutoExecConfig_CreateConVar("rpg_weaponhandler_sawed", "550", "Price of the Sawed in menu");
	g_hMag7Value = AutoExecConfig_CreateConVar("rpg_weaponhandler_mag7", "650", "Price of the Mag7 in menu");
	
	g_hGalilValue = AutoExecConfig_CreateConVar("rpg_weaponhandler_galil", "600", "Price of the Galil in menu");
	g_hFamasValue = AutoExecConfig_CreateConVar("rpg_weaponhandler_famas", "650", "Price of the Famas in menu");
	g_hSg553Value = AutoExecConfig_CreateConVar("rpg_weaponhandler_sg553", "1000", "Price of the Sg553 in menu");
	g_hAUGValue = AutoExecConfig_CreateConVar("rpg_weaponhandler_aug", "1000", "Price of the Aug in menu");
	g_hM4A4Value = AutoExecConfig_CreateConVar("rpg_weaponhandler_m4a4", "1250", "Price of the M4a4 in menu");
	g_hM4A1SValue = AutoExecConfig_CreateConVar("rpg_weaponhandler_m4a1s", "1500", "Price of the M4a1s in menu");
	g_hAk47Value = AutoExecConfig_CreateConVar("rpg_weaponhandler_ak47", "1500", "Price of the Ak47 in menu");
	
	g_hAwpValue = AutoExecConfig_CreateConVar("rpg_weaponhandler_awp", "2000", "Price of the awp in menu");
	g_hScoutValue = AutoExecConfig_CreateConVar("rpg_weaponhandler_scout", "1200", "Price of the scout in menu");
	g_hG3SG1Value = AutoExecConfig_CreateConVar("rpg_weaponhandler_g3sg1", "2500", "Price of the g3sg1 in menu");
	g_hScar20Value = AutoExecConfig_CreateConVar("rpg_weaponhandler_scar", "2500", "Price of the scar in menu");
	g_hM249Value = AutoExecConfig_CreateConVar("rpg_weaponhandler_m249", "2000", "Price of the m249 in menu");
	g_hNegevValue = AutoExecConfig_CreateConVar("rpg_weaponhandler_negev", "2250", "Price of the negev in menu");
	
	AutoExecConfig_CleanFile();
	AutoExecConfig_ExecuteFile();
}

public void OnConfigsExecuted() {
	g_iKevlarPrice = GetConVarInt(g_hKevlarPrice);
	g_iHelmetKevlarPrice = GetConVarInt(g_hHelmetKevlarPrice);
	g_iFlashbangPrice = GetConVarInt(g_hFlashbangPrice);
	g_iGrenadePrice = GetConVarInt(g_hGrenadePrice);
	g_iSmokegrenadePrice = GetConVarInt(g_hSmokegrenadePrice);
	
	g_iUspValue = GetConVarInt(g_hUspValue);
	g_iP2000Value = GetConVarInt(g_hP2000Value);
	g_iGlockValue = GetConVarInt(g_hGlockValue);
	g_iP250Value = GetConVarInt(g_hP250Value);
	g_iDeagleValue = GetConVarInt(g_hDeagleValue);
	g_iDualsValue = GetConVarInt(g_hDualsValue);
	g_iFivesevenValue = GetConVarInt(g_hFivesevenValue);
	g_iTecValue = GetConVarInt(g_hTecValue);
	g_iCzValue = GetConVarInt(g_hCzValue);
	
	g_iMac10Value = GetConVarInt(g_hMac10Value);
	g_iMp7Value = GetConVarInt(g_hMp7Value);
	g_iMp9Value = GetConVarInt(g_hMp9Value);
	g_iUmp45Value = GetConVarInt(g_hUmp45Value);
	g_iBizonValue = GetConVarInt(g_hBizonValue);
	g_iP90Value = GetConVarInt(g_hP90Value);
	
	g_iNovaValue = GetConVarInt(g_hNovaValue);
	g_iXM1014Value = GetConVarInt(g_hXM1014Value);
	g_iSawedValue = GetConVarInt(g_hSawedValue);
	g_iMag7Value = GetConVarInt(g_hMag7Value);
	
	g_iGalilValue = GetConVarInt(g_hGalilValue);
	g_iFamasValue = GetConVarInt(g_hFamasValue);
	g_iSg553Value = GetConVarInt(g_hSg553Value);
	g_iAUGValue = GetConVarInt(g_hAUGValue);
	g_iM4A4Value = GetConVarInt(g_hM4A4Value);
	g_iM4A1SValue = GetConVarInt(g_hM4A1SValue);
	g_iAk47Value = GetConVarInt(g_hAk47Value);
	
	g_iAwpValue = GetConVarInt(g_hAwpValue);
	g_iScoutValue = GetConVarInt(g_hScoutValue);
	g_iG3SG1Value = GetConVarInt(g_hG3SG1Value);
	g_iScar20Value = GetConVarInt(g_hScar20Value);
	g_iM249Value = GetConVarInt(g_hM249Value);
	g_iNegevValue = GetConVarInt(g_hNegevValue);
}

public void OnNpcInteract(int client, char npcType[64], char UniqueId[128], int entIndex) {
	if (!StrEqual(my_npcType, npcType))
		return;
	g_iLastInteractedWith[client] = entIndex;
	
	showTopPanelToClient(client);
}

public void showTopPanelToClient(int client) {
	Panel wPanel = CreatePanel();
	SetPanelTitle(wPanel, "Licensed Weapon Vendor");
	DrawPanelText(wPanel, "^-.-^-.-^-.-^-.-^");
	if (inventory_hasPlayerItem(client, "Pistol License"))
		DrawPanelItem(wPanel, "Pistols");
	else
		DrawPanelItem(wPanel, "Pistols (requires License)", ITEMDRAW_DISABLED);
	
	if (inventory_hasPlayerItem(client, "SMG License"))
		DrawPanelItem(wPanel, "SMGs");
	else
		DrawPanelItem(wPanel, "SMGs (requires License)", ITEMDRAW_DISABLED);
	
	if (inventory_hasPlayerItem(client, "Shotgun License"))
		DrawPanelItem(wPanel, "Shotguns");
	else
		DrawPanelItem(wPanel, "Shotguns (requires License)", ITEMDRAW_DISABLED);
	
	if (inventory_hasPlayerItem(client, "Rifle License"))
		DrawPanelItem(wPanel, "Rifles");
	else
		DrawPanelItem(wPanel, "Rifles (requires License)", ITEMDRAW_DISABLED);
	
	if (inventory_hasPlayerItem(client, "Special Weapon License"))
		DrawPanelItem(wPanel, "Special Weapons");
	else
		DrawPanelItem(wPanel, "Special Weapons (requires License)", ITEMDRAW_DISABLED);
	
	if (inventory_hasPlayerItem(client, "Nade License"))
		DrawPanelItem(wPanel, "Nades & Armour");
	else
		DrawPanelItem(wPanel, "Nades & Armour (requires License)", ITEMDRAW_DISABLED);
	
	DrawPanelText(wPanel, "^-.-^-.-^-.-^-.-^");
	DrawPanelItem(wPanel, "Exit");
	SendPanelToClient(wPanel, client, LicensedWeaponVendorHandler, 60);
}


public int LicensedWeaponVendorHandler(Handle menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select) {
		if (item == 1) {
			showPistolsPanelToClient(client);
		} else if (item == 2) {
			showSMGPanelToClient(client);
		} else if (item == 3) {
			showShotgunPanelToClient(client);
		} else if (item == 4) {
			showRiflesPanelToClient(client);
		} else if (item == 5) {
			showSpecialWeaponsPanelToClient(client);
		} else if (item == 6) {
			showArmorHpPanelToClient(client);
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void showPistolsPanelToClient(int client) {
	int Money = tConomy_getCurrency(client);
	Handle rpgPanel = CreateMenu(pistolsPanelHandler);
	char panelTitle[128];
	Format(panelTitle, sizeof(panelTitle), "Pistols Menu (%i)", Money);
	SetMenuTitle(rpgPanel, panelTitle);
	char uspItem[64];
	Format(uspItem, sizeof(uspItem), "USP-S - %i Money", g_iUspValue);
	if (Money >= g_iUspValue)
		AddMenuItem(rpgPanel, "1", uspItem);
	else
		AddMenuItem(rpgPanel, "1", uspItem, ITEMDRAW_DISABLED);
	char p200Item[64];
	Format(p200Item, sizeof(p200Item), "P2000 - %i Money", g_iP2000Value);
	if (Money >= g_iP2000Value)
		AddMenuItem(rpgPanel, "2", p200Item);
	else
		AddMenuItem(rpgPanel, "2", p200Item, ITEMDRAW_DISABLED);
	char glockItem[64];
	Format(glockItem, sizeof(glockItem), "Glock - %i Money", g_iGlockValue);
	if (Money >= g_iGlockValue)
		AddMenuItem(rpgPanel, "3", glockItem);
	else
		AddMenuItem(rpgPanel, "3", glockItem, ITEMDRAW_DISABLED);
	char P250Item[64];
	Format(P250Item, sizeof(P250Item), "P250 - %i Money", g_iP250Value);
	if (Money >= g_iP250Value)
		AddMenuItem(rpgPanel, "4", P250Item);
	else
		AddMenuItem(rpgPanel, "4", P250Item, ITEMDRAW_DISABLED);
	char DeagleItem[64];
	Format(DeagleItem, sizeof(DeagleItem), "Dessert Eagle - %i Money", g_iDeagleValue);
	if (Money >= g_iDeagleValue)
		AddMenuItem(rpgPanel, "5", DeagleItem);
	else
		AddMenuItem(rpgPanel, "5", DeagleItem, ITEMDRAW_DISABLED);
	char DualsItem[64];
	Format(DualsItem, sizeof(DualsItem), "Dual Berratas - %i Money", g_iDualsValue);
	if (Money >= g_iDualsValue)
		AddMenuItem(rpgPanel, "6", DualsItem);
	else
		AddMenuItem(rpgPanel, "6", DualsItem, ITEMDRAW_DISABLED);
	char Fiveseven[64];
	Format(Fiveseven, sizeof(Fiveseven), "FiveSeven - %i Money", g_iFivesevenValue);
	if (Money >= g_iFivesevenValue)
		AddMenuItem(rpgPanel, "7", Fiveseven);
	else
		AddMenuItem(rpgPanel, "7", Fiveseven, ITEMDRAW_DISABLED);
	char TecItem[64];
	Format(TecItem, sizeof(TecItem), "Tec-9 - %i Money", g_iTecValue);
	if (Money >= g_iTecValue)
		AddMenuItem(rpgPanel, "8", TecItem);
	else
		AddMenuItem(rpgPanel, "8", TecItem, ITEMDRAW_DISABLED);
	char CzItem[64];
	Format(CzItem, sizeof(CzItem), "CZ75 Auto - %i Money", g_iCzValue);
	if (Money >= g_iCzValue)
		AddMenuItem(rpgPanel, "9", CzItem);
	else
		AddMenuItem(rpgPanel, "9", CzItem, ITEMDRAW_DISABLED);
	
	DisplayMenu(rpgPanel, client, 60);
}

public int pistolsPanelHandler(Handle menu, MenuAction action, int client, int item) {
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
		char info[64];
		GetMenuItem(menu, item, info, sizeof(info));
		int id = StringToInt(info);
		if (id == 1) {
			if (tConomy_removeCurrency(client, g_iUspValue, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_usp_silencer");
		} else if (id == 2) {
			if (tConomy_removeCurrency(client, g_iP2000Value, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_hkp2000");
		} else if (id == 3) {
			if (tConomy_removeCurrency(client, g_iGlockValue, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_glock");
		} else if (id == 4) {
			if (tConomy_removeCurrency(client, g_iP250Value, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_p250");
		} else if (id == 5) {
			if (tConomy_removeCurrency(client, g_iDeagleValue, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_deagle");
		} else if (id == 6) {
			if (tConomy_removeCurrency(client, g_iDualsValue, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_elite");
		} else if (id == 7) {
			if (tConomy_removeCurrency(client, g_iFivesevenValue, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_fiveseven");
		} else if (id == 8) {
			if (tConomy_removeCurrency(client, g_iTecValue, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_tec9");
		} else if (id == 9) {
			if (tConomy_removeCurrency(client, g_iCzValue, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_cz75a");
		}
	} else if (action == MenuAction_Cancel) {
		showTopPanelToClient(client);
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void showSMGPanelToClient(int client) {
	int Money = tConomy_getCurrency(client);
	Handle rpgPanel = CreateMenu(SMGPanelHandler);
	char panelTitle[128];
	Format(panelTitle, sizeof(panelTitle), "Submachine Guns Menu (%i)", Money);
	SetMenuTitle(rpgPanel, panelTitle);
	char mac10Item[64];
	Format(mac10Item, sizeof(mac10Item), "Mac-10 - %i Money", g_iMac10Value);
	if (Money >= g_iMac10Value)
		AddMenuItem(rpgPanel, "1", mac10Item);
	else
		AddMenuItem(rpgPanel, "1", mac10Item, ITEMDRAW_DISABLED);
	char mp7Item[64];
	Format(mp7Item, sizeof(mp7Item), "MP7 - %i Money", g_iMp7Value);
	if (Money >= g_iMp7Value)
		AddMenuItem(rpgPanel, "2", mp7Item);
	else
		AddMenuItem(rpgPanel, "2", mp7Item, ITEMDRAW_DISABLED);
	char mp9Item[64];
	Format(mp9Item, sizeof(mp9Item), "MP9 - %i Money", g_iMp9Value);
	if (Money >= g_iMp9Value)
		AddMenuItem(rpgPanel, "3", mp9Item);
	else
		AddMenuItem(rpgPanel, "3", mp9Item, ITEMDRAW_DISABLED);
	char ump45Item[64];
	Format(ump45Item, sizeof(ump45Item), "UMP-45 - %i Money", g_iUmp45Value);
	if (Money >= g_iUmp45Value)
		AddMenuItem(rpgPanel, "4", ump45Item);
	else
		AddMenuItem(rpgPanel, "4", ump45Item, ITEMDRAW_DISABLED);
	char bizonItem[64];
	Format(bizonItem, sizeof(bizonItem), "PP-Bizon - %i Money", g_iBizonValue);
	if (Money >= g_iBizonValue)
		AddMenuItem(rpgPanel, "5", bizonItem);
	else
		AddMenuItem(rpgPanel, "5", bizonItem, ITEMDRAW_DISABLED);
	char p90Item[64];
	Format(p90Item, sizeof(p90Item), "P90 - %i Money", g_iP90Value);
	if (Money >= g_iP90Value)
		AddMenuItem(rpgPanel, "6", p90Item);
	else
		AddMenuItem(rpgPanel, "6", p90Item, ITEMDRAW_DISABLED);
	
	DisplayMenu(rpgPanel, client, 60);
}

public int SMGPanelHandler(Handle menu, MenuAction action, int client, int item) {
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
		char info[64];
		GetMenuItem(menu, item, info, sizeof(info));
		int id = StringToInt(info);
		if (id == 1) {
			if (tConomy_removeCurrency(client, g_iMac10Value, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_mac10");
		} else if (id == 2) {
			if (tConomy_removeCurrency(client, g_iMp7Value, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_mp7");
		} else if (id == 3) {
			if (tConomy_removeCurrency(client, g_iMp9Value, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_mp9");
		} else if (id == 4) {
			if (tConomy_removeCurrency(client, g_iUmp45Value, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_ump45");
		} else if (id == 5) {
			if (tConomy_removeCurrency(client, g_iBizonValue, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_bizon");
		} else if (id == 6) {
			if (tConomy_removeCurrency(client, g_iP90Value, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_p90");
		}
	} else if (action == MenuAction_Cancel) {
		showTopPanelToClient(client);
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void showShotgunPanelToClient(int client) {
	int Money = tConomy_getCurrency(client);
	Handle rpgPanel = CreateMenu(ShotgunPanelHandler);
	char panelTitle[128];
	Format(panelTitle, sizeof(panelTitle), "Shotguns Menu (%i)", Money);
	SetMenuTitle(rpgPanel, panelTitle);
	char novaItem[64];
	Format(novaItem, sizeof(novaItem), "Nova - %i Money", g_iNovaValue);
	if (Money >= g_iNovaValue)
		AddMenuItem(rpgPanel, "1", novaItem);
	else
		AddMenuItem(rpgPanel, "1", novaItem, ITEMDRAW_DISABLED);
	char XMItem[64];
	Format(XMItem, sizeof(XMItem), "XM1014 - %i Money", g_iXM1014Value);
	if (Money >= g_iXM1014Value)
		AddMenuItem(rpgPanel, "2", XMItem);
	else
		AddMenuItem(rpgPanel, "2", XMItem, ITEMDRAW_DISABLED);
	char SawedItem[64];
	Format(SawedItem, sizeof(SawedItem), "Sawed Off - %i Money", g_iSawedValue);
	if (Money >= g_iSawedValue)
		AddMenuItem(rpgPanel, "3", SawedItem);
	else
		AddMenuItem(rpgPanel, "3", SawedItem, ITEMDRAW_DISABLED);
	char Mag7Item[64];
	Format(Mag7Item, sizeof(Mag7Item), "MAG-7 - %i Money", g_iMag7Value);
	if (Money >= g_iMag7Value)
		AddMenuItem(rpgPanel, "4", Mag7Item);
	else
		AddMenuItem(rpgPanel, "4", Mag7Item, ITEMDRAW_DISABLED);
	
	DisplayMenu(rpgPanel, client, 60);
}

public int ShotgunPanelHandler(Handle menu, MenuAction action, int client, int item) {
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
		char info[64];
		GetMenuItem(menu, item, info, sizeof(info));
		int id = StringToInt(info);
		if (id == 1) {
			if (tConomy_removeCurrency(client, g_iNovaValue, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_nova");
		} else if (id == 2) {
			if (tConomy_removeCurrency(client, g_iXM1014Value, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_xm1014");
		} else if (id == 3) {
			if (tConomy_removeCurrency(client, g_iSawedValue, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_sawedoff");
		} else if (id == 4) {
			if (tConomy_removeCurrency(client, g_iMag7Value, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_mag7");
		}
	} else if (action == MenuAction_Cancel) {
		showTopPanelToClient(client);
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void showRiflesPanelToClient(int client) {
	int Money = tConomy_getCurrency(client);
	Handle rpgPanel = CreateMenu(RiflesPanelHandler);
	char panelTitle[128];
	Format(panelTitle, sizeof(panelTitle), "Rifles Menu (%i)", Money);
	SetMenuTitle(rpgPanel, panelTitle);
	char galilItem[64];
	Format(galilItem, sizeof(galilItem), "Galil AR - %i Money", g_iGalilValue);
	if (Money >= g_iGalilValue)
		AddMenuItem(rpgPanel, "1", galilItem);
	else
		AddMenuItem(rpgPanel, "1", galilItem, ITEMDRAW_DISABLED);
	char famasItem[64];
	Format(famasItem, sizeof(famasItem), "Famas - %i Money", g_iFamasValue);
	if (Money >= g_iFamasValue)
		AddMenuItem(rpgPanel, "2", famasItem);
	else
		AddMenuItem(rpgPanel, "2", famasItem, ITEMDRAW_DISABLED);
	char sgValue[64];
	Format(sgValue, sizeof(sgValue), "SG 553 - %i Money", g_iSg553Value);
	if (Money >= g_iSg553Value)
		AddMenuItem(rpgPanel, "3", sgValue);
	else
		AddMenuItem(rpgPanel, "3", sgValue, ITEMDRAW_DISABLED);
	char augItem[64];
	Format(augItem, sizeof(augItem), "AUG - %i Money", g_iAUGValue);
	if (Money >= g_iAUGValue)
		AddMenuItem(rpgPanel, "4", augItem);
	else
		AddMenuItem(rpgPanel, "4", augItem, ITEMDRAW_DISABLED);
	char M4a4Item[64];
	Format(M4a4Item, sizeof(M4a4Item), "M4A4 - %i Money", g_iM4A4Value);
	if (Money >= g_iM4A4Value)
		AddMenuItem(rpgPanel, "5", M4a4Item);
	else
		AddMenuItem(rpgPanel, "5", M4a4Item, ITEMDRAW_DISABLED);
	char m4a1sValue[64];
	Format(m4a1sValue, sizeof(m4a1sValue), "M4A1-S - %i Money", g_iM4A1SValue);
	if (Money >= g_iM4A1SValue)
		AddMenuItem(rpgPanel, "6", m4a1sValue);
	else
		AddMenuItem(rpgPanel, "6", m4a1sValue, ITEMDRAW_DISABLED);
	char ak47Item[64];
	Format(ak47Item, sizeof(ak47Item), "AK-47 - %i Money", g_iAk47Value);
	if (Money >= g_iAk47Value)
		AddMenuItem(rpgPanel, "7", ak47Item);
	else
		AddMenuItem(rpgPanel, "7", ak47Item, ITEMDRAW_DISABLED);
	
	DisplayMenu(rpgPanel, client, 60);
}

public int RiflesPanelHandler(Handle menu, MenuAction action, int client, int item) {
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
		char info[64];
		GetMenuItem(menu, item, info, sizeof(info));
		int id = StringToInt(info);
		if (id == 1) {
			if (tConomy_removeCurrency(client, g_iGalilValue, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_galilar");
		} else if (id == 2) {
			if (tConomy_removeCurrency(client, g_iFamasValue, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_famas");
		} else if (id == 3) {
			if (tConomy_removeCurrency(client, g_iSg553Value, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_sg556");
		} else if (id == 4) {
			if (tConomy_removeCurrency(client, g_iAUGValue, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_aug");
		} else if (id == 5) {
			if (tConomy_removeCurrency(client, g_iM4A4Value, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_m4a1");
		} else if (id == 6) {
			if (tConomy_removeCurrency(client, g_iM4A1SValue, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_m4a1_silencer");
		} else if (id == 7) {
			if (tConomy_removeCurrency(client, g_iAk47Value, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_ak47");
		}
	} else if (action == MenuAction_Cancel) {
		showTopPanelToClient(client);
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void showArmorHpPanelToClient(int client) {
	int Money = tConomy_getCurrency(client);
	Handle rpgPanel = CreateMenu(ArmorAndHPPanelHandler);
	char panelTitle[128];
	Format(panelTitle, sizeof(panelTitle), "Armor & Grenades (%i)", Money);
	SetMenuTitle(rpgPanel, panelTitle);
	char kevlarItem[64];
	Format(kevlarItem, sizeof(kevlarItem), "Kevlar - %i Money", g_iKevlarPrice);
	if (Money >= g_iKevlarPrice)
		AddMenuItem(rpgPanel, "2", kevlarItem);
	else
		AddMenuItem(rpgPanel, "2", kevlarItem, ITEMDRAW_DISABLED);
	char kevlarHelmetItem[64];
	Format(kevlarHelmetItem, sizeof(kevlarHelmetItem), "Kevlar and Helmet - %i Money", g_iHelmetKevlarPrice);
	if (Money >= g_iHelmetKevlarPrice)
		AddMenuItem(rpgPanel, "3", kevlarHelmetItem);
	else
		AddMenuItem(rpgPanel, "3", kevlarHelmetItem, ITEMDRAW_DISABLED);
	char flashbangItem[64];
	Format(flashbangItem, sizeof(flashbangItem), "Flasbang - %i Money", g_iFlashbangPrice);
	if (Money >= g_iFlashbangPrice)
		AddMenuItem(rpgPanel, "4", flashbangItem);
	else
		AddMenuItem(rpgPanel, "4", flashbangItem, ITEMDRAW_DISABLED);
	char GrenadeItem[64];
	Format(GrenadeItem, sizeof(GrenadeItem), "HEGrenade - %i Money", g_iGrenadePrice);
	if (Money >= g_iGrenadePrice)
		AddMenuItem(rpgPanel, "5", GrenadeItem);
	else
		AddMenuItem(rpgPanel, "5", GrenadeItem, ITEMDRAW_DISABLED);
	char smokegrenadeItem[64];
	Format(smokegrenadeItem, sizeof(smokegrenadeItem), "Smokegrenade - %i Money", g_iSmokegrenadePrice);
	if (Money >= g_iSmokegrenadePrice)
		AddMenuItem(rpgPanel, "6", smokegrenadeItem);
	else
		AddMenuItem(rpgPanel, "6", smokegrenadeItem, ITEMDRAW_DISABLED);
	
	DisplayMenu(rpgPanel, client, 60);
}

public int ArmorAndHPPanelHandler(Handle menu, MenuAction action, int client, int item) {
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
		char info[64];
		GetMenuItem(menu, item, info, sizeof(info));
		int id = StringToInt(info);
		if (id == 2) {
			if (tConomy_removeCurrency(client, g_iKevlarPrice, "Bought Item from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "item_kevlar");
		} else if (id == 3) {
			if (tConomy_removeCurrency(client, g_iHelmetKevlarPrice, "Bought Item from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "item_assaultsuit");
		} else if (id == 4) {
			if (tConomy_removeCurrency(client, g_iFlashbangPrice, "Bought Item from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_flashbang");
		} else if (id == 5) {
			if (tConomy_removeCurrency(client, g_iGrenadePrice, "Bought Item from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_hegrenade");
		} else if (id == 6) {
			if (tConomy_removeCurrency(client, g_iSmokegrenadePrice, "Bought Item from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_smokegrenade");
		}
	} else if (action == MenuAction_Cancel) {
		showTopPanelToClient(client);
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void showSpecialWeaponsPanelToClient(int client) {
	int Money = tConomy_getCurrency(client);
	Handle rpgPanel = CreateMenu(SpecialWeaponsPanelHandler);
	char panelTitle[128];
	Format(panelTitle, sizeof(panelTitle), "Special Weapons Menu (%i)", Money);
	SetMenuTitle(rpgPanel, panelTitle);
	char awpItem[64];
	Format(awpItem, sizeof(awpItem), "AWP - %i Money", g_iAwpValue);
	if (Money >= g_iAwpValue)
		AddMenuItem(rpgPanel, "1", awpItem);
	else
		AddMenuItem(rpgPanel, "1", awpItem, ITEMDRAW_DISABLED);
	char scoutItem[64];
	Format(scoutItem, sizeof(scoutItem), "SSG 08 (Scout) - %i Money", g_iScoutValue);
	if (Money >= g_iScoutValue)
		AddMenuItem(rpgPanel, "2", scoutItem);
	else
		AddMenuItem(rpgPanel, "2", scoutItem, ITEMDRAW_DISABLED);
	char g3sg1Item[64];
	Format(g3sg1Item, sizeof(g3sg1Item), "G3SG1 - %i Money", g_iG3SG1Value);
	if (Money >= g_iG3SG1Value)
		AddMenuItem(rpgPanel, "3", g3sg1Item);
	else
		AddMenuItem(rpgPanel, "3", g3sg1Item, ITEMDRAW_DISABLED);
	char Scar20Item[64];
	Format(Scar20Item, sizeof(Scar20Item), "SCAR-20 - %i Money", g_iScar20Value);
	if (Money >= g_iScar20Value)
		AddMenuItem(rpgPanel, "4", Scar20Item);
	else
		AddMenuItem(rpgPanel, "4", Scar20Item, ITEMDRAW_DISABLED);
	char m249Item[64];
	Format(m249Item, sizeof(m249Item), "M249 - %i Money", g_iM249Value);
	if (Money >= g_iM249Value)
		AddMenuItem(rpgPanel, "5", m249Item);
	else
		AddMenuItem(rpgPanel, "5", m249Item, ITEMDRAW_DISABLED);
	char NegevItem[64];
	Format(NegevItem, sizeof(NegevItem), "Negev - %i Money", g_iNegevValue);
	if (Money >= g_iNegevValue)
		AddMenuItem(rpgPanel, "6", NegevItem);
	else
		AddMenuItem(rpgPanel, "6", NegevItem, ITEMDRAW_DISABLED);
	
	
	DisplayMenu(rpgPanel, client, 60);
}

public int SpecialWeaponsPanelHandler(Handle menu, MenuAction action, int client, int item) {
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
		char info[64];
		GetMenuItem(menu, item, info, sizeof(info));
		int id = StringToInt(info);
		if (id == 1) {
			if (tConomy_removeCurrency(client, g_iAwpValue, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_awp");
		} else if (id == 2) {
			if (tConomy_removeCurrency(client, g_iScoutValue, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_ssg08");
		} else if (id == 3) {
			if (tConomy_removeCurrency(client, g_iG3SG1Value, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_g3sg1");
		} else if (id == 4) {
			if (tConomy_removeCurrency(client, g_iScar20Value, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_scar20");
		} else if (id == 5) {
			if (tConomy_removeCurrency(client, g_iM249Value, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_m249");
		} else if (id == 6) {
			if (tConomy_removeCurrency(client, g_iNegevValue, "Bought Weapon from License Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_negev");
		}
	} else if (action == MenuAction_Cancel) {
		showTopPanelToClient(client);
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void t_GiveClientItem(int client, char[] weaponItem) {
	char item[128];
	strcopy(item, sizeof(item), weaponItem);
	inventory_givePlayerItem(client, item, 0, "", "License Weapon", "Weapon", 1, "Bought from License Weapon Vendor");
}

stock bool isValidClient(int client) {
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client))
		return false;
	
	return true;
}
