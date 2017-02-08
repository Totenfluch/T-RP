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

char my_npcType[128] = "License Vendor";
int g_iLastInteractedWith[MAXPLAYERS + 1];

Handle g_hPistolLicense;
int g_iPistolLicense;

Handle g_hSMGLicense;
int g_iSMGLicense;

Handle g_hShotgunLicense;
int g_iShotgunLicense;

Handle g_hSpecialweaponLicense;
int g_iSpecialweaponLicense;

Handle g_hRifleLicense;
int g_iRifleLicense;

Handle g_hGrenadeLicense;
int g_iGrenadeLicense;

Handle g_hBikeLicense;
int g_iBikeLicense;

Handle g_hCarLicense;
int g_iCarLicense;


public Plugin myinfo = 
{
	name = "License Vendor for T-RP", 
	author = PLUGIN_AUTHOR, 
	description = "Adds Licenses for T-RP", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart() {
	AutoExecConfig_SetFile("rpg_npc_licensevendor");
	AutoExecConfig_SetCreateFile(true);
	
	g_hPistolLicense = AutoExecConfig_CreateConVar("rpg_pistollicense", "1500", "Price of the Pistol License");
	g_hSMGLicense = AutoExecConfig_CreateConVar("rpg_smglicense", "2000", "Price of the SMG License");
	g_hShotgunLicense = AutoExecConfig_CreateConVar("rpg_shotgunlicense", "2500", "Price of the Shotgun License");
	g_hSpecialweaponLicense = AutoExecConfig_CreateConVar("rpg_specialweaponlicense", "3000", "Price of the Special Weapon License");
	g_hRifleLicense = AutoExecConfig_CreateConVar("rpg_riflelicense", "3500", "Price of the Rifle License");
	g_hGrenadeLicense = AutoExecConfig_CreateConVar("rpg_grenadelicense", "4000", "Price of the Grenade License");
	g_hBikeLicense = AutoExecConfig_CreateConVar("rpg_bikelicense", "5000", "Price of the Bike License");
	g_hCarLicense = AutoExecConfig_CreateConVar("rpg_carlicense", "5000", "Price of the Car License");
	
	AutoExecConfig_CleanFile();
	AutoExecConfig_ExecuteFile();
}

public void OnConfigsExecuted() {
	g_iPistolLicense = GetConVarInt(g_hPistolLicense);
	g_iSMGLicense = GetConVarInt(g_hSMGLicense);
	g_iShotgunLicense = GetConVarInt(g_hShotgunLicense);
	g_iSpecialweaponLicense = GetConVarInt(g_hSpecialweaponLicense);
	g_iRifleLicense = GetConVarInt(g_hRifleLicense);
	g_iGrenadeLicense = GetConVarInt(g_hGrenadeLicense);
	g_iBikeLicense = GetConVarInt(g_hBikeLicense);
	g_iCarLicense = GetConVarInt(g_hCarLicense);
}

public void OnMapStart() {
	npc_registerNpcType(my_npcType);
}

public void OnNpcInteract(int client, char npcType[64], char UniqueId[128], int entIndex) {
	if (!StrEqual(my_npcType, npcType))
		return;
	g_iLastInteractedWith[client] = entIndex;
	showTopPanelToClient(client);
}

public void showTopPanelToClient(int client) {
	Menu licenseMenu = CreateMenu(licenseMenuHandler);
	SetMenuTitle(licenseMenu, "License Vendor");
	char displayText[64];
	Format(displayText, sizeof(displayText), "Pistol License (%i)", g_iPistolLicense);
	if (tConomy_getCurrency(client) >= g_iPistolLicense)
		AddMenuItem(licenseMenu, "pistol", displayText);
	else
		AddMenuItem(licenseMenu, "-pistol", displayText, ITEMDRAW_DISABLED);
	
	Format(displayText, sizeof(displayText), "SMG License (%i)", g_iSMGLicense);
	if (tConomy_getCurrency(client) >= g_iSMGLicense)
		AddMenuItem(licenseMenu, "smg", displayText);
	else
		AddMenuItem(licenseMenu, "-smg", displayText, ITEMDRAW_DISABLED);
	
	Format(displayText, sizeof(displayText), "SMG License (%i)", g_iShotgunLicense);
	if (tConomy_getCurrency(client) >= g_iShotgunLicense)
		AddMenuItem(licenseMenu, "shotgun", displayText);
	else
		AddMenuItem(licenseMenu, "-shotgun", displayText, ITEMDRAW_DISABLED);
	
	Format(displayText, sizeof(displayText), "Special Weapon License (%i)", g_iSpecialweaponLicense);
	if (tConomy_getCurrency(client) >= g_iSpecialweaponLicense)
		AddMenuItem(licenseMenu, "specialWeapons", displayText);
	else
		AddMenuItem(licenseMenu, "-specialWeapons", displayText, ITEMDRAW_DISABLED);
	
	Format(displayText, sizeof(displayText), "Rifle License (%i)", g_iRifleLicense);
	if (tConomy_getCurrency(client) >= g_iRifleLicense)
		AddMenuItem(licenseMenu, "rifle", displayText);
	else
		AddMenuItem(licenseMenu, "-rifle", displayText, ITEMDRAW_DISABLED);
	
	Format(displayText, sizeof(displayText), "Grenade License (%i)", g_iGrenadeLicense);
	if (tConomy_getCurrency(client) >= g_iGrenadeLicense)
		AddMenuItem(licenseMenu, "nades", displayText);
	else
		AddMenuItem(licenseMenu, "-nades", displayText, ITEMDRAW_DISABLED);
	
	Format(displayText, sizeof(displayText), "Bike License (%i)", g_iBikeLicense);
	if (tConomy_getCurrency(client) >= g_iBikeLicense)
		AddMenuItem(licenseMenu, "bike", displayText);
	else
		AddMenuItem(licenseMenu, "-bike", displayText, ITEMDRAW_DISABLED);
	
	Format(displayText, sizeof(displayText), "Car License (%i)", g_iCarLicense);
	if (tConomy_getCurrency(client) >= g_iCarLicense)
		AddMenuItem(licenseMenu, "car", displayText);
	else
		AddMenuItem(licenseMenu, "-car", displayText, ITEMDRAW_DISABLED);
	
	DisplayMenu(licenseMenu, client, 60);
}

public int licenseMenuHandler(Handle menu, MenuAction action, int client, int item) {
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
		if (StrEqual(cValue, "pistol")) {
			if (tConomy_getCurrency(client) >= g_iPistolLicense) {
				tConomy_removeCurrency(client, g_iPistolLicense, "Bought Pistol License");
				inventory_givePlayerItem(client, "Pistol License", 1, "", "License", "Weapon License", 1, "Bought from License Vendor");
			}
		} else if (StrEqual(cValue, "smg")) {
			if (tConomy_getCurrency(client) >= g_iSMGLicense) {
				tConomy_removeCurrency(client, g_iSMGLicense, "Bought SMG License");
				inventory_givePlayerItem(client, "SMG License", 1, "", "License", "Weapon License", 1, "Bought from License Vendor");
			}
		} else if (StrEqual(cValue, "shotgun")) {
			if (tConomy_getCurrency(client) >= g_iShotgunLicense) {
				tConomy_removeCurrency(client, g_iShotgunLicense, "Bought Shotgun License");
				inventory_givePlayerItem(client, "Shotgun License", 1, "", "License", "Weapon License", 1, "Bought from License Vendor");
			}
		} else if (StrEqual(cValue, "specialWeapons")) {
			if (tConomy_getCurrency(client) >= g_iSpecialweaponLicense) {
				tConomy_removeCurrency(client, g_iSpecialweaponLicense, "Bought Shotgun License");
				inventory_givePlayerItem(client, "Special Weapon License", 1, "", "License", "Weapon License", 1, "Bought from License Vendor");
			}
		} else if (StrEqual(cValue, "rifle")) {
			if (tConomy_getCurrency(client) >= g_iRifleLicense) {
				tConomy_removeCurrency(client, g_iRifleLicense, "Bought Rifle License");
				inventory_givePlayerItem(client, "Rifle License", 1, "", "License", "Weapon License", 1, "Bought from License Vendor");
			}
		} else if (StrEqual(cValue, "nades")) {
			if (tConomy_getCurrency(client) >= g_iGrenadeLicense) {
				tConomy_removeCurrency(client, g_iGrenadeLicense, "Bought Nade License");
				inventory_givePlayerItem(client, "Nade License", 1, "", "License", "Weapon License", 1, "Bought from License Vendor");
			}
		} else if (StrEqual(cValue, "bike")) {
			if (tConomy_getCurrency(client) >= g_iBikeLicense) {
				tConomy_removeCurrency(client, g_iBikeLicense, "Bought Bike License");
				inventory_givePlayerItem(client, "Bike License", 1, "", "License", "Generic License", 1, "Bought from License Vendor");
			}
		} else if (StrEqual(cValue, "car")) {
			if (tConomy_getCurrency(client) >= g_iCarLicense) {
				tConomy_removeCurrency(client, g_iCarLicense, "Bought Car License");
				inventory_givePlayerItem(client, "Car License", 1, "", "License", "Generic License", 1, "Bought from License Vendor");
			}
		}
	}
}

stock bool isValidClient(int client) {
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client))
		return false;
	
	return true;
}
