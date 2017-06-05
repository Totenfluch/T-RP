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
#include <rpg_jobs_core>
#include <tCrime>
#include <tConomy>
#include <rpg_inventory_core>
#include <autoexecconfig>
#include <smlib>
#include <sdkhooks>
#include <emitsoundany>
#include <multicolors>
#include <cstrike>
#include <rpg_jail>

#pragma newdecls required

#define MAX_CUFF_TIME 90

Handle g_hPlayTimeNeededForPolice;
int g_iPlayTimeNeededForPolice = 18000;


/* Special Stuff Values */
Handle g_hHandCuffsPrice;
int g_iHandCuffsPrice;

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

/* Skins */
Handle g_hSkin1Value;
int g_iSkin1Value;

Handle g_hSkin2Value;
int g_iSkin2Value;

Handle g_hSkin3Value;
int g_iSkin3Value;


int g_iHaloSprite;
int g_iFire;

bool g_bCuffed[MAXPLAYERS + 1] = false;

int g_iPlayerHandCuffs[MAXPLAYERS + 1];
int g_iCuffed = 0;

int gc_iHandCuffsDistance = 5;

int g_iOfficerTarget[MAXPLAYERS + 1];
int g_iCuffedBy[MAXPLAYERS + 1];
int g_iCuffedTimeLeft[MAXPLAYERS + 1];

char g_sSoundCuffsPath[256];
char g_sOverlayCuffsPath[256];
char g_sSoundBreakCuffsPath[256];
char g_sSoundUnLockCuffsPath[256];
bool g_bSounds;

ConVar gc_sSoundBreakCuffsPath;
ConVar gc_sSoundUnLockCuffsPath;
ConVar gc_sSoundCuffsPath;
ConVar gc_sOverlayCuffsPath;
ConVar gc_bSounds;


char dbconfig[] = "gsxh_multiroot";
Database g_DB;

public Plugin myinfo = 
{
	name = "[T-RP] Job: Police", 
	author = PLUGIN_AUTHOR, 
	description = "Adds the Police Job to T-RP", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart() {
	jobs_registerJob("Police", "Stop the criminals from beeing criminal", 7, 1200, 3.0);
	npc_registerNpcType("Police Recruiter");
	npc_registerNpcType("Police Weapon Vendor");
	
	RegConsoleCmd("sm_purge", cmdPurgeCallback, "Calls for the Emergency situation");
	RegConsoleCmd("sm_helpme", cmdHelpCallback, "Request help from other Police Officers");
	RegConsoleCmd("sm_criminals", cmdCriminalsCallback, "Lists all Criminals");
	
	HookEvent("round_start", OnRoundStart);
	HookEvent("round_end", OnRoundEnd);
	HookEvent("player_death", OnPlayerTeamDeath);
	HookEvent("player_team", OnPlayerTeamDeath);
	HookEvent("weapon_fire", Event_WeaponFire);
	HookEvent("player_spawn", onPlayerSpawn);
	
	AutoExecConfig_SetFile("rpg_job_police");
	AutoExecConfig_SetCreateFile(true);
	
	g_hPlayTimeNeededForPolice = AutoExecConfig_CreateConVar("rpg_playTimeForPolice", "180000", "Playtime needed for Police in seconds");
	
	g_hHandCuffsPrice = AutoExecConfig_CreateConVar("rpg_handcuffs", "30", "Price of the handcuffs in menu");
	g_hKevlarPrice = AutoExecConfig_CreateConVar("rpg_kevlar", "35", "Price of the kevlar in menu");
	g_hHelmetKevlarPrice = AutoExecConfig_CreateConVar("rpg_helmetkevlar", "35", "Price of the helmetkevlar in menu");
	g_hFlashbangPrice = AutoExecConfig_CreateConVar("rpg_flashbang", "35", "Price of the flashbang in menu");
	g_hGrenadePrice = AutoExecConfig_CreateConVar("rpg_grenade", "40", "Price of the grenade in menu");
	g_hSmokegrenadePrice = AutoExecConfig_CreateConVar("rpg_smoke", "50", "Price of the smoke in menu");
	
	
	g_hUspValue = AutoExecConfig_CreateConVar("rpg_usp", "10", "Price of the usp in menu");
	g_hP2000Value = AutoExecConfig_CreateConVar("rpg_p2000", "10", "Price of the p2000 in menu");
	g_hGlockValue = AutoExecConfig_CreateConVar("rpg_glock", "20", "Price of the glock in menu");
	g_hP250Value = AutoExecConfig_CreateConVar("rpg_p250", "25", "Price of the p250 in menu");
	g_hDeagleValue = AutoExecConfig_CreateConVar("rpg_deagle", "25", "Price of the deagle in menu");
	g_hDualsValue = AutoExecConfig_CreateConVar("rpg_duals", "30", "Price of the duals in menu");
	g_hFivesevenValue = AutoExecConfig_CreateConVar("rpg_fiveseven", "30", "Price of the fiveseven in menu");
	g_hTecValue = AutoExecConfig_CreateConVar("rpg_tec9", "35", "Price of the tec9 in menu");
	g_hCzValue = AutoExecConfig_CreateConVar("rpg_cz", "35", "Price of the cz in menu");
	
	g_hMac10Value = AutoExecConfig_CreateConVar("rpg_mac10", "30", "Price of the Mac10 in menu");
	g_hMp7Value = AutoExecConfig_CreateConVar("rpg_mp7", "35", "Price of the Mp7 in menu");
	g_hMp9Value = AutoExecConfig_CreateConVar("rpg_mp9", "35", "Price of the Mp9 in menu");
	g_hUmp45Value = AutoExecConfig_CreateConVar("rpg_ump45", "35", "Price of the Ump45 in menu");
	g_hBizonValue = AutoExecConfig_CreateConVar("rpg_bizon", "40", "Price of the Bizon in menu");
	g_hP90Value = AutoExecConfig_CreateConVar("rpg_p90", "50", "Price of the P90 in menu");
	
	g_hNovaValue = AutoExecConfig_CreateConVar("rpg_nova", "50", "Price of the nova in menu");
	g_hXM1014Value = AutoExecConfig_CreateConVar("rpg_xm1014", "60", "Price of the XM1014 in menu");
	g_hSawedValue = AutoExecConfig_CreateConVar("rpg_sawed", "55", "Price of the Sawed in menu");
	g_hMag7Value = AutoExecConfig_CreateConVar("rpg_mag7", "65", "Price of the Mag7 in menu");
	
	g_hGalilValue = AutoExecConfig_CreateConVar("rpg_galil", "60", "Price of the Galil in menu");
	g_hFamasValue = AutoExecConfig_CreateConVar("rpg_famas", "65", "Price of the Famas in menu");
	g_hSg553Value = AutoExecConfig_CreateConVar("rpg_sg553", "100", "Price of the Sg553 in menu");
	g_hAUGValue = AutoExecConfig_CreateConVar("rpg_aug", "100", "Price of the Aug in menu");
	g_hM4A4Value = AutoExecConfig_CreateConVar("rpg_m4a4", "125", "Price of the M4a4 in menu");
	g_hM4A1SValue = AutoExecConfig_CreateConVar("rpg_m4a1s", "150", "Price of the M4a1s in menu");
	g_hAk47Value = AutoExecConfig_CreateConVar("rpg_ak47", "150", "Price of the Ak47 in menu");
	
	g_hAwpValue = AutoExecConfig_CreateConVar("rpg_awp", "200", "Price of the awp in menu");
	g_hScoutValue = AutoExecConfig_CreateConVar("rpg_scout", "120", "Price of the scout in menu");
	g_hG3SG1Value = AutoExecConfig_CreateConVar("rpg_g3sg1", "250", "Price of the g3sg1 in menu");
	g_hScar20Value = AutoExecConfig_CreateConVar("rpg_scar", "250", "Price of the scar in menu");
	g_hM249Value = AutoExecConfig_CreateConVar("rpg_m249", "200", "Price of the m249 in menu");
	g_hNegevValue = AutoExecConfig_CreateConVar("rpg_negev", "225", "Price of the negev in menu");
	
	gc_sOverlayCuffsPath = AutoExecConfig_CreateConVar("rpg_overlays_cuffs", "overlays/MyJailbreak/cuffs", "Path to the cuffs Overlay DONT TYPE .vmt or .vft");
	gc_sSoundCuffsPath = AutoExecConfig_CreateConVar("rpg_sounds_cuffs", "music/MyJailbreak/cuffs.mp3", "Path to the soundfile which should be played for cuffed player.");
	gc_sSoundBreakCuffsPath = AutoExecConfig_CreateConVar("rpg_sounds_breakcuffs", "music/MyJailbreak/breakcuffs.mp3", "Path to the soundfile which should be played for break cuffs.");
	gc_sSoundUnLockCuffsPath = AutoExecConfig_CreateConVar("rpg_sounds_unlock", "music/MyJailbreak/unlock.mp3", "Path to the soundfile which should be played for unlocking cuffs.");
	
	gc_bSounds = AutoExecConfig_CreateConVar("rpg_sounds_enable", "0", "0 - disabled, 1 - enable sounds ", _, true, 0.1, true, 1.0);
	
	g_hSkin1Value = AutoExecConfig_CreateConVar("rpg_police_skin_1_cost", "250", "Cost of 'Police 1' Skin");
	g_hSkin2Value = AutoExecConfig_CreateConVar("rpg_police_skin_2_cost", "250", "Cost of 'Police 2' Skin");
	g_hSkin3Value = AutoExecConfig_CreateConVar("rpg_police_skin_3_cost", "250", "Cost of 'Police 3' Skin");
	
	AutoExecConfig_CleanFile();
	AutoExecConfig_ExecuteFile();
	
	char error[255];
	g_DB = SQL_Connect(dbconfig, true, error, sizeof(error));
	SQL_SetCharset(g_DB, "utf8");
	
	char createTableQuery[1024];
	Format(createTableQuery, sizeof(createTableQuery), "CREATE TABLE IF NOT EXISTS t_rpg_police_log ( `Id` BIGINT NOT NULL AUTO_INCREMENT , `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , `officer` VARCHAR(20) NOT NULL , `target` VARCHAR(20) NOT NULL , `action` VARCHAR(32) NOT NULL , `action_params` VARCHAR(64) NOT NULL , PRIMARY KEY (`Id`)) ENGINE = InnoDB;");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createTableQuery);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	/*
		Return is the Player is cuffed or not
		@Param1-> int client
		
		@return true if cuffed false if not
	
	*/
	CreateNative("police_isPlayerCuffed", Native_isPlayerCuffed);
}

public int Native_isPlayerCuffed(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	return g_bCuffed[client];
}

public void OnConfigsExecuted() {
	g_iPlayTimeNeededForPolice = GetConVarInt(g_hPlayTimeNeededForPolice);
	
	g_iHandCuffsPrice = GetConVarInt(g_hHandCuffsPrice);
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
	
	g_iSkin1Value = GetConVarInt(g_hSkin1Value);
	g_iSkin2Value = GetConVarInt(g_hSkin2Value);
	g_iSkin3Value = GetConVarInt(g_hSkin3Value);
	
	GetConVarString(gc_sOverlayCuffsPath, g_sSoundCuffsPath, sizeof(g_sSoundCuffsPath));
	GetConVarString(gc_sSoundCuffsPath, g_sSoundCuffsPath, sizeof(g_sSoundCuffsPath));
	GetConVarString(gc_sSoundBreakCuffsPath, g_sSoundBreakCuffsPath, sizeof(g_sSoundBreakCuffsPath));
	GetConVarString(gc_sSoundUnLockCuffsPath, g_sSoundUnLockCuffsPath, sizeof(g_sSoundUnLockCuffsPath));
	
	g_bSounds = GetConVarBool(gc_bSounds);
}

public void OnNpcInteract(int client, char npcType[64], char uniqueId[128], int entIndex) {
	if (StrEqual(npcType, "Police Recruiter")) {
		Menu m = CreateMenu(policeRecruiterHandler);
		SetMenuTitle(m, "Become a Police Officer TODAY!");
		if (CheckCommandAccess(client, "sm_pedo", ADMFLAG_CUSTOM5, true))
			AddMenuItem(m, "join", "Join the Police (Leaves old job)");
		else
			AddMenuItem(m, "x", "You are not whitelisted", ITEMDRAW_DISABLED);
		DisplayMenu(m, client, 60);
	} else if (StrEqual(npcType, "Police Weapon Vendor")) {
		showTopPanelToClient(client);
	}
}

public void showTopPanelToClient(int client) {
	if (jobs_isActiveJob(client, "Police")) {
		Panel wPanel = CreatePanel();
		SetPanelTitle(wPanel, "Police Weapon Vendor");
		DrawPanelText(wPanel, "^-.-^-.-^-.-^-.-^");
		DrawPanelItem(wPanel, "Pistols");
		DrawPanelItem(wPanel, "SMGs [2]", jobs_getLevel(client) >= 2 ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
		DrawPanelItem(wPanel, "Shotguns [3]", jobs_getLevel(client) >= 3 ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
		DrawPanelItem(wPanel, "Rifles [5]", jobs_getLevel(client) >= 5 ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
		DrawPanelItem(wPanel, "Special Weapons [6]", jobs_getLevel(client) >= 6 ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
		DrawPanelItem(wPanel, "Nades & Armour");
		DrawPanelText(wPanel, "^-.-^-.-^-.-^-.-^");
		DrawPanelItem(wPanel, "Exit");
		SendPanelToClient(wPanel, client, policeWeaponVendorHandler, 60);
	} else {
		PrintToChat(client, "You are not a Police Officer!");
	}
}

public int policeWeaponVendorHandler(Handle menu, MenuAction action, int client, int item) {
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
		char info[64];
		GetMenuItem(menu, item, info, sizeof(info));
		int id = StringToInt(info);
		if (id == 1) {
			if (tConomy_removeCurrency(client, g_iUspValue, "Bought Weapon from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_usp_silencer");
		} else if (id == 2) {
			if (tConomy_removeCurrency(client, g_iP2000Value, "Bought Weapon from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_hkp2000");
		} else if (id == 3) {
			if (tConomy_removeCurrency(client, g_iGlockValue, "Bought Weapon from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_glock");
		} else if (id == 4) {
			if (tConomy_removeCurrency(client, g_iP250Value, "Bought Weapon from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_p250");
		} else if (id == 5) {
			if (tConomy_removeCurrency(client, g_iDeagleValue, "Bought Weapon from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_deagle");
		} else if (id == 6) {
			if (tConomy_removeCurrency(client, g_iDualsValue, "Bought Weapon from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_elite");
		} else if (id == 7) {
			if (tConomy_removeCurrency(client, g_iFivesevenValue, "Bought Weapon from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_fiveseven");
		} else if (id == 8) {
			if (tConomy_removeCurrency(client, g_iTecValue, "Bought Weapon from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_tec9");
		} else if (id == 9) {
			if (tConomy_removeCurrency(client, g_iCzValue, "Bought Weapon from Police Weapon Vendor") >= 0)
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
		char info[64];
		GetMenuItem(menu, item, info, sizeof(info));
		int id = StringToInt(info);
		if (id == 1) {
			if (tConomy_removeCurrency(client, g_iMac10Value, "Bought Weapon from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_mac10");
		} else if (id == 2) {
			if (tConomy_removeCurrency(client, g_iMp7Value, "Bought Weapon from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_mp7");
		} else if (id == 3) {
			if (tConomy_removeCurrency(client, g_iMp9Value, "Bought Weapon from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_mp9");
		} else if (id == 4) {
			if (tConomy_removeCurrency(client, g_iUmp45Value, "Bought Weapon from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_ump45");
		} else if (id == 5) {
			if (tConomy_removeCurrency(client, g_iBizonValue, "Bought Weapon from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_bizon");
		} else if (id == 6) {
			if (tConomy_removeCurrency(client, g_iP90Value, "Bought Weapon from Police Weapon Vendor") >= 0)
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
		char info[64];
		GetMenuItem(menu, item, info, sizeof(info));
		int id = StringToInt(info);
		if (id == 1) {
			if (tConomy_removeCurrency(client, g_iNovaValue, "Bought Weapon from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_nova");
		} else if (id == 2) {
			if (tConomy_removeCurrency(client, g_iXM1014Value, "Bought Weapon from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_xm1014");
		} else if (id == 3) {
			if (tConomy_removeCurrency(client, g_iSawedValue, "Bought Weapon from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_sawedoff");
		} else if (id == 4) {
			if (tConomy_removeCurrency(client, g_iMag7Value, "Bought Weapon from Police Weapon Vendor") >= 0)
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
		char info[64];
		GetMenuItem(menu, item, info, sizeof(info));
		int id = StringToInt(info);
		if (id == 1) {
			if (tConomy_removeCurrency(client, g_iGalilValue, "Bought Weapon from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_galilar");
		} else if (id == 2) {
			if (tConomy_removeCurrency(client, g_iFamasValue, "Bought Weapon from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_famas");
		} else if (id == 3) {
			if (tConomy_removeCurrency(client, g_iSg553Value, "Bought Weapon from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_sg556");
		} else if (id == 4) {
			if (tConomy_removeCurrency(client, g_iAUGValue, "Bought Weapon from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_aug");
		} else if (id == 5) {
			if (tConomy_removeCurrency(client, g_iM4A4Value, "Bought Weapon from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_m4a1");
		} else if (id == 6) {
			if (tConomy_removeCurrency(client, g_iM4A1SValue, "Bought Weapon from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_m4a1_silencer");
		} else if (id == 7) {
			if (tConomy_removeCurrency(client, g_iAk47Value, "Bought Weapon from Police Weapon Vendor") >= 0)
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
	char handCuffsItem[64];
	Format(handCuffsItem, sizeof(handCuffsItem), "HandCuffs - %i Money", g_iHandCuffsPrice);
	if (Money >= g_iHandCuffsPrice)
		AddMenuItem(rpgPanel, "1", handCuffsItem);
	else
		AddMenuItem(rpgPanel, "1", handCuffsItem, ITEMDRAW_DISABLED);
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
	
	char skin1Item[64];
	Format(skin1Item, sizeof(skin1Item), "Skin: Police 1 - %i Money", g_iSkin1Value);
	if (Money >= g_iSkin1Value)
		AddMenuItem(rpgPanel, "7", skin1Item);
	else
		AddMenuItem(rpgPanel, "7", skin1Item, ITEMDRAW_DISABLED);
	
	char skin2Item[64];
	Format(skin2Item, sizeof(skin2Item), "Skin: Police 2 - %i Money", g_iSkin2Value);
	if (Money >= g_iSkin2Value)
		AddMenuItem(rpgPanel, "8", skin2Item);
	else
		AddMenuItem(rpgPanel, "8", skin2Item, ITEMDRAW_DISABLED);
	
	char skin3Item[64];
	Format(skin3Item, sizeof(skin3Item), "Skin: Police 3 - %i Money", g_iSkin3Value);
	if (Money >= g_iSkin3Value)
		AddMenuItem(rpgPanel, "9", skin3Item);
	else
		AddMenuItem(rpgPanel, "9", skin3Item, ITEMDRAW_DISABLED);
	
	DisplayMenu(rpgPanel, client, 60);
}

public int ArmorAndHPPanelHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char info[64];
		GetMenuItem(menu, item, info, sizeof(info));
		int id = StringToInt(info);
		if (id == 1) {
			if (tConomy_removeCurrency(client, g_iHandCuffsPrice, "Bought Item from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_taser");
		} else if (id == 2) {
			if (tConomy_removeCurrency(client, g_iKevlarPrice, "Bought Item from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "item_kevlar");
		} else if (id == 3) {
			if (tConomy_removeCurrency(client, g_iHelmetKevlarPrice, "Bought Item from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "item_assaultsuit");
		} else if (id == 4) {
			if (tConomy_removeCurrency(client, g_iFlashbangPrice, "Bought Item from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_flashbang");
		} else if (id == 5) {
			if (tConomy_removeCurrency(client, g_iGrenadePrice, "Bought Item from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_hegrenade");
		} else if (id == 6) {
			if (tConomy_removeCurrency(client, g_iSmokegrenadePrice, "Bought Item from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_smokegrenade");
		} else if (id == 7) {
			if (tConomy_removeCurrency(client, g_iSkin1Value, "Bought Item from Police Weapon Vendor") >= 0)
				inventory_givePlayerItem(client, "Police 1", 0, "", "Skin", "Skin", 1, "Bought from Police Vendor");
		} else if (id == 8) {
			if (tConomy_removeCurrency(client, g_iSkin2Value, "Bought Item from Police Weapon Vendor") >= 0)
				inventory_givePlayerItem(client, "Police 2", 0, "", "Skin", "Skin", 1, "Bought from Police Vendor");
		} else if (id == 9) {
			if (tConomy_removeCurrency(client, g_iSkin3Value, "Bought Item from Police Weapon Vendor") >= 0)
				inventory_givePlayerItem(client, "Police 3", 0, "", "Skin", "Skin", 1, "Bought from Police Vendor");
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
		char info[64];
		GetMenuItem(menu, item, info, sizeof(info));
		int id = StringToInt(info);
		if (id == 1) {
			if (tConomy_removeCurrency(client, g_iAwpValue, "Bought Weapon from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_awp");
		} else if (id == 2) {
			if (tConomy_removeCurrency(client, g_iScoutValue, "Bought Weapon from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_ssg08");
		} else if (id == 3) {
			if (tConomy_removeCurrency(client, g_iG3SG1Value, "Bought Weapon from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_g3sg1");
		} else if (id == 4) {
			if (tConomy_removeCurrency(client, g_iScar20Value, "Bought Weapon from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_scar20");
		} else if (id == 5) {
			if (tConomy_removeCurrency(client, g_iM249Value, "Bought Weapon from Police Weapon Vendor") >= 0)
				t_GiveClientItem(client, "weapon_m249");
		} else if (id == 6) {
			if (tConomy_removeCurrency(client, g_iNegevValue, "Bought Weapon from Police Weapon Vendor") >= 0)
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
	inventory_givePlayerItem(client, item, 10120, "", "Police Weapon", "Weapon", 1, "Bough from Police Weapon Vendor");
}

public int policeRecruiterHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "join")) {
			jobs_giveJob(client, "Police");
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public Action cmdPurgeCallback(int client, int args) {
	/* TODO */
	return Plugin_Handled;
}

public Action cmdHelpCallback(int client, int args) {
	if (!jobs_isActiveJob(client, "Police"))
		return Plugin_Handled;
	
	float origin[3];
	GetClientAbsOrigin(client, origin);
	
	int color[4] =  { 50, 50, 255, 255 };
	TE_SetupBeamRingPoint(origin, 10.0, 1150.0, g_iFire, g_iHaloSprite, 0, 66, 5.0, 64.0, 0.5, color, 15, 0);
	TE_SendToAll();
	
	for (int i = 1; i < MAXPLAYERS; i++) {
		if (!isValidClient(i))
			continue;
		if (!jobs_isActiveJob(client, "Police"))
			continue;
		if (i == client)
			continue;
		PrintToChat(i, "Officer %N is under attack at %.2f %.2f %.2f !!", client, origin[0], origin[1], origin[2]);
	}
	
	return Plugin_Handled;
}

public Action cmdCriminalsCallback(int client, int args) {
	Menu criminals = CreateMenu(criminalsHandler);
	for (int i = 1; i < MAXPLAYERS; i++) {
		if (!isValidClient(i))
			continue;
		if (tCrime_getCrime(i) == 0)
			continue;
		
		char cInfo[8];
		IntToString(i, cInfo, sizeof(cInfo));
		char cName[MAX_NAME_LENGTH + 8];
		GetClientName(i, cName, sizeof(cName));
		char DisplayString[MAX_NAME_LENGTH + 36];
		Format(DisplayString, sizeof(DisplayString), "%s (%i)", cName, tCrime_getCrime(i));
		AddMenuItem(criminals, cInfo, DisplayString, ITEMDRAW_DISABLED);
	}
	DisplayMenu(criminals, client, 60);
	return Plugin_Handled;
}

public int criminalsHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "...")) {
			
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast) {
	g_iCuffed = 0;
	
	for (int i = 1; i < MAXPLAYERS; i++) {
		g_iPlayerHandCuffs[i] = 10000;
		g_bCuffed[i] = false;
	}
}

public void OnPlayerTeamDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid")); // Get the dead clients id
	
	if (g_bCuffed[client])
	{
		g_iCuffed--;
		g_bCuffed[client] = false;
		SetEntityMoveType(client, MOVETYPE_WALK);
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
		CreateTimer(0.0, DeleteOverlay, client);
	}
}

public void Event_WeaponFire(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (jobs_isActiveJob(client, "Police") && (g_iPlayerHandCuffs[client] != 0 || (g_iPlayerHandCuffs[client] == 0 && g_iCuffed > 0)))
	{
		char sWeapon[64];
		event.GetString("weapon", sWeapon, sizeof(sWeapon));
		if (StrEqual(sWeapon, "weapon_taser"))
		{
			SetPlayerWeaponAmmo(client, Client_GetActiveWeapon(client), _, 2);
		}
	}
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i < MAXPLAYERS; i++) {
		if (!isValidClient(i))
			continue;
		if (g_bCuffed[i])
			FreeEm(i, 0);
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	char wName[128];
	GetClientWeapon(client, wName, sizeof(wName));
	if ((buttons & IN_ATTACK2))
	{
		if (StrContains(wName, "taser") != -1 && jobs_isActiveJob(client, "Police"))
		{
			int Target = GetClientAimTarget(client, true);
			
			if (isValidClient(Target) && g_bCuffed[Target])
			{
				float distance = Entity_GetDistance(client, Target);
				distance = Math_UnitsToMeters(distance);
				
				if ((gc_iHandCuffsDistance > distance) && !Client_IsLookingAtWall(client, Entity_GetDistance(client, Target) + 40.0))
				{
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
					location2[0] = (location[0] + (50 * ((Cosine(DegToRad(ang[1]))) * (Cosine(DegToRad(ang[0]))))));
					location2[1] = (location[1] + (50 * ((Sine(DegToRad(ang[1]))) * (Cosine(DegToRad(ang[0]))))));
					ang[0] -= (2 * ang[0]);
					location2[2] = origin[2] += 5.0;
					
					TeleportEntity(Target, location2, NULL_VECTOR, NULL_VECTOR);
					if (IsPlayerStuck(Target) && IsPlayerOnUpperStuck(Target)) {
						origin2[2] -= 5.0;
						TeleportEntity(Target, origin2, NULL_VECTOR, NULL_VECTOR);
					} else if (!IsPlayerOnUpperStuck(Target) && IsPlayerStuck(Target)) {
						location2[2] += 21.0;
						TeleportEntity(Target, location2, NULL_VECTOR, NULL_VECTOR);
					}
					
				}
			}
		}
	} else if (buttons & IN_USE || buttons & IN_ATTACK || buttons & IN_ATTACK2) {
		if (g_bCuffed[client]) {
			buttons = buttons & ~IN_USE;
			buttons = buttons & ~IN_ATTACK;
			buttons = buttons & ~IN_ATTACK2;
			return Plugin_Changed;
		}
		
		if (StrContains(wName, "taser") != -1 && jobs_isActiveJob(client, "Police")) {
			int Target = GetClientAimTarget(client, true);
			
			if (isValidClient(Target) && (g_bCuffed[Target] == true)) {
				float distance = Entity_GetDistance(client, Target);
				distance = Math_UnitsToMeters(distance);
				if ((gc_iHandCuffsDistance > distance)) {
					g_iOfficerTarget[client] = Target;
					Menu m = CreateMenu(searchMenuHandler);
					char menuTitle[128];
					Format(menuTitle, sizeof(menuTitle), "What do you want to do? (Crime: %i)", tCrime_getCrime(Target));
					SetMenuTitle(m, menuTitle);
					char targetNameString[32];
					GetClientName(Target, targetNameString, sizeof(targetNameString));
					AddMenuItem(m, "x", targetNameString, ITEMDRAW_DISABLED);
					//AddMenuItem(m, "arrest", "Arrest Player");
					AddMenuItem(m, "search", "Search Inventory");
					AddMenuItem(m, "licenses", "Lookup Licenses");
					AddMenuItem(m, "pardon", "Pardon Player");
					AddMenuItem(m, "punish", "Punish Player");
					DisplayMenu(m, client, 60);
				}
			}
		}
	}
	return Plugin_Continue;
}

public int searchMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		/*if (StrEqual(cValue, "arrest")) {
			putInJail(client, g_iOfficerTarget[client]);
		} else */
		if (StrEqual(cValue, "search")) {
			inventory_showInventoryOfClientToOtherClient(g_iOfficerTarget[client], client);
		} else if (StrEqual(cValue, "licenses")) {
			inventory_showInventoryOfClientToOtherClientByCategory(g_iOfficerTarget[client], client, "License");
		} else if (StrEqual(cValue, "pardon")) {
			char crime[12];
			IntToString(tCrime_getCrime(g_iOfficerTarget[client]), crime, sizeof(crime));
			logAction(client, g_iOfficerTarget[client], "Pardon", crime);
			tCrime_setCrime(g_iOfficerTarget[client], 0);
		} else if (StrEqual(cValue, "punish")) {
			openPunishMenu(client, g_iOfficerTarget[client]);
		}
		g_iOfficerTarget[client] = -1;
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

int overtake[MAXPLAYERS + 1];
public void openPunishMenu(int officer, int target) {
	Menu punishMenu = CreateMenu(punishMenuHandler);
	SetMenuTitle(punishMenu, "Punish Player");
	AddMenuItem(punishMenu, "arrest", "Arrest Player");
	AddMenuItem(punishMenu, "small", "Crime: 100 (illegal Drugs)");
	AddMenuItem(punishMenu, "medium", "Crime: 200 (frags Players)");
	AddMenuItem(punishMenu, "high", "Crime: 300 (no Weapon License)");
	if (jobs_getLevel(officer) >= 3)
		AddMenuItem(punishMenu, "setCrime", "Crime: Add Crime [3]");
	else
		AddMenuItem(punishMenu, "setCrime", "Crime: Add Crime [3]", ITEMDRAW_DISABLED);
	AddMenuItem(punishMenu, "giveTicket", "Give Ticket (Crime * 2)");
	if (jobs_getLevel(officer) >= 3)
		AddMenuItem(punishMenu, "setTicket", "Set Ticket [3]");
	else
		AddMenuItem(punishMenu, "setTicket", "Set Ticket (In Chat)", ITEMDRAW_DISABLED);
	AddMenuItem(punishMenu, "deleteIllegal", "Delete Items");
	AddMenuItem(punishMenu, "deleteAllIllegal", "Delete Items (by Group)");
	AddMenuItem(punishMenu, "deleteAll", "Delete Active Weapons");
	DisplayMenu(punishMenu, officer, 60);
	overtake[officer] = target;
	//PrintToChat(officer, "%i %i %i", g_iOfficerTarget[officer], target, overtake[officer]);
}

public int punishMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		//PrintToChat(client, "o1: %i", overtake[client]);
		if (StrEqual(cValue, "small")) {
			char crime[12];
			IntToString(100, crime, sizeof(crime));
			logAction(client, overtake[client], "AddCrime", crime);
			tCrime_addCrime(overtake[client], 100);
		} else if (StrEqual(cValue, "medium")) {
			char crime[12];
			IntToString(200, crime, sizeof(crime));
			logAction(client, overtake[client], "AddCrime", crime);
			tCrime_addCrime(overtake[client], 200);
		} else if (StrEqual(cValue, "high")) {
			char crime[12];
			IntToString(300, crime, sizeof(crime));
			logAction(client, overtake[client], "AddCrime", crime);
			tCrime_addCrime(overtake[client], 300);
		} else if (StrEqual(cValue, "deleteAll")) {
			logAction(client, overtake[client], "StripWeapons", "");
			StripAllPlayerWeapons(overtake[client]);
			GivePlayerItem(overtake[client], "weapon_knife");
		} else if (StrEqual(cValue, "arrest")) {
			char crime[12];
			IntToString(tCrime_getCrime(overtake[client]), crime, sizeof(crime));
			logAction(client, overtake[client], "Arrest", crime);
			putInJail(client, overtake[client]);
		} else if (StrEqual(cValue, "deleteIllegal")) {
			deleteItems(client, overtake[client]);
		} else if (StrEqual(cValue, "deleteAllIllegal")) {
			deleteItemsByGroup(client, overtake[client]);
		} else if (StrEqual(cValue, "setCrime")) {
			openSetCrimeMenu(client, overtake[client]);
		} else if (StrEqual(cValue, "setTicket")) {
			openSetTicketMenu(client, overtake[client]);
		} else if (StrEqual(cValue, "giveTicket")) {
			giveTicketToClient(client, overtake[client], tCrime_getCrime(overtake[client]) * 2);
		}
		overtake[client] = -1;
		g_iOfficerTarget[client] = -1;
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

int g_iLatestTicket[MAXPLAYERS + 1];
int g_iTickpriceOvertake[MAXPLAYERS + 1];
public void giveTicketToClient(int officer, int client, int amount) {
	Handle menu = CreateMenu(giveTicketmenuHandler);
	char menuTitle[128];
	Format(menuTitle, sizeof(menuTitle), "Pay ticket of %i$", amount);
	SetMenuTitle(menu, menuTitle);
	AddMenuItem(menu, "x", "Ignore");
	if (tConomy_getCurrency(client) >= amount || tConomy_getBankCurrency(client) >= amount)
		AddMenuItem(menu, "pay", "Pay Ticket");
	else
		AddMenuItem(menu, "pay", "Pay Ticket", ITEMDRAW_DISABLED);
	g_iLatestTicket[client] = officer;
	g_iTickpriceOvertake[client] = amount;
	DisplayMenu(menu, client, 60);
}

public int giveTicketmenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "pay")) {
			if (tConomy_getCurrency(client) >= g_iTickpriceOvertake[client] || tConomy_getBankCurrency(client) >= g_iTickpriceOvertake[client]) {
				if (tConomy_getCurrency(client) >= g_iTickpriceOvertake[client])
					tConomy_removeCurrency(client, g_iTickpriceOvertake[client], "Paid Ticket");
				else
					tConomy_removeBankCurrency(client, g_iTickpriceOvertake[client], "Paid Ticket");
				PrintToChat(g_iLatestTicket[client], "[-T-] %N has paid the Ticket of %i", client, g_iTickpriceOvertake[client]);
				tCrime_setCrime(client, 0);
				tConomy_addCurrency(g_iLatestTicket[client], RoundToNearest(g_iTickpriceOvertake[client] / 2.0), "Ticket Split");
				jobs_addExperience(g_iLatestTicket[client], RoundToNearest(g_iTickpriceOvertake[client] / 10.0), "Police");
				
				char ticketprice[12];
				IntToString(g_iTickpriceOvertake[client], ticketprice, sizeof(ticketprice));
				logAction(g_iLatestTicket[client], client, "Ticket", ticketprice);
			}
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

int g_iOfficerSetTicketOvertake[MAXPLAYERS + 1];
public void openSetTicketMenu(int officer, int client) {
	Handle menu = CreateMenu(setTicketMenuHandler);
	SetMenuTitle(menu, "Choose Ticket amount");
	
	int tempMoney = 20;
	int increaseBy = 20;
	int step = 0;
	int reduce = 0;
	while (tempMoney <= 15000) {
		char cTempMoney[128];
		IntToString(tempMoney, cTempMoney, sizeof(cTempMoney));
		AddMenuItem(menu, cTempMoney, cTempMoney);
		if (++step < (5 - reduce))
			tempMoney += increaseBy;
		else {
			increaseBy *= 5;
			step = 0;
			tempMoney += increaseBy;
			reduce = 1;
		}
	}
	g_iOfficerSetTicketOvertake[officer] = client;
	DisplayMenu(menu, officer, 30);
}

public int setTicketMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[8];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		int theAmount = StringToInt(cValue);
		if (!isValidClient(g_iOfficerSetTicketOvertake[client]))
			return;
		giveTicketToClient(client, g_iOfficerSetTicketOvertake[client], theAmount);
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}


int g_iOfficerSetCrimeMenuTarget[MAXPLAYERS + 1];
public void openSetCrimeMenu(int officer, int client) {
	Handle menu = CreateMenu(setCrimeMenuHandler);
	SetMenuTitle(menu, "Choose Crime amount");
	
	int tempMoney = 20;
	int increaseBy = 20;
	int step = 0;
	int reduce = 0;
	while (tempMoney <= 15000) {
		char cTempMoney[128];
		IntToString(tempMoney, cTempMoney, sizeof(cTempMoney));
		AddMenuItem(menu, cTempMoney, cTempMoney);
		if (++step < (5 - reduce))
			tempMoney += increaseBy;
		else {
			increaseBy *= 5;
			step = 0;
			tempMoney += increaseBy;
			reduce = 1;
		}
	}
	g_iOfficerSetCrimeMenuTarget[officer] = client;
	DisplayMenu(menu, officer, 30);
}

public int setCrimeMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[8];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		int theAmount = StringToInt(cValue);
		if (!isValidClient(g_iOfficerSetCrimeMenuTarget[client]))
			return;
		tCrime_addCrime(g_iOfficerSetCrimeMenuTarget[client], theAmount);
		
		char crime[12];
		IntToString(theAmount, crime, sizeof(crime));
		logAction(client, g_iOfficerSetCrimeMenuTarget[client], "SetCrime", crime);
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}


int g_iOfficerDeleteItemsTaget[MAXPLAYERS + 1];
public void deleteItems(int officer, int client) {
	if (!isValidClient(client))
		return;
	g_iOfficerDeleteItemsTaget[officer] = client;
	int maxItems = inventory_getClientItemsAmount(client);
	Menu deleteItemsMenu = CreateMenu(deleteItemsMenuHandler);
	SetMenuTitle(deleteItemsMenu, "Delete Items");
	for (int i = 0; i <= maxItems; i++) {
		if (inventory_isValidItem(client, i)) {
			char itemName[128];
			if (inventory_getItemNameBySlotAndClient(client, i, itemName, "")) {
				char cId[8];
				IntToString(i, cId, sizeof(cId));
				AddMenuItem(deleteItemsMenu, cId, itemName);
			}
		}
	}
	DisplayMenu(deleteItemsMenu, officer, 60);
}

public int deleteItemsMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[8];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		int id = StringToInt(cValue);
		if (!isValidClient(g_iOfficerDeleteItemsTaget[client]))
			return;
		if (!inventory_isValidItem(g_iOfficerDeleteItemsTaget[client], id))
			return;
		char reason[256];
		Format(reason, sizeof(reason), "Deleted By Police Officer %N", client);
		char itemBuffer[128];
		inventory_getItemNameBySlotAndClient(g_iOfficerDeleteItemsTaget[client], id, itemBuffer, "");
		CPrintToChat(client, "{olive}[POLICE]{darkred}Removed {olive}1x{darkred} {olive}%s{darkred} from {olive}%N{darkred} Inventory.", itemBuffer, g_iOfficerDeleteItemsTaget[client]);
		inventory_deleteItemBySlot(g_iOfficerDeleteItemsTaget[client], id, reason);
		deleteItems(client, g_iOfficerDeleteItemsTaget[client]);
		jobs_addExperience(client, 10, "Police");
		
		char deleted[64];
		Format(deleted, sizeof(deleted), "1x %s", itemBuffer);
		logAction(client, g_iOfficerDeleteItemsTaget[client], "DeleteItem", deleted);
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void deleteItemsByGroup(int officer, int client) {
	if (!isValidClient(client))
		return;
	g_iOfficerDeleteItemsTaget[officer] = client;
	int maxItems = inventory_getClientItemsAmount(client);
	Menu deleteItemsMenu = CreateMenu(deleteItemsByGroupMenuHandler);
	SetMenuTitle(deleteItemsMenu, "Delete Item Group");
	for (int i = 0; i <= maxItems; i++) {
		if (inventory_isValidItem(client, i)) {
			char itemName[128];
			if (inventory_getItemNameBySlotAndClient(client, i, itemName, "")) {
				char cId[8];
				IntToString(i, cId, sizeof(cId));
				AddMenuItem(deleteItemsMenu, cId, itemName);
			}
		}
	}
	DisplayMenu(deleteItemsMenu, officer, 60);
}

public int deleteItemsByGroupMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[8];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		int id = StringToInt(cValue);
		if (!isValidClient(g_iOfficerDeleteItemsTaget[client]))
			return;
		if (!inventory_isValidItem(g_iOfficerDeleteItemsTaget[client], id))
			return;
		char reason[256];
		Format(reason, sizeof(reason), "Deleted By Police Officer %N (Group delete)", client);
		char itemBuffer[128];
		inventory_getItemNameBySlotAndClient(g_iOfficerDeleteItemsTaget[client], id, itemBuffer, "");
		int amount = inventory_getPlayerItemAmount(g_iOfficerDeleteItemsTaget[client], itemBuffer);
		inventory_removePlayerItems(g_iOfficerDeleteItemsTaget[client], itemBuffer, amount, "Deleted by Police Officer");
		CPrintToChat(client, "{olive}[POLICE]{darkred}Removed {olive}%ix{darkred} {olive}%s{darkred} from {olive}%N{darkred} Inventory.", amount, itemBuffer, g_iOfficerDeleteItemsTaget[client]);
		deleteItemsByGroup(client, g_iOfficerDeleteItemsTaget[client]);
		
		char deleted[64];
		Format(deleted, sizeof(deleted), "%i %s", amount, itemBuffer);
		logAction(client, g_iOfficerDeleteItemsTaget[client], "DeleteItem", deleted);
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void putInJail(int initiator, int target) {
	FreeEm(target, initiator);
	int amount = RoundToNearest(tCrime_getCrime(target) / 10.0);
	jobs_addExperience(initiator, amount, "Police");
	jail_putInJail(initiator, target);
}

public Action OnTakedamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom) {
	if (!isValidClient(victim) || attacker == victim || !isValidClient(attacker))
		return Plugin_Continue;
	
	char sWeapon[32];
	if (IsValidEntity(weapon))GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));
	
	if (g_bCuffed[attacker])
		return Plugin_Handled;
	
	if (!jobs_isActiveJob(attacker, "Police") || !IsValidEdict(weapon))
		return Plugin_Continue;
	
	if (!StrEqual(sWeapon, "weapon_taser"))
		return Plugin_Continue;
	
	if ((g_iPlayerHandCuffs[attacker] == 0) && (g_iCuffed == 0))
		return Plugin_Continue;
	
	if (g_bCuffed[victim]) {
		logAction(attacker, victim, "ControlFree", "");
		FreeEm(victim, attacker);
	} else {
		if (!jobs_isActiveJob(victim, "Police")) {
			logAction(attacker, victim, "ControlCuff", "");
			CuffsEm(victim, attacker);
		}
	}
	
	return Plugin_Handled;
}


public void OnClientDisconnect(int client) {
	for (int i = 0; i < MAXPLAYERS; i++) {
		if (g_iCuffedBy[i] != -1)
			if (!isValidClient(g_iCuffedBy[i])) {
			g_iCuffedBy[i] = -1;
			FreeEm(i, 0);
		}
	}
	if (g_bCuffed[client])g_iCuffed--;
	
	if (isValidClient(client)) {
		SDKUnhook(client, SDKHook_OnTakeDamage, OnTakedamage);
		SDKUnhook(client, SDKHook_WeaponDrop, onWeaponDrop);
	}
}

public void OnClientPostAdminCheck(int client) {
	g_iPlayerHandCuffs[client] = 10000;
	g_iOfficerTarget[client] = -1;
	g_iCuffedTimeLeft[client] = -1;
	g_iCuffedBy[client] = -1;
}

public void OnMapEnd()
{
	for (int i = 1; i < MAXPLAYERS; i++) {
		if (!isValidClient(i))
			continue;
		if (g_bCuffed[i])
			FreeEm(i, 0);
	}
}

public void OnMapStart()
{
	CreateTimer(1.0, refreshTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(120.0, incomeTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	g_iHaloSprite = PrecacheModel("materials/sprites/halo01.vmt");
	g_iFire = PrecacheModel("materials/sprites/fire2.vmt");
	PrecacheSoundAnyDownload(g_sSoundCuffsPath);
	PrecacheSoundAnyDownload(g_sSoundBreakCuffsPath);
	PrecacheSoundAnyDownload(g_sSoundUnLockCuffsPath);
	PrecacheDecalAnyDownload(g_sOverlayCuffsPath);
}

public Action incomeTimer(Handle Timer) {
	for (int i = 1; i < MAXPLAYERS; i++) {
		if (!isValidClient(i))
			continue;
		if (jobs_isActiveJob(i, "Police"))
			tConomy_addBankCurrency(i, jobs_getLevel(i) * 20 + 50, "Police Salary");
	}
}

public void OnClientPutInServer(int client) {
	if (isValidClient(client)) {
		SDKHook(client, SDKHook_OnTakeDamage, OnTakedamage);
		SDKHook(client, SDKHook_WeaponDrop, onWeaponDrop);
	}
}

public Action CuffsEm(int client, int attacker) {
	if (g_iPlayerHandCuffs[attacker] > 0) {
		SetEntityMoveType(client, MOVETYPE_NONE);
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 0.0);
		SetEntityRenderColor(client, 0, 190, 0, 255);
		//StripAllPlayerWeapons(client);
		//GivePlayerItem(client, "weapon_knife");
		//int slot;
		//if((slot = GetPlayerWeaponSlot(client, 2) != -1))
		//	EquipPlayerWeapon(client, slot);
		g_bCuffed[client] = true;
		ShowOverlay(client, g_sOverlayCuffsPath, 0.0);
		g_iPlayerHandCuffs[attacker]--;
		g_iCuffed++;
		g_iCuffedBy[client] = attacker;
		g_iCuffedTimeLeft[client] = MAX_CUFF_TIME;
		//if (g_bSounds)
		//	EmitSoundAny(g_sSoundCuffsPath);
		tConomy_addCurrency(attacker, 20, "Police Control");
		
		//CPrintToChatAll("%t %t", "warden_tag", "warden_cuffson", attacker, client);
		//CPrintToChat(attacker, "%t %t", "warden_tag", "warden_cuffsgot", g_iPlayerHandCuffs[attacker]);
		/*if (CheckVipFlag(client, g_sAdminFlagCuffs))
		{
			CreateTimer(2.5, HasPaperClip, client);
		}*/
	}
}


public Action FreeEm(int client, int attacker) {
	g_bCuffed[client] = false;
	g_iCuffed--;
	if (!isValidClient(client))
		return;
	SetEntityMoveType(client, MOVETYPE_WALK);
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
	SetEntityRenderColor(client, 255, 255, 255, 255);
	
	CreateTimer(0.0, DeleteOverlay, client);
	if (g_bSounds)StopSoundAny(client, SNDCHAN_AUTO, g_sSoundUnLockCuffsPath);
	if ((attacker != 0) && (attacker != -1) && (g_iCuffed == 0) && (g_iPlayerHandCuffs[attacker] < 1))SetPlayerWeaponAmmo(attacker, Client_GetActiveWeapon(attacker), _, 0);
	//if (attacker != 0)CPrintToChatAll("%t %t", "warden_tag", "warden_cuffsoff", attacker, client);
}

/*public Action HasPaperClip(Handle timer, int client)
{
	if (g_bCuffed[client])
	{
		int paperclip = GetRandomInt(1, gc_iPaperClipGetChance.IntValue);
		float unlocktime = GetRandomFloat(gc_fUnLockTimeMin.FloatValue, gc_fUnLockTimeMax.FloatValue);
		if (paperclip == 1)
		{
			CPrintToChat(client, "%t", "warden_gotpaperclip");
			PrintCenterText(client, "%t", "warden_gotpaperclip");
			CreateTimer(unlocktime, BreakTheseCuffs, client);
			if (g_bSounds)EmitSoundToClientAny(client, g_sSoundUnLockCuffsPath);
		}
	}
}*/

/*public Action BreakTheseCuffs(Handle timer, int client)
{
	if (isValidClient(client) && g_bCuffed[client])
	{
		int unlocked = GetRandomInt(1, gc_iPaperClipUnLockChance.IntValue);
		if (unlocked == 1)
		{
			CPrintToChat(client, "%t", "warden_unlock");
			PrintCenterText(client, "%t", "warden_unlock");
			if (g_bSounds)EmitSoundToAllAny(g_sSoundBreakCuffsPath);
			SetEntityMoveType(client, MOVETYPE_WALK);
			SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
			SetEntityRenderColor(client, 255, 255, 255, 255);
			g_bCuffed[client] = false;
			CreateTimer(0.0, DeleteOverlay, client);
			g_iCuffed--;
		}
		else
		{
			CPrintToChat(client, "%t", "warden_brokepaperclip");
			PrintCenterText(client, "%t", "warden_brokepaperclip");
		}
	}
}*/

stock void StripZeus(int client)
{
	if (isValidClient(client)) {
		char sWeapon[64];
		FakeClientCommand(client, "use weapon_taser");
		int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if (weapon != -1) {
			GetEntityClassname(weapon, sWeapon, sizeof(sWeapon));
			if (StrEqual(sWeapon, "weapon_taser")) {
				SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR);
				if (IsValidEdict(weapon))
					AcceptEntityInput(weapon, "Kill");
			}
		}
	}
}

stock bool isValidClient(int client) {
	return (1 <= client <= MaxClients && IsClientInGame(client));
}

stock void PrecacheModelAnyDownload(char[] sModel)
{
	char sBuffer[256];
	Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", sModel);
	AddFileToDownloadsTable(sBuffer);
	PrecacheModel(sBuffer, true);
	Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", sModel);
	AddFileToDownloadsTable(sBuffer);
	PrecacheModel(sBuffer, true);
}

stock void PrecacheDecalAnyDownload(char[] sDecal)
{
	char sBuffer[256];
	Format(sBuffer, sizeof(sBuffer), "%s.vmt", sDecal);
	PrecacheDecal(sBuffer, true);
	Format(sBuffer, sizeof(sBuffer), "materials/%s.vmt", sDecal);
	AddFileToDownloadsTable(sBuffer);
	
	Format(sBuffer, sizeof(sBuffer), "%s.vtf", sDecal);
	PrecacheDecal(sBuffer, true);
	Format(sBuffer, sizeof(sBuffer), "materials/%s.vtf", sDecal);
	AddFileToDownloadsTable(sBuffer);
}

stock void PrecacheSoundAnyDownload(char[] sSound) {
	char sBuffer[256];
	PrecacheSoundAny(sSound);
	Format(sBuffer, sizeof(sBuffer), "sound/%s", sSound);
	AddFileToDownloadsTable(sBuffer);
}

public Action DeleteOverlay(Handle timer, any client)
{
	if (isValidClient(client))
	{
		int iFlag = GetCommandFlags("r_screenoverlay") & (~FCVAR_CHEAT);
		SetCommandFlags("r_screenoverlay", iFlag);
		ClientCommand(client, "r_screenoverlay \"\"");
	}
}

stock void SetPlayerWeaponAmmo(int client, int weaponEnt, int clip = -1, int ammo = -1)
{
	if (weaponEnt == INVALID_ENT_REFERENCE)
		return;
	
	if (clip != -1)
		SetEntProp(weaponEnt, Prop_Send, "m_iClip1", clip);
	
	if (ammo != -1)
	{
		int iOffset = FindDataMapInfo(client, "m_iAmmo") + (GetEntProp(weaponEnt, Prop_Data, "m_iPrimaryAmmoType") * 4);
		SetEntData(client, iOffset, ammo, 4, true);
		
		if (GetEngineVersion() == Engine_CSGO)
		{
			SetEntProp(weaponEnt, Prop_Send, "m_iPrimaryReserveAmmoCount", ammo);
		}
	}
}

stock void ShowOverlay(int client, char[] path, float lifetime)
{
	if (isValidClient(client))
	{
		int iFlag = GetCommandFlags("r_screenoverlay") & (~FCVAR_CHEAT);
		SetCommandFlags("r_screenoverlay", iFlag);
		ClientCommand(client, "r_screenoverlay \"%s.vtf\"", path);
		if (lifetime != 0.0)CreateTimer(lifetime, DeleteOverlay, client);
	}
}

stock void StripAllPlayerWeapons(int client) {
	if (!isValidClient(client))
		return;
	int weapon;
	for (int i = 0; i <= 4; i++)
	{
		if ((weapon = GetPlayerWeaponSlot(client, i)) != -1) {
			SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR);
			AcceptEntityInput(weapon, "Kill");
		}
	}
	if ((weapon = GetPlayerWeaponSlot(client, CS_SLOT_KNIFE)) != -1) {  //strip knife slot 2 times for taser{
		SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(weapon, "Kill");
	} }


stock bool CheckVipFlag(int client, const char[] flagsNeed)
{
	if ((GetUserFlagBits(client) & ReadFlagString(flagsNeed) == ReadFlagString(flagsNeed)) || (GetUserFlagBits(client) & ADMFLAG_ROOT)) {
		return true;
	}
	return false;
}

public Action onPlayerSpawn(Handle event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!isValidClient(client))
		return;
	if (!IsPlayerAlive(client))
		return;
	SetEntityRenderColor(client, 255, 255, 255, 255);
}

public Action refreshTimer(Handle Timer) {
	for (int client = 1; client < MAXPLAYERS; client++) {
		if (!isValidClient(client))
			continue;
		if (g_bCuffed[client]) {
			if (g_iCuffedTimeLeft[client] == 1)
				FreeEm(client, g_iCuffedBy[client]);
			else if (g_iCuffedTimeLeft[client] > 1)
				g_iCuffedTimeLeft[client]--;
			
			if (!IsPlayerAlive(g_iCuffedBy[client]))
				FreeEm(client, g_iCuffedBy[client]);
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

stock bool IsPlayerOnUpperStuck(int client) {
	float vecMin[3];
	float vecMax[3];
	float vecOrigin[3];
	
	GetClientMins(client, vecMin);
	GetClientMaxs(client, vecMax);
	
	vecMin[2] += 26.0;
	
	GetClientAbsOrigin(client, vecOrigin);
	
	TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_PLAYERSOLID, TraceRayDontHitPlayerAndWorld);
	return TR_GetEntityIndex() != -1;
}

public bool TraceRayDontHitPlayerAndWorld(int entityhit, int mask) {
	return (entityhit < 1 || entityhit > MaxClients);
}

public Action onWeaponDrop(int client, int weapon) {
	if (jobs_isActiveJob(client, "Police")) {
		PrintToChat(client, "You can not Drop weapons as Police officer");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public void logAction(int officer, int target, char[] action, char[] action_params) {
	char officerId[20];
	GetClientAuthId(officer, AuthId_Steam2, officerId, sizeof(officerId));
	
	char targetId[20];
	GetClientAuthId(target, AuthId_Steam2, targetId, sizeof(targetId));
	
	char logQuery[256];
	Format(logQuery, sizeof(logQuery), "INSERT INTO `t_rpg_police_log` (`Id`, `timestamp`, `officer`, `target`, `action`, `action_params`) VALUES (NULL, CURRENT_TIMESTAMP, '%s', '%s', '%s', '%s');", officerId, targetId, action, action_params);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, logQuery);
}

public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, any data) {
	if (!StrEqual(error, ""))
		LogError(error);
} 