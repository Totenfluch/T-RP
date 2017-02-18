#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <rpg_npc_core>
#include <autoexecconfig>
#include <rpg_jobs_core>
#include <tConomy>

#pragma newdecls required

#define MAX_PERKS 128

//int g_iLoadedPerks;
//char g_cLoadedPerks[MAX_PERKS][64];

char g_cOwnedPerks[MAXPLAYERS + 1][MAX_PERKS][64];
int g_iOwnedPerks[MAXPLAYERS + 1];

char dbconfig[] = "gsxh_multiroot";
Database g_DB;

char my_npcType[128] = "Perk Shop";

int g_iLastInteractedWith[MAXPLAYERS + 1];

/* MINING */
Handle g_hPerk_mining_copper;
int g_iPerk_mining_copper;

Handle g_hPerk_mining_fosil;
int g_iPerk_mining_fosil;

Handle g_hPerk_mining_iron;
int g_iPerk_mining_iron;

Handle g_hPerk_mining_gold;
int g_iPerk_mining_gold;

Handle g_hPerk_mining_boost1;
int g_iPerk_mining_boost1;

Handle g_hPerk_mining_boost2;
int g_iPerk_mining_boost2;

Handle g_hPerk_mining_boost3;
int g_iPerk_mining_boost3;

Handle g_hPerk_mining_boost4;
int g_iPerk_mining_boost4;


/* APPLE HARVESTER */
Handle g_hPerk_apples_boost1;
int g_iPerk_apples_boost1;

Handle g_hPerk_apples_boost2;
int g_iPerk_apples_boost2;

Handle g_hPerk_apples_boost3;
int g_iPerk_apples_boost3;

Handle g_hPerk_apples_boost4;
int g_iPerk_apples_boost4;

Handle g_hPerk_apples_pears;
int g_iPerk_apples_pears;

Handle g_hPerk_apples_nuts;
int g_iPerk_apples_nuts;

Handle g_hPerk_apples_walnut;
int g_iPerk_apples_walnut;

Handle g_hPerk_apples_avocado;
int g_iPerk_apples_avocado;

public Plugin myinfo = 
{
	name = "Perks for T-RP", 
	author = PLUGIN_AUTHOR, 
	description = "Adds Perks for T-RP", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart() {
	char error[255];
	g_DB = SQL_Connect(dbconfig, true, error, sizeof(error));
	SQL_SetCharset(g_DB, "utf8");
	
	AutoExecConfig_SetFile("rpg_perks");
	AutoExecConfig_SetCreateFile(true);
	
	/* MINING */
	g_hPerk_mining_copper = AutoExecConfig_CreateConVar("perk_mining_copper", "2500", "Price of the Mining Copper Perk");
	g_hPerk_mining_fosil = AutoExecConfig_CreateConVar("perk_mining_fosil", "3500", "Price of the Mining Fosil Perk");
	g_hPerk_mining_iron = AutoExecConfig_CreateConVar("perk_mining_iron", "4500", "Price of the Mining Iron Perk");
	g_hPerk_mining_gold = AutoExecConfig_CreateConVar("perk_mining_gold", "5500", "Price of the Mining Gold Perk");
	
	g_hPerk_mining_boost1 = AutoExecConfig_CreateConVar("perk_mining_boost1", "1000", "Price of the Mining Boost1 Perk");
	g_hPerk_mining_boost2 = AutoExecConfig_CreateConVar("perk_mining_boost2", "2000", "Price of the Mining Boost2 Perk");
	g_hPerk_mining_boost3 = AutoExecConfig_CreateConVar("perk_mining_boost3", "3000", "Price of the Mining Boost3 Perk");
	g_hPerk_mining_boost4 = AutoExecConfig_CreateConVar("perk_mining_boost4", "4000", "Price of the Mining Boost4 Perk");
	
	/* APPLES */
	g_hPerk_apples_boost1 = AutoExecConfig_CreateConVar("perk_apples_boost1", "1000", "Price of the Apples Boost1 Perk");
	g_hPerk_apples_boost2 = AutoExecConfig_CreateConVar("perk_apples_boost2", "2000", "Price of the Apples Boost2 Perk");
	g_hPerk_apples_boost3 = AutoExecConfig_CreateConVar("perk_apples_boost3", "3000", "Price of the Apples Boost3 Perk");
	g_hPerk_apples_boost4 = AutoExecConfig_CreateConVar("perk_apples_boost4", "4000", "Price of the Apples Boost4 Perk");
	
	g_hPerk_apples_pears = AutoExecConfig_CreateConVar("perk_apples_pears", "2500", "Apples:Upgrade to Pears");
	g_hPerk_apples_nuts = AutoExecConfig_CreateConVar("perk_apples_pears", "5000", "Apples:Upgrade to Nuts");
	g_hPerk_apples_walnut = AutoExecConfig_CreateConVar("perk_apples_pears", "7500", "Apples:Upgrade to Walnuts");
	g_hPerk_apples_avocado = AutoExecConfig_CreateConVar("perk_apples_pears", "10000", "Apples:Upgrade to Avocado");
	
	AutoExecConfig_CleanFile();
	AutoExecConfig_ExecuteFile();
	
	char createTableQuery[4096];
	Format(createTableQuery, sizeof(createTableQuery), "CREATE TABLE IF NOT EXISTS t_rpg_perks ( `Id` BIGINT NOT NULL AUTO_INCREMENT , `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , `playerid` VARCHAR(20) NOT NULL , `perk` VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL , PRIMARY KEY (`Id`), UNIQUE (`playerid`, `perk`)) ENGINE = InnoDB;");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createTableQuery);
	
	RegConsoleCmd("sm_cperks", cmdCheckPerks);
}

public Action cmdCheckPerks(int client, int args) {
	PrintToConsole(client, ">> %i Perks <<", g_iOwnedPerks[client]);
	for (int i = 0; i < g_iOwnedPerks[client]; i++)
	PrintToConsole(client, "|-> %s", g_cOwnedPerks[client][i]);
	return Plugin_Handled;
}

public void OnConfigsExecuted() {
	g_iPerk_mining_copper = GetConVarInt(g_hPerk_mining_copper);
	g_iPerk_mining_fosil = GetConVarInt(g_hPerk_mining_fosil);
	g_iPerk_mining_iron = GetConVarInt(g_hPerk_mining_iron);
	g_iPerk_mining_gold = GetConVarInt(g_hPerk_mining_gold);
	
	g_iPerk_mining_boost1 = GetConVarInt(g_hPerk_mining_boost1);
	g_iPerk_mining_boost2 = GetConVarInt(g_hPerk_mining_boost2);
	g_iPerk_mining_boost3 = GetConVarInt(g_hPerk_mining_boost3);
	g_iPerk_mining_boost4 = GetConVarInt(g_hPerk_mining_boost4);
	
	g_iPerk_apples_boost1 = GetConVarInt(g_hPerk_apples_boost1);
	g_iPerk_apples_boost2 = GetConVarInt(g_hPerk_apples_boost2);
	g_iPerk_apples_boost3 = GetConVarInt(g_hPerk_apples_boost3);
	g_iPerk_apples_boost4 = GetConVarInt(g_hPerk_apples_boost4);
	
	g_iPerk_apples_pears = GetConVarInt(g_hPerk_apples_pears);
	g_iPerk_apples_nuts = GetConVarInt(g_hPerk_apples_nuts);
	g_iPerk_apples_walnut = GetConVarInt(g_hPerk_apples_walnut);
	g_iPerk_apples_avocado = GetConVarInt(g_hPerk_apples_avocado);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	/*
		Checks if a Player has a Perk
		@Param1-> int owner
		@Param2-> char Perk[64]
		
		@return true if client has Perk
	
	*/
	CreateNative("perks_hasPerk", Native_hasPerk);
}

public int Native_hasPerk(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	char cPerk[64];
	GetNativeString(2, cPerk, sizeof(cPerk));
	return hasPerk(client, cPerk);
}

public void OnMapStart() {
	npc_registerNpcType(my_npcType);
}

public void OnClientPostAdminCheck(int client) {
	for (int i = 0; i < g_iOwnedPerks[client]; i++)
	strcopy(g_cOwnedPerks[client][i], 64, "");
	g_iOwnedPerks[client] = 0;
	g_iLastInteractedWith[client] = -1;
	loadPerks(client);
}

public void loadPerks(int client) {
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char loadPerksQuery[1024];
	Format(loadPerksQuery, sizeof(loadPerksQuery), "SELECT perk FROM t_rpg_perks WHERE playerid = '%s';", playerid);
	SQL_TQuery(g_DB, SQLLoadPerksQuery, loadPerksQuery, client);
}

public void SQLLoadPerksQuery(Handle owner, Handle hndl, const char[] error, any data) {
	int client = data;
	if (!isValidClient(client))
		return;
	while (SQL_FetchRow(hndl)) {
		char cPerk[64];
		SQL_FetchString(hndl, 0, cPerk, sizeof(cPerk));
		strcopy(g_cOwnedPerks[client][g_iOwnedPerks[client]++], 64, cPerk);
	}
}

public void addPerk(int client, char perk[64]) {
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char addPerkQuery[1024];
	Format(addPerkQuery, sizeof(addPerkQuery), "INSERT IGNORE INTO `t_rpg_perks` (`Id`, `timestamp`, `playerid`, `perk`) VALUES (NULL, CURRENT_TIMESTAMP, '%s', '%s');", playerid, perk);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, addPerkQuery);
	
	strcopy(g_cOwnedPerks[client][g_iOwnedPerks[client]++], 64, perk);
}

public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, any data) {
	if (!StrEqual(error, ""))
		LogError(error);
}

stock bool isValidClient(int client) {
	return (1 <= client <= MaxClients && IsClientInGame(client));
}

public void OnNpcInteract(int client, char npcType[64], char UniqueId[128], int entIndex) {
	if (!StrEqual(my_npcType, npcType))
		return;
	g_iLastInteractedWith[client] = entIndex;
	
	showTopMenu(client);
}

public bool hasPerk(int client, char cPerks[64]) {
	for (int i = 0; i < g_iOwnedPerks[client]; i++)
	if (StrEqual(g_cOwnedPerks[client][i], cPerks))
		return true;
	return false;
}

public void showTopMenu(int client) {
	Menu topMenu = CreateMenu(topMenuHandler);
	SetMenuTitle(topMenu, ">Perks<");
	AddMenuItem(topMenu, "miner", "Miner Perks");
	AddMenuItem(topMenu, "garbage", "Garbage Collector Perks");
	AddMenuItem(topMenu, "apple", "Apple Harvester Perks");
	AddMenuItem(topMenu, "drugs", "Drug Planter Perks");
	DisplayMenu(topMenu, client, 60);
}

public int topMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		char display[64];
		Menu nextMenu = CreateMenu(nextMenuHandler);
		if (StrEqual(cValue, "miner")) {
			SetMenuTitle(nextMenu, "> Mining Perks <");
			if (jobs_isActiveJob(client, "Mining")) {
				
				// Mining Copper
				if (!hasPerk(client, "Mining Copper")) {
					Format(display, sizeof(display), "Mine Copper [3](%i)", g_iPerk_mining_copper);
					if (tConomy_getCurrency(client) >= g_iPerk_mining_copper && jobs_getLevel(client) >= 3)
						AddMenuItem(nextMenu, "mining_copper", display);
					else
						AddMenuItem(nextMenu, "mining_copper", display, ITEMDRAW_DISABLED);
				} else {
					AddMenuItem(nextMenu, "x", "Mine Copper | ^~Owned~^", ITEMDRAW_DISABLED);
				}
				
				
				// Mining Boost 1
				
				if (!hasPerk(client, "Mining Boost1")) {
					Format(display, sizeof(display), "Mining Speed Boost 1 [4](%i)", g_iPerk_mining_boost1);
					if (tConomy_getCurrency(client) >= g_iPerk_mining_boost1 && jobs_getLevel(client) >= 4)
						AddMenuItem(nextMenu, "mining_boost1", display);
					else
						AddMenuItem(nextMenu, "mining_boost1", display, ITEMDRAW_DISABLED);
				} else {
					AddMenuItem(nextMenu, "x", "Mining Speed Boost 1 | ^~Owned~^", ITEMDRAW_DISABLED);
				}
				
				
				// Mining Fossil
				
				if (!hasPerk(client, "Mining Fosil")) {
					Format(display, sizeof(display), "Mine Fosil [5](%i)", g_iPerk_mining_fosil);
					if (tConomy_getCurrency(client) >= g_iPerk_mining_fosil && jobs_getLevel(client) >= 5)
						AddMenuItem(nextMenu, "mining_fosil", display);
					else
						AddMenuItem(nextMenu, "mining_fosil", display, ITEMDRAW_DISABLED);
				} else {
					AddMenuItem(nextMenu, "x", "Mine Fosil | ^~Owned~^", ITEMDRAW_DISABLED);
				}
				
				
				// Mining Boost 2
				if (!hasPerk(client, "Mining Boost2")) {
					Format(display, sizeof(display), "Mining XP Boost 2 [6](%i)", g_iPerk_mining_boost2);
					if (tConomy_getCurrency(client) >= g_iPerk_mining_boost2 && jobs_getLevel(client) >= 6)
						AddMenuItem(nextMenu, "mining_boost2", display);
					else
						AddMenuItem(nextMenu, "mining_boost2", display, ITEMDRAW_DISABLED);
				} else {
					AddMenuItem(nextMenu, "x", "Mining XP Boost 2 | ^~Owned~^", ITEMDRAW_DISABLED);
				}
				
				
				// Mining Iron
				if (!hasPerk(client, "Mining Iron")) {
					Format(display, sizeof(display), "Mine Iron [7](%i)", g_iPerk_mining_iron);
					if (tConomy_getCurrency(client) >= g_iPerk_mining_iron && jobs_getLevel(client) >= 7)
						AddMenuItem(nextMenu, "mining_iron", display);
					else
						AddMenuItem(nextMenu, "mining_iron", display, ITEMDRAW_DISABLED);
				} else {
					AddMenuItem(nextMenu, "x", "Mining Iron | ^~Owned~^", ITEMDRAW_DISABLED);
				}
				
				
				// Mining Boost 3
				if (!hasPerk(client, "Mining Boost3")) {
					Format(display, sizeof(display), "Mining Speed Boost 3 [8](%i)", g_iPerk_mining_boost3);
					if (tConomy_getCurrency(client) >= g_iPerk_mining_boost3 && jobs_getLevel(client) >= 8)
						AddMenuItem(nextMenu, "mining_boost3", display);
					else
						AddMenuItem(nextMenu, "mining_boost3", display, ITEMDRAW_DISABLED);
				} else {
					AddMenuItem(nextMenu, "x", "Mining Speed Boost 3 | ^~Owned~^", ITEMDRAW_DISABLED);
				}
				
				
				// Mining Gold
				if (!hasPerk(client, "Mining Gold")) {
					Format(display, sizeof(display), "Mine Gold [9](%i)", g_iPerk_mining_gold);
					if (tConomy_getCurrency(client) >= g_iPerk_mining_gold && jobs_getLevel(client) >= 9)
						AddMenuItem(nextMenu, "mining_gold", display);
					else
						AddMenuItem(nextMenu, "mining_gold", display, ITEMDRAW_DISABLED);
				} else {
					AddMenuItem(nextMenu, "x", "Mining Gold | ^~Owned~^", ITEMDRAW_DISABLED);
				}
				
				
				// Mining Boost 4
				if (!hasPerk(client, "Mining Boost4")) {
					Format(display, sizeof(display), "Mining XP Boost 4 [10](%i)", g_iPerk_mining_boost4);
					if (tConomy_getCurrency(client) >= g_iPerk_mining_boost4 && jobs_getLevel(client) >= 10)
						AddMenuItem(nextMenu, "mining_boost4", display);
					else
						AddMenuItem(nextMenu, "mining_boost4", display, ITEMDRAW_DISABLED);
				} else {
					AddMenuItem(nextMenu, "x", "Mining XP Boost 4 | ^~Owned~^", ITEMDRAW_DISABLED);
				}
				
				
			} else {
				AddMenuItem(nextMenu, "x", "- You are not a Miner -", ITEMDRAW_DISABLED);
			}
		} else if (StrEqual(cValue, "garbage")) {
			SetMenuTitle(nextMenu, "> Garbage Collector Perks <");
			AddMenuItem(nextMenu, "x", "- There are no Perks for Garbage Collector -", ITEMDRAW_DISABLED);
		} else if (StrEqual(cValue, "apple")) {
			SetMenuTitle(nextMenu, "> Apple Harvester Perks <");
			if (jobs_isActiveJob(client, "Apple Harvester")) {
				// Apples Boost 1
				if (!hasPerk(client, "Apples Boost1")) {
					Format(display, sizeof(display), "Apples boost [4](%i)", g_iPerk_apples_boost1);
					if (tConomy_getCurrency(client) >= g_iPerk_apples_boost1 && jobs_getLevel(client) >= 4)
						AddMenuItem(nextMenu, "apples_boost1", display);
					else
						AddMenuItem(nextMenu, "apples_boost1", display, ITEMDRAW_DISABLED);
				} else {
					AddMenuItem(nextMenu, "x", "Apples Boost1 | ^~Owned~^", ITEMDRAW_DISABLED);
				}
				
				// Upgrade:Pears
				if (!hasPerk(client, "Apple:Pears")) {
					Format(display, sizeof(display), "Upgrade to Pears [5](%i)", g_iPerk_apples_pears);
					if (tConomy_getCurrency(client) >= g_iPerk_apples_pears && jobs_getLevel(client) >= 5)
						AddMenuItem(nextMenu, "apples_pears", display);
					else
						AddMenuItem(nextMenu, "apples_pears", display, ITEMDRAW_DISABLED);
				} else {
					AddMenuItem(nextMenu, "x", "Upgrade to Pears | ^~Owned~^", ITEMDRAW_DISABLED);
				}
				
				// Apples Boost 2
				if (!hasPerk(client, "Apples Boost2")) {
					Format(display, sizeof(display), "Apples boost [6](%i)", g_iPerk_apples_boost2);
					if (tConomy_getCurrency(client) >= g_iPerk_apples_boost2 && jobs_getLevel(client) >= 6)
						AddMenuItem(nextMenu, "apples_boost2", display);
					else
						AddMenuItem(nextMenu, "apples_boost2", display, ITEMDRAW_DISABLED);
				} else {
					AddMenuItem(nextMenu, "x", "Apples Boost2 | ^~Owned~^", ITEMDRAW_DISABLED);
				}
				
				// Upgrade:Nuts
				if (!hasPerk(client, "Apple:Nuts")) {
					Format(display, sizeof(display), "Upgrade to Nuts [7](%i)", g_iPerk_apples_nuts);
					if (tConomy_getCurrency(client) >= g_iPerk_apples_nuts && jobs_getLevel(client) >= 7)
						AddMenuItem(nextMenu, "apples_nuts", display);
					else
						AddMenuItem(nextMenu, "apples_nuts", display, ITEMDRAW_DISABLED);
				} else {
					AddMenuItem(nextMenu, "x", "Upgrade to Nuts | ^~Owned~^", ITEMDRAW_DISABLED);
				}
				
				// Apples Boost 3
				if (!hasPerk(client, "Apples Boost3")) {
					Format(display, sizeof(display), "Apples boost [8](%i)", g_iPerk_apples_boost3);
					if (tConomy_getCurrency(client) >= g_iPerk_apples_boost3 && jobs_getLevel(client) >= 8)
						AddMenuItem(nextMenu, "apples_boost3", display);
					else
						AddMenuItem(nextMenu, "apples_boost3", display, ITEMDRAW_DISABLED);
				} else {
					AddMenuItem(nextMenu, "x", "Apples Boost3 | ^~Owned~^", ITEMDRAW_DISABLED);
				}
				
				// Upgrade:Walnuts
				if (!hasPerk(client, "Apple:Walnuts")) {
					Format(display, sizeof(display), "Upgrade to Walnuts [9](%i)", g_iPerk_apples_walnut);
					if (tConomy_getCurrency(client) >= g_iPerk_apples_walnut && jobs_getLevel(client) >= 9)
						AddMenuItem(nextMenu, "apples_walnuts", display);
					else
						AddMenuItem(nextMenu, "apples_walnuts", display, ITEMDRAW_DISABLED);
				} else {
					AddMenuItem(nextMenu, "x", "Upgrade to Walnuts | ^~Owned~^", ITEMDRAW_DISABLED);
				}
				
				// Apples Boost 4
				if (!hasPerk(client, "Apples Boost4")) {
					Format(display, sizeof(display), "Apples boost [10](%i)", g_iPerk_apples_boost4);
					if (tConomy_getCurrency(client) >= g_iPerk_apples_boost4 && jobs_getLevel(client) >= 10)
						AddMenuItem(nextMenu, "apples_boost4", display);
					else
						AddMenuItem(nextMenu, "apples_boost4", display, ITEMDRAW_DISABLED);
				} else {
					AddMenuItem(nextMenu, "x", "Apples Boost4 | ^~Owned~^", ITEMDRAW_DISABLED);
				}
				
				// Upgrade:Avocado
				if (!hasPerk(client, "Apple:Avocado")) {
					Format(display, sizeof(display), "Upgrade to Avocado [10](%i)", g_iPerk_apples_avocado);
					if (tConomy_getCurrency(client) >= g_iPerk_apples_avocado && jobs_getLevel(client) >= 10)
						AddMenuItem(nextMenu, "apples_avocado", display);
					else
						AddMenuItem(nextMenu, "apples_avocado", display, ITEMDRAW_DISABLED);
				} else {
					AddMenuItem(nextMenu, "x", "Upgrade to Avocado | ^~Owned~^", ITEMDRAW_DISABLED);
				}
				
			} else {
				AddMenuItem(nextMenu, "x", "- You are not a Apple Harvester -", ITEMDRAW_DISABLED);
			}
		} else if (StrEqual(cValue, "drugs")) {
			SetMenuTitle(nextMenu, "> Drug Harvester Perks <");
			AddMenuItem(nextMenu, "x", "- There are no Perks for Drug Harvester -", ITEMDRAW_DISABLED);
		}
		DisplayMenu(nextMenu, client, 60);
	}
}

public int nextMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		
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
		
		if (StrEqual(cValue, "mining_copper")) {
			if (tConomy_getCurrency(client) >= g_iPerk_mining_copper) {
				tConomy_removeCurrency(client, g_iPerk_mining_copper, "Bought Mining Copper Perk");
				addPerk(client, "Mining Copper");
			}
		} else if (StrEqual(cValue, "mining_fosil")) {
			if (tConomy_getCurrency(client) >= g_iPerk_mining_fosil) {
				tConomy_removeCurrency(client, g_iPerk_mining_fosil, "Bought Mining Fosil Perk");
				addPerk(client, "Mining Fosil");
			}
		} else if (StrEqual(cValue, "mining_iron")) {
			if (tConomy_getCurrency(client) >= g_iPerk_mining_iron) {
				tConomy_removeCurrency(client, g_iPerk_mining_iron, "Bought Mining Iron Perk");
				addPerk(client, "Mining Iron");
			}
		} else if (StrEqual(cValue, "mining_gold")) {
			if (tConomy_getCurrency(client) >= g_iPerk_mining_gold) {
				tConomy_removeCurrency(client, g_iPerk_mining_gold, "Bought Mining Gold Perk");
				addPerk(client, "Mining Gold");
			}
		} else if (StrEqual(cValue, "mining_boost1")) {
			if (tConomy_getCurrency(client) >= g_iPerk_mining_boost1) {
				tConomy_removeCurrency(client, g_iPerk_mining_boost1, "Bought Mining Boost1 Perk");
				addPerk(client, "Mining Boost1");
			}
		} else if (StrEqual(cValue, "mining_boost2")) {
			if (tConomy_getCurrency(client) >= g_iPerk_mining_boost2) {
				tConomy_removeCurrency(client, g_iPerk_mining_boost2, "Bought Mining Boost2 Perk");
				addPerk(client, "Mining Boost2");
			}
		} else if (StrEqual(cValue, "mining_boost3")) {
			if (tConomy_getCurrency(client) >= g_iPerk_mining_boost3) {
				tConomy_removeCurrency(client, g_iPerk_mining_boost3, "Bought Mining Boost3 Perk");
				addPerk(client, "Mining Boost3");
			}
		} else if (StrEqual(cValue, "mining_boost4")) {
			if (tConomy_getCurrency(client) >= g_iPerk_mining_boost4) {
				tConomy_removeCurrency(client, g_iPerk_mining_boost4, "Bought Mining Boost4 Perk");
				addPerk(client, "Mining Boost4");
			}
		} else if (StrEqual(cValue, "apples_boost1")) {
			if (tConomy_getCurrency(client) >= g_iPerk_apples_boost1) {
				tConomy_removeCurrency(client, g_iPerk_apples_boost1, "Bought Apples Boost1 Perk");
				addPerk(client, "Apples Boost1");
			}
		} else if (StrEqual(cValue, "apples_boost2")) {
			if (tConomy_getCurrency(client) >= g_iPerk_apples_boost2) {
				tConomy_removeCurrency(client, g_iPerk_apples_boost2, "Bought Apples Boost2 Perk");
				addPerk(client, "Apples Boost2");
			}
		} else if (StrEqual(cValue, "apples_boost3")) {
			if (tConomy_getCurrency(client) >= g_iPerk_apples_boost3) {
				tConomy_removeCurrency(client, g_iPerk_apples_boost3, "Bought Apples Boost3 Perk");
				addPerk(client, "Apples Boost3");
			}
		} else if (StrEqual(cValue, "apples_boost4")) {
			if (tConomy_getCurrency(client) >= g_iPerk_apples_boost4) {
				tConomy_removeCurrency(client, g_iPerk_apples_boost4, "Bought Apples Boost4 Perk");
				addPerk(client, "Apples Boost4");
			}
		} else if (StrEqual(cValue, "apples_avocado")) {
			if (tConomy_getCurrency(client) >= g_iPerk_apples_avocado) {
				tConomy_removeCurrency(client, g_iPerk_apples_avocado, "Bought Apples Avocado Upgrade");
				addPerk(client, "Apple:Avocado");
			}
		} else if (StrEqual(cValue, "apples_walnuts")) {
			if (tConomy_getCurrency(client) >= g_iPerk_apples_walnut) {
				tConomy_removeCurrency(client, g_iPerk_apples_walnut, "Bought Apples Walnuts Upgrade");
				addPerk(client, "Apple:Walnuts");
			}
		} else if (StrEqual(cValue, "apples_nuts")) {
			if (tConomy_getCurrency(client) >= g_iPerk_apples_nuts) {
				tConomy_removeCurrency(client, g_iPerk_apples_nuts, "Bought Apples Nuts Upgrade");
				addPerk(client, "Apple:Nuts");
			}
		} else if (StrEqual(cValue, "apples_pears")) {
			if (tConomy_getCurrency(client) >= g_iPerk_apples_pears) {
				tConomy_removeCurrency(client, g_iPerk_apples_pears, "Bought Apples Pears Upgrade");
				addPerk(client, "Apple:Pears");
			}
		}
	}
} 