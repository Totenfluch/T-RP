#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <tConomy>
#include <rpg_inventory_core>
#include <rpg_npc_core>

#pragma newdecls required

char my_npcType[128] = "License Vendor";

public Plugin myinfo = 
{
	name = "License Vendor for T-RP", 
	author = PLUGIN_AUTHOR, 
	description = "Adds Licenses for T-RP", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart(){
	npc_registerNpcType(my_npcType);
}

public void OnNpcInteract(int client, char npcType[64], char UniqueId[128], int entIndex) {
	showTopPanelToClient(client);
}

public void showTopPanelToClient(int client) {
	Menu licenseMenu = CreateMenu(licenseMenuHandler);
	SetMenuTitle(licenseMenu, "License Vendor");
	if (tConomy_getCurrency(client) >= 15000)
		AddMenuItem(licenseMenu, "pistol", "Pistol License (15000)");
	else
		AddMenuItem(licenseMenu, "-pistol", "Pistol License (15000)", ITEMDRAW_DISABLED);
	if (tConomy_getCurrency(client) >= 25000)
		AddMenuItem(licenseMenu, "smg", "SMG License (25000)");
	else
		AddMenuItem(licenseMenu, "-smg", "SMG License (25000)", ITEMDRAW_DISABLED);
	if (tConomy_getCurrency(client) >= 35000)
		AddMenuItem(licenseMenu, "shotgun", "Shotgun License (35000)");
	else
		AddMenuItem(licenseMenu, "-shotgun", "Shotgun License (35000)", ITEMDRAW_DISABLED);
	if (tConomy_getCurrency(client) >= 45000)
		AddMenuItem(licenseMenu, "specialWeapons", "Special Weapon License (45000)");
	else
		AddMenuItem(licenseMenu, "-specialWeapons", "Special Weapon License (45000)", ITEMDRAW_DISABLED);
	if (tConomy_getCurrency(client) >= 55000)
		AddMenuItem(licenseMenu, "rifle", "Rifle License (55000)");
	else
		AddMenuItem(licenseMenu, "-rifle", "Rifle License (55000)", ITEMDRAW_DISABLED);
	if (tConomy_getCurrency(client) >= 25000)
		AddMenuItem(licenseMenu, "nades", "Grenade License (25000)");
	else
		AddMenuItem(licenseMenu, "-nades", "Grenade License (25000)", ITEMDRAW_DISABLED);
	if (tConomy_getCurrency(client) >= 65000)
		AddMenuItem(licenseMenu, "bike", "Bike License (65000)");
	else
		AddMenuItem(licenseMenu, "-bike", "Bike License (65000)", ITEMDRAW_DISABLED);
	if (tConomy_getCurrency(client) >= 65000)
		AddMenuItem(licenseMenu, "car", "Car License (65000)");
	else
		AddMenuItem(licenseMenu, "-car", "Car License (65000)", ITEMDRAW_DISABLED);
	
	DisplayMenu(licenseMenu, client, 60);
}

public int licenseMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "pistol")) {
			if (tConomy_getCurrency(client) >= 25000) {
				tConomy_removeCurrency(client, 25000, "Bought Pistol License");
				inventory_givePlayerItem(client, "Pistol License", 1, "", "License", "Weapon License", 1, "Bought from License Vendor");
			}
		} else if (StrEqual(cValue, "smg")) {
			if (tConomy_getCurrency(client) >= 25000) {
				tConomy_removeCurrency(client, 25000, "Bought SMG License");
				inventory_givePlayerItem(client, "SMG License", 1, "", "License", "Weapon License", 1, "Bought from License Vendor");
			}
		} else if (StrEqual(cValue, "shotgun")) {
			if (tConomy_getCurrency(client) >= 35000) {
				tConomy_removeCurrency(client, 35000, "Bought Shotgun License");
				inventory_givePlayerItem(client, "Shotgun License", 1, "", "License", "Weapon License", 1, "Bought from License Vendor");
			}
		} else if (StrEqual(cValue, "specialWeapons")) {
			if (tConomy_getCurrency(client) >= 45000) {
				tConomy_removeCurrency(client, 45000, "Bought Shotgun License");
				inventory_givePlayerItem(client, "Special Weapon License", 1, "", "License", "Weapon License", 1, "Bought from License Vendor");
			}
		} else if (StrEqual(cValue, "rifle")) {
			if (tConomy_getCurrency(client) >= 55000) {
				tConomy_removeCurrency(client, 55000, "Bought Rifle License");
				inventory_givePlayerItem(client, "Rfile License", 1, "", "License", "Weapon License", 1, "Bought from License Vendor");
			}
		} else if (StrEqual(cValue, "nades")) {
			if (tConomy_getCurrency(client) >= 25000) {
				tConomy_removeCurrency(client, 25000, "Bought Nade License");
				inventory_givePlayerItem(client, "Nade License", 1, "", "License", "Weapon License", 1, "Bought from License Vendor");
			}
		} else if (StrEqual(cValue, "bike")) {
			if (tConomy_getCurrency(client) >= 65000) {
				tConomy_removeCurrency(client, 65000, "Bought Bike License");
				inventory_givePlayerItem(client, "Bike License", 1, "", "License", "Generic License", 1, "Bought from License Vendor");
			}
		} else if (StrEqual(cValue, "car")) {
			if (tConomy_getCurrency(client) >= 65000) {
				tConomy_removeCurrency(client, 65000, "Bought Car License");
				inventory_givePlayerItem(client, "Car License", 1, "", "License", "Generic License", 1, "Bought from License Vendor");
			}
		}
	}
}
