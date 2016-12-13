#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <devzones>
#include <tConomy>
#include <smlib>

#pragma newdecls required


#define MAX_APARTMENTS 512

int g_iPlayerPrevButtons[MAXPLAYERS + 1];
char g_cDBConfig[] = "gsxh_multiroot";
char activeZone[MAXPLAYERS + 1][128];

Database g_DB;

float zone_pos[MAXPLAYERS + 1][3];
Handle g_hClientTimers[MAXPLAYERS + 1] =  { INVALID_HANDLE, ... };

enum existingApartment {
	eaId, 
	String:eaApartment_Id[128],  // = Zone ID
	eaApartment_Price, 
	bool:eaBuyable, 
	String:eaFlag[8], 
	bool:eaBought
}

int g_iLoadedApartments = 0;
int existingApartments[MAX_APARTMENTS][existingApartment];


enum ownedApartment {
	oaId, 
	String:oaTime_of_purchase[64], 
	oaPrice_of_purchase, 
	String:oaApartment_Id[128],  // = Zone ID
	String:oaPlayerid[20], 
	String:oaPlayername[48], 
	String:oaApartmentName[255], 
	String:oaAllowed_players[550], 
	bool:oaDoor_locked
}

int g_iOwnedApartmentsCount = 0;
int ownedApartments[MAX_APARTMENTS][ownedApartment];

enum playerProperty {
	ppInEdit, 
	String:ppZone[128]
}

int playerProperties[MAXPLAYERS + 1][playerProperty];


public Plugin myinfo = 
{
	name = "RPG Housing", 
	author = PLUGIN_AUTHOR, 
	description = "RPH Housing for T-RP", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart()
{
	/*
		Table Struct (1) (existing apartments)
		Id		apartment_id	apartment_price	buyable	flag	bought	map
		int		vchar			int				bool	vchar	boolean	vchar
		
		
		Table Struct (2) (bought Table)
		Id	time_of_purchase	price_of_purchase	apartment_id	playerid	playername	apartment_name	allowed_players	door_locked	map
		int	timestamp			int					vchar			vchar		vchar		vchar			vchar			bool		vchar
	*/
	
	char error[255];
	g_DB = SQL_Connect(g_cDBConfig, true, error, sizeof(error));
	SQL_SetCharset(g_DB, "utf8");
	
	char createExistingApartmentsTable[4096];
	Format(createExistingApartmentsTable, sizeof(createExistingApartmentsTable), "CREATE TABLE IF NOT EXISTS `t_rpg_apartments` ( `Id` BIGINT NULL DEFAULT NULL AUTO_INCREMENT , `apartment_id` VARCHAR(128) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL , `apartment_price` INT NOT NULL , `buyable` BOOLEAN NOT NULL , `flag` VARCHAR(8) NOT NULL , `bought` BOOLEAN NOT NULL , `map` varchar(128) COLLATE utf8_bin NOT NULL , UNIQUE KEY `apartment_id` (`apartment_id`), PRIMARY KEY (`Id`)) ENGINE = InnoDB CHARSET=utf8 COLLATE utf8_bin;");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createExistingApartmentsTable);
	
	char createBoughtApartmentsTable[4096];
	Format(createBoughtApartmentsTable, sizeof(createBoughtApartmentsTable), "CREATE TABLE IF NOT EXISTS `t_rpg_boughtApartments` ( `Id` BIGINT NULL DEFAULT NULL AUTO_INCREMENT , `time_of_purchase` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , `price_of_purchase` INT NOT NULL , `apartment_id` VARCHAR(128) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL , `playerid` VARCHAR(20) NOT NULL , `playername` VARCHAR(48) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL , `apartment_name` VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL , `allowed_players` VARCHAR(550) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL , `door_locked` BOOLEAN NOT NULL , `map` varchar(128) COLLATE utf8_bin NOT NULL , UNIQUE KEY `apartment_id` (`apartment_id`), PRIMARY KEY (`Id`)) ENGINE = InnoDB CHARSET=utf8 COLLATE utf8_bin;");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createBoughtApartmentsTable);
	
	RegAdminCmd("sm_apartmentadmin", createApartmentCallback, ADMFLAG_ROOT, "Opens the Apartment Admin Menu");
	RegConsoleCmd("sm_apartment", apartmentCommand, "Opens the Apartment Menu");
	RegConsoleCmd("say", chatHook);
	
	loadApartments();
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon, int &tickcount) {
	if (IsClientInGame(client) && IsPlayerAlive(client)) {
		if (!(g_iPlayerPrevButtons[client] & IN_USE) && iButtons & IN_USE) {
			int ent = GetClientAimTarget(client, false);
			if (!IsValidEntity(ent)) {
				g_iPlayerPrevButtons[client] = iButtons;
				return;
			}
			if (Zone_CheckIfZoneExists(activeZone[client], true, true)) {
				if (HasEntProp(ent, Prop_Data, "m_iName")) {
					char itemName[128];
					GetEntPropString(ent, Prop_Data, "m_iName", itemName, sizeof(itemName));
					if (StrContains(itemName, "door", false)) {
						doorAction(client, activeZone[client], ent);
					}
				}
				if (StrContains(activeZone[client], "apartment", false) != -1)
					apartmentAction(client);
			}
		}
	}
	g_iPlayerPrevButtons[client] = iButtons;
}

public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, any data) {
	if (!StrEqual(error, ""))
		LogError(error);
}

public void OnClientPostAdminCheck(int client) {
	strcopy(activeZone[client], sizeof(activeZone), "");
}

public int Zone_OnClientEntry(int client, char[] zone) {
	strcopy(activeZone[client], sizeof(activeZone), zone);
	if (StrContains(zone, "apartment_", false) == 0) {
		int zoneId;
		char eZone[128];
		strcopy(eZone, sizeof(eZone), zone);
		if ((zoneId = getLoadedIdFromApartmentId(eZone)) != -1) {
			int ownedId;
			if ((ownedId = ApartmentIdToOwnedId(zoneId)) != -1) {
				char playerid[20];
				GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
				if (StrContains(ownedApartments[ownedId][oaAllowed_players], playerid) == -1) {
					if (!StrEqual(ownedApartments[ownedId][oaPlayerid], playerid)) {
						if (ownedApartments[ownedId][oaDoor_locked]) {
							Zone_GetZonePosition(zone, false, zone_pos[client]);
							g_hClientTimers[client] = CreateTimer(0.1, Timer_Repeat, client, TIMER_REPEAT);
							PrintToChat(client, "You can't enter %s", ownedApartments[ownedId][oaApartmentName]);
						}
					}
				}
			}
		}
	}
}

public int Zone_OnClientLeave(int client, char[] zone) {
	strcopy(activeZone[client], sizeof(activeZone), "");
	if (StrContains(zone, "apartment_", false) != -1) {
		if (g_hClientTimers[client] != INVALID_HANDLE)
			KillTimer(g_hClientTimers[client]);
		g_hClientTimers[client] = INVALID_HANDLE;
	}
}

public void doorAction(int client, char[] zone, int doorEnt) {
	
}

public Action apartmentCommand(int client, int args) {
	int zoneId;
	if ((zoneId = getLoadedIdFromApartmentId(activeZone[client])) != -1) {
		int ownedId;
		if ((ownedId = ApartmentIdToOwnedId(zoneId)) != -1) {
			char playerid[20];
			GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
			if (StrEqual(ownedApartments[ownedId][oaPlayerid], playerid)) {
				Menu apartmentMenu = CreateMenu(apartmentMenuHandler);
				char menuTitle[256];
				Format(menuTitle, sizeof(menuTitle), "%s", ownedApartments[ownedId][oaApartmentName]);
				AddMenuItem(apartmentMenu, "rename", "Rename Apartment");
				AddMenuItem(apartmentMenu, "revoke", "Revoke all Access");
				AddMenuItem(apartmentMenu, "lock", "Lock Doors");
				AddMenuItem(apartmentMenu, "unlock", "Lock Doors");
				char sellPriceDisplay[128];
				Format(sellPriceDisplay, sizeof(sellPriceDisplay), "Sell Apartment for %.1f", ownedApartments[ownedId][oaPrice_of_purchase] * 0.80);
				AddMenuItem(apartmentMenu, "sell", sellPriceDisplay);
				strcopy(playerProperties[client][ppZone], 128, activeZone[client]);
				DisplayMenu(apartmentMenu, client, 60);
			} else {
				PrintToChat(client, "This Apartment does not belong to you");
			}
		}
	}
}

public int apartmentMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "rename")) {
			playerProperties[client][ppInEdit] = 2;
			PrintToChat(client, "Enter the Apartment Name OR 'abort' to cancel");
		} else if (StrEqual(cValue, "revoke")) {
			revokeAllAccess(client);
			PrintToChat(client, "Revoked all Allowed Players");
		} else if (StrEqual(cValue, "lock")) {
			changeDoorLock(client, 1);
			PrintToChat(client, "Locked Doors");
		} else if (StrEqual(cValue, "unlock")) {
			changeDoorLock(client, 1);
			PrintToChat(client, "Unlocked Doors");
		} else if (StrEqual(cValue, "sell")) {
			sellApartment(client);
			PrintToChat(client, "Sold Apartment");
		}
		apartmentCommand(client, 0);
	}
}

public void apartmentAction(int client) {
	int apartmentId;
	if ((apartmentId = getLoadedIdFromApartmentId(activeZone[client])) != -1) {
		if (existingApartments[apartmentId][eaBuyable] && !existingApartments[apartmentId][eaBought]) {
			char val[8];
			IntToString(apartmentId, val, sizeof(val));
			
			Menu buyApartmentMenu = CreateMenu(buyApartmentHandler);
			SetMenuTitle(buyApartmentMenu, "Apartment Menu");
			char buyApartmentText[512];
			if (!(tConomy_getCurrency(client) >= existingApartments[apartmentId][eaApartment_Price])) {
				Format(buyApartmentText, sizeof(buyApartmentText), "Buy Apartment for %i", existingApartments[apartmentId][eaApartment_Price]);
				AddMenuItem(buyApartmentMenu, val, buyApartmentText);
			} else {
				Format(buyApartmentText, sizeof(buyApartmentText), "Buy Apartment for %i (no Money)", existingApartments[apartmentId][eaApartment_Price]);
				AddMenuItem(buyApartmentMenu, val, buyApartmentText, ITEMDRAW_DISABLED);
			}
			
			DisplayMenu(buyApartmentMenu, client, 30);
		} else if (!existingApartments[apartmentId][eaBuyable]) {
			PrintToChat(client, "This Apartment is not for Sale");
		} else if (existingApartments[apartmentId][eaBought]) {
			int owned;
			if ((owned = ApartmentIdToOwnedId(apartmentId)) != -1)
				PrintToChat(client, "This Apartment (%i | %i) '%s' is owned by %s", apartmentId, owned, ownedApartments[owned][oaApartmentName], ownedApartments[owned][oaPlayername]);
		}
	}
	PrintToChat(client, "Selected: %i", apartmentId);
}

public int buyApartmentHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		int apartmentId = StringToInt(cValue);
		buyApartment(client, apartmentId);
	}
}

public void buyApartment(int client, int id) {
	if (existingApartments[id][eaBuyable] && !existingApartments[id][eaBought]) {
		if (!(tConomy_getCurrency(client) < existingApartments[id][eaApartment_Price])) {
			PrintToChat(client, "You can not afford this Apartment");
			return;
		}
		tConomy_removeCurrency(client, existingApartments[id][eaApartment_Price], "Bought Apartment");
		existingApartments[id][eaBought] = true;
		
		char mapName[128];
		GetCurrentMap(mapName, sizeof(mapName));
		
		char buyApartmentQuery[512];
		Format(buyApartmentQuery, sizeof(buyApartmentQuery), "UPDATE t_rpg_apartments SET bought = 1 WHERE apartment_id = '%s' AND map = '%s';", activeZone[client], mapName);
		SQL_TQuery(g_DB, SQLErrorCheckCallback, buyApartmentQuery);
		
		char playerid[20];
		GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
		
		char playername[MAX_NAME_LENGTH + 8];
		GetClientName(client, playername, sizeof(playername));
		
		char clean_playername[MAX_NAME_LENGTH * 2 + 16];
		SQL_EscapeString(g_DB, playername, clean_playername, sizeof(clean_playername));
		
		char apartment_name[255];
		Format(apartment_name, sizeof(apartment_name), "%ss Apartment", clean_playername);
		
		Format(buyApartmentQuery, sizeof(buyApartmentQuery), "INSERT INTO `t_rpg_boughtApartments` (`Id`, `time_of_purchase`, `price_of_purchase`, `apartment_id`, `playerid`, `playername`, `apartment_name`, `allowed_players`, `door_locked`, `map`) VALUES (NULL, CURRENT_TIMESTAMP, '%i', '%s', '%s', '%s', '%s', '', '0', '%s');", existingApartments[id][eaApartment_Price], activeZone[client], playerid, clean_playername, apartment_name, mapName);
		SQL_TQuery(g_DB, SQLErrorCheckCallback, buyApartmentQuery);
		
		char time[32];
		IntToString(GetTime(), time, sizeof(time));
		ownedApartments[g_iOwnedApartmentsCount][oaId] = g_iOwnedApartmentsCount;
		strcopy(ownedApartments[g_iOwnedApartmentsCount][oaTime_of_purchase], 64, time);
		ownedApartments[g_iOwnedApartmentsCount][oaPrice_of_purchase] = existingApartments[id][eaApartment_Price];
		strcopy(ownedApartments[g_iOwnedApartmentsCount][oaApartment_Id], 128, activeZone[client]);
		strcopy(ownedApartments[g_iOwnedApartmentsCount][oaPlayerid], 20, playerid);
		strcopy(ownedApartments[g_iOwnedApartmentsCount][oaPlayername], 48, playername);
		strcopy(ownedApartments[g_iOwnedApartmentsCount][oaApartmentName], 255, apartment_name);
		strcopy(ownedApartments[g_iOwnedApartmentsCount][oaAllowed_players], 550, "");
		ownedApartments[g_iOwnedApartmentsCount++][oaDoor_locked] = false;
	}
}

public Action createApartmentCallback(int client, int args) {
	Menu createApartmentMenu = CreateMenu(createApartmentHandler);
	char addApartment[128];
	SetMenuTitle(createApartmentMenu, "Apartment Admin");
	Format(addApartment, sizeof(addApartment), "Create Apartment( %s )", activeZone[client]);
	if (apartmentExists(activeZone[client]))
		AddMenuItem(createApartmentMenu, "addThis", addApartment, ITEMDRAW_DISABLED);
	else
		AddMenuItem(createApartmentMenu, "addThis", addApartment);
	char deleteApartmentText[128];
	Format(deleteApartmentText, sizeof(deleteApartmentText), "Delete Apartment( %s )", activeZone[client]);
	if (apartmentExists(activeZone[client]))
		AddMenuItem(createApartmentMenu, "deleteThis", deleteApartmentText);
	else
		AddMenuItem(createApartmentMenu, "deleteThis", deleteApartmentText, ITEMDRAW_DISABLED);
	char editApartment[128];
	if (apartmentExists(activeZone[client]))
		Format(editApartment, sizeof(editApartment), "Edit Apartment( %s ) - TODO", activeZone[client]);
	else
		Format(editApartment, sizeof(editApartment), "Edit Apartment( %s ) - TODO", activeZone[client], ITEMDRAW_DISABLED);
	AddMenuItem(createApartmentMenu, "editThis", editApartment);
	AddMenuItem(createApartmentMenu, "delete", "Delete another Apartment");
	AddMenuItem(createApartmentMenu, "edit", "Edit another Apartment - TODO");
	DisplayMenu(createApartmentMenu, client, 30);
	
	return Plugin_Handled;
}

public int createApartmentHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "addThis")) {
			playerProperties[client][ppInEdit] = 1;
			strcopy(playerProperties[client][ppZone], 128, activeZone[client]);
			PrintToChat(client, "Enter the Apartment Price OR 'abort' to cancel");
		} else if (StrEqual(cValue, "deleteThis")) {
			deleteApartment(playerProperties[client][ppZone]);
		} else if (StrEqual(cValue, "editThis")) {
			// TODO
		} else if (StrEqual(cValue, "delete")) {
			loadMenuForDeletion(client);
		} else if (StrEqual(cValue, "edit")) {
			
		}
	}
}

public void loadMenuForDeletion(int client) {
	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	
	char getAllApartmentsForDeletion[1024];
	Format(getAllApartmentsForDeletion, sizeof(getAllApartmentsForDeletion), "SELECT * FROM t_rpg_apartments WHERE map = '%s';", mapName);
	SQL_TQuery(g_DB, showAllApartmentsForDeletion, getAllApartmentsForDeletion, client);
}

public void showAllApartmentsForDeletion(Handle owner, Handle hndl, const char[] error, any data) {
	int client = data;
	Menu deleteApartmentMenu = CreateMenu(deleteApartmentMenuHandler);
	SetMenuTitle(deleteApartmentMenu, "Delete Apartment");
	bool hasData = false;
	while (SQL_FetchRow(hndl)) {
		char name[64];
		SQL_FetchStringByName(hndl, "apartment_id", name, sizeof(name));
		
		int Id = SQL_FetchIntByName(hndl, "Id");
		char cId[8];
		IntToString(Id, cId, sizeof(cId));
		char display[70];
		Format(display, sizeof(display), "%i: %s", Id, name);
		
		AddMenuItem(deleteApartmentMenu, name, display);
		hasData = true;
	}
	if (!hasData)
		AddMenuItem(deleteApartmentMenu, "-1", "- There are no Apartments - ", ITEMDRAW_DISABLED);
	DisplayMenu(deleteApartmentMenu, client, 60);
}

public int deleteApartmentMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char mapName[128];
		GetCurrentMap(mapName, sizeof(mapName));
		
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		char deleteApartmentQuery[1024];
		Format(deleteApartmentQuery, sizeof(deleteApartmentQuery), "DELETE FROM t_rpg_apartments WHERE apartment_id = '%s' AND map = '%s';", cValue, mapName);
		SQL_TQuery(g_DB, SQLErrorCheckCallback, deleteApartmentQuery);
		
		Format(deleteApartmentQuery, sizeof(deleteApartmentQuery), "DELETE FROM t_rpg_boughtApartments WHERE apartment_id = '%s' AND map = '%s';", cValue, mapName);
		SQL_TQuery(g_DB, SQLErrorCheckCallback, deleteApartmentQuery);
		
		loadMenuForDeletion(client);
	}
}

public Action chatHook(int client, int args) {
	char text[1024];
	GetCmdArgString(text, sizeof(text));
	StripQuotes(text);
	
	if (playerProperties[client][ppInEdit] == 1 && StrContains(text, "abort") == -1) {
		createApartment(playerProperties[client][ppZone], StringToInt(text));
		PrintToChat(client, "Created: %s - Price: %i", playerProperties[client][ppZone], StringToInt(text));
		playerProperties[client][ppInEdit] = -1;
		return Plugin_Handled;
	} else if (playerProperties[client][ppInEdit] == 2 && StrContains(text, "abort") == -1) {
		PrintToChat(client, "Renamed: %s to: %s", playerProperties[client][ppZone], text);
		playerProperties[client][ppInEdit] = -1;
		
		char clean_apartment_name[128];
		SQL_EscapeString(g_DB, text, clean_apartment_name, sizeof(clean_apartment_name));
		
		char mapName[128];
		GetCurrentMap(mapName, sizeof(mapName));
		
		char updateNameQuery[1024];
		Format(updateNameQuery, sizeof(updateNameQuery), "UPDATE t_rpg_boughtApartments SET apartment_name = '%s' WHERE apartment_id = '%s' AND map = '%s';", clean_apartment_name, playerProperties[client][ppZone], mapName);
		SQL_TQuery(g_DB, SQLErrorCheckCallback, updateNameQuery);
		
		strcopy(ownedApartments[getOwnedApartmentFromKey(playerProperties[client][ppZone])][oaApartmentName], 128, clean_apartment_name);
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public void createApartment(char[] apartmentId, int price) {
	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	
	char createApartmentQuery[4096];
	Format(createApartmentQuery, sizeof(createApartmentQuery), "INSERT IGNORE INTO `t_rpg_apartments` (`Id`, `apartment_id`, `apartment_price`, `buyable`, `flag`, `bought`, `map`) VALUES (NULL, '%s', '%i', '1', '', '0', '%s');", apartmentId, price, mapName);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createApartmentQuery);
	
	strcopy(existingApartments[g_iLoadedApartments][eaApartment_Id], 128, apartmentId);
	existingApartments[g_iLoadedApartments][eaApartment_Price] = price;
	existingApartments[g_iLoadedApartments][eaBuyable] = true;
	strcopy(existingApartments[g_iLoadedApartments][eaFlag], 8, "");
	existingApartments[g_iLoadedApartments++][eaBought] = false;
}

public void deleteApartment(char[] apartmentId) {
	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	
	char deleteApartmentQuery[4096];
	Format(deleteApartmentQuery, sizeof(deleteApartmentQuery), "DELETE FROM `t_rpg_apartments` WHERE apartment_id = '%s' AND map = '%s';", apartmentId, mapName);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, deleteApartmentQuery);
	
	Format(deleteApartmentQuery, sizeof(deleteApartmentQuery), "DELETE FROM `t_rpg_boughtApartments` WHERE apartment_id = '%s' AND map = '%s';", apartmentId, mapName);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, deleteApartmentQuery);
}

public void loadApartments() {
	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	
	char loadApartmentsQuery[1024];
	Format(loadApartmentsQuery, sizeof(loadApartmentsQuery), "SELECT apartment_id,apartment_price,buyable,flag,bought FROM t_rpg_apartments WHERE map = '%s';", mapName);
	SQL_TQuery(g_DB, SQLLoadApartmentsQueryCallback, loadApartmentsQuery);
	
	char loadOwnedApartments[1024];
	Format(loadOwnedApartments, sizeof(loadOwnedApartments), "SELECT time_of_purchase,price_of_purchase,apartment_id,playerid,playername,apartment_name,allowed_players,door_locked FROM t_rpg_boughtApartments WHERE map = '%s';", mapName);
	SQL_TQuery(g_DB, SQLLoadOwnedApartmentsQueryCallback, loadOwnedApartments);
}


public void SQLLoadApartmentsQueryCallback(Handle owner, Handle hndl, const char[] error, any data) {
	while (SQL_FetchRow(hndl)) {
		SQL_FetchStringByName(hndl, "apartment_id", existingApartments[g_iLoadedApartments][eaApartment_Id], 128);
		existingApartments[g_iLoadedApartments][eaApartment_Price] = SQL_FetchIntByName(hndl, "apartment_price");
		existingApartments[g_iLoadedApartments][eaBuyable] = SQL_FetchBoolByName(hndl, "buyable");
		SQL_FetchStringByName(hndl, "flag", existingApartments[g_iLoadedApartments][eaFlag], 8);
		existingApartments[g_iLoadedApartments++][eaBought] = SQL_FetchBoolByName(hndl, "bought");
	}
}

public void SQLLoadOwnedApartmentsQueryCallback(Handle owner, Handle hndl, const char[] error, any data) {
	while (SQL_FetchRow(hndl)) {
		ownedApartments[g_iOwnedApartmentsCount][oaId] = g_iOwnedApartmentsCount;
		SQL_FetchStringByName(hndl, "time_of_purchase", ownedApartments[g_iOwnedApartmentsCount][oaTime_of_purchase], 64);
		ownedApartments[g_iOwnedApartmentsCount][oaPrice_of_purchase] = SQL_FetchIntByName(hndl, "oaPrice_of_purchase");
		SQL_FetchStringByName(hndl, "apartment_id", ownedApartments[g_iOwnedApartmentsCount][oaApartment_Id], 128);
		SQL_FetchStringByName(hndl, "playerid", ownedApartments[g_iOwnedApartmentsCount][oaPlayerid], 20);
		SQL_FetchStringByName(hndl, "playername", ownedApartments[g_iOwnedApartmentsCount][oaPlayername], 48);
		SQL_FetchStringByName(hndl, "apartment_name", ownedApartments[g_iOwnedApartmentsCount][oaApartmentName], 255);
		SQL_FetchStringByName(hndl, "allowed_players", ownedApartments[g_iOwnedApartmentsCount][oaAllowed_players], 550);
		ownedApartments[g_iOwnedApartmentsCount++][oaDoor_locked] = SQL_FetchBoolByName(hndl, "door_locked");
	}
}

public int getLoadedIdFromApartmentId(char[] apartmentId) {
	for (int i = 0; i < g_iLoadedApartments; i++) {
		if (StrEqual(existingApartments[i][eaApartment_Id], apartmentId))
			return i;
	}
	return -1;
}

public int ApartmentIdToOwnedId(int apartmentKey) {
	for (int x = 0; x < g_iOwnedApartmentsCount; x++) {
		if (StrEqual(existingApartments[apartmentKey][eaApartment_Id], ownedApartments[x][oaApartment_Id]))
			return x;
	}
	return -1;
}

public int getOwnedApartmentFromKey(char[] apartmentId) {
	int apId;
	if ((apId = getLoadedIdFromApartmentId(apartmentId)) != -1) {
		int owned;
		if ((owned = ApartmentIdToOwnedId(apId)) != -1) {
			return owned;
		}
	}
	return -1;
}

public void revokeAllAccess(int client) {
	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	strcopy(playerProperties[client][ppZone], 128, activeZone[client]);
	char updateNameQuery[1024];
	Format(updateNameQuery, sizeof(updateNameQuery), "UPDATE t_rpg_boughtApartments SET allowed_players = '' WHERE apartment_id = '%s' AND map = '%s';", playerProperties[client][ppZone], mapName);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateNameQuery);
	strcopy(ownedApartments[getOwnedApartmentFromKey(playerProperties[client][ppZone])][oaAllowed_players], 550, "");
	strcopy(playerProperties[client][ppZone], 128, "");
}

public void changeDoorLock(int client, int state/* 1 = Locked | 0 = Unlocked */) {
	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	strcopy(playerProperties[client][ppZone], 128, activeZone[client]);
	char updateDoorLockQuery[1024];
	Format(updateDoorLockQuery, sizeof(updateDoorLockQuery), "UPDATE t_rpg_boughtApartments SET door_locked = %i WHERE apartment_id = '%s' AND map = '%s';", state, playerProperties[client][ppZone], mapName);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateDoorLockQuery);
	ownedApartments[getOwnedApartmentFromKey(playerProperties[client][ppZone])][oaDoor_locked] = state == 1;
	strcopy(playerProperties[client][ppZone], 128, "");
}

public void sellApartment(int client) {
	int aptId = getOwnedApartmentFromKey(playerProperties[client][ppZone]);
	int sellPrice = RoundToNearest(ownedApartments[aptId][oaPrice_of_purchase] * 0.80);
	tConomy_addCurrency(client, sellPrice, "Sold Apartment");
	
	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	
	char sellApartmentQuery[4096];
	Format(sellApartmentQuery, sizeof(sellApartmentQuery), "DELETE FROM `t_rpg_boughtApartments` WHERE apartment_id = '%s' AND map = '%s';", ownedApartments[aptId][oaApartment_Id]);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, sellApartmentQuery);
	
	ownedApartments[aptId][oaId] = -1;
	strcopy(ownedApartments[aptId][oaTime_of_purchase], 64, "");
	ownedApartments[aptId][oaPrice_of_purchase] = -1;
	strcopy(ownedApartments[aptId][oaApartment_Id], 128, "");
	strcopy(ownedApartments[aptId][oaPlayerid], 20, "");
	strcopy(ownedApartments[aptId][oaPlayername], 48, "");
	strcopy(ownedApartments[aptId][oaApartmentName], 255, "");
	strcopy(ownedApartments[aptId][oaAllowed_players], 550, "");
	ownedApartments[aptId][oaDoor_locked] = false;
}



public bool apartmentExists(char[] apartmentId) {
	for (int x = 0; x < g_iLoadedApartments; x++) {
		if (StrEqual(existingApartments[x][eaApartment_Id], apartmentId))
			return true;
	}
	return false;
}

public void OnClientDisconnect(int client) {
	if (g_hClientTimers[client] != INVALID_HANDLE)
		KillTimer(g_hClientTimers[client]);
	g_hClientTimers[client] = INVALID_HANDLE;
}

public Action Timer_Repeat(Handle timer, any client) {
	if (!IsClientInGame(client) || !IsPlayerAlive(client)) {
		if (g_hClientTimers[client] != INVALID_HANDLE)
			KillTimer(g_hClientTimers[client]);
		g_hClientTimers[client] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	float clientloc[3];
	GetClientAbsOrigin(client, clientloc);
	
	KnockbackSetVelocity(client, zone_pos[client], clientloc, 300.0);
	return Plugin_Continue;
}

public void KnockbackSetVelocity(int client, const float startpoint[3], const float endpoint[3], float magnitude) {
	float vector[3];
	MakeVectorFromPoints(startpoint, endpoint, vector);
	NormalizeVector(vector, vector);
	ScaleVector(vector, magnitude);
	
	
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vector);
} 