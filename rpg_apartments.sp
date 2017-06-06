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
#include <devzones>
#include <tConomy>
#include <smlib>
#include <rpg_jobs_core>
#include <rpg_inventory_core>
#include <tCrime>
#include <sdkhooks>
#include <tStocks>
#include <rpg_furniture>

#pragma newdecls required


#define MAX_APARTMENTS 512
#define MAX_OWNED 2

int g_iPlayerPrevButtons[MAXPLAYERS + 1];
char g_cDBConfig[] = "gsxh_multiroot";
char activeZone[MAXPLAYERS + 1][128];
char prevZone[MAXPLAYERS + 1][128];

Database g_DB;

float zone_pos[MAXPLAYERS + 1][3];
Handle g_hClientTimers[MAXPLAYERS + 1] =  { INVALID_HANDLE, ... };

int g_iActiveGlows[4096];

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
	name = "[T-RP] Apartment Core", 
	author = PLUGIN_AUTHOR, 
	description = "Adds Housing for T-RP", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
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
	Format(createExistingApartmentsTable, sizeof(createExistingApartmentsTable), "CREATE TABLE IF NOT EXISTS `t_rpg_apartments` ( `Id` BIGINT NOT NULL DEFAULT NULL AUTO_INCREMENT , `apartment_id` VARCHAR(128) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL , `apartment_price` INT NOT NULL , `buyable` BOOLEAN NOT NULL , `flag` VARCHAR(8) NOT NULL , `bought` BOOLEAN NOT NULL , `map` varchar(128) COLLATE utf8_bin NOT NULL , UNIQUE KEY `apartment_id` (`apartment_id`), PRIMARY KEY (`Id`)) ENGINE = InnoDB CHARSET=utf8 COLLATE utf8_bin;");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createExistingApartmentsTable);
	
	char createBoughtApartmentsTable[4096];
	Format(createBoughtApartmentsTable, sizeof(createBoughtApartmentsTable), "CREATE TABLE IF NOT EXISTS `t_rpg_boughtApartments` ( `Id` BIGINT NOT NULL DEFAULT NULL AUTO_INCREMENT , `time_of_purchase` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , `price_of_purchase` INT NOT NULL , `apartment_id` VARCHAR(128) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL , `playerid` VARCHAR(20) NOT NULL , `playername` VARCHAR(48) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL , `apartment_name` VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL , `allowed_players` VARCHAR(550) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL , `door_locked` BOOLEAN NOT NULL , `map` varchar(128) COLLATE utf8_bin NOT NULL , UNIQUE KEY `apartment_id` (`apartment_id`), PRIMARY KEY (`Id`)) ENGINE = InnoDB CHARSET=utf8 COLLATE utf8_bin;");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createBoughtApartmentsTable);
	
	char createRentsTable[4096];
	Format(createRentsTable, sizeof(createRentsTable), "CREATE TABLE IF NOT EXISTS `t_rpg_apartment_rent` ( `cId` BIGINT AUTO_INCREMENT NOT NULL PRIMARY KEY, `Id` BIGINT NOT NULL , `playerid` VARCHAR(20) NOT NULL , `startrent` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , `endrent` TIMESTAMP NOT NULL, FOREIGN KEY (Id) REFERENCES t_rpg_apartments(Id)) ENGINE = InnoDB;");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createRentsTable);
	
	RegAdminCmd("sm_apartmentadmin", createApartmentCallback, ADMFLAG_ROOT, "Opens the Apartment Admin Menu");
	RegConsoleCmd("sm_apartment", apartmentCommand, "Opens the Apartment Menu");
	RegAdminCmd("sm_apartmentlist", listAps, ADMFLAG_ROOT, "list aps");
	RegAdminCmd("sm_postloadaps", postloadaps, ADMFLAG_ROOT, "postloads aps");
	RegConsoleCmd("sm_az", checkZone);
	HookEvent("round_start", onRoundStart);
	RegConsoleCmd("say", chatHook);
	resetAps();
}

public Action checkZone(int client, int args) {
	char mraz[64];
	Zone_getMostRecentActiveZone(client, mraz);
	PrintToChat(client, "Z:%s| OZ:%s|-|x:%.2f y:%.2f z:%.2f|mraz: %s", activeZone[client], prevZone[client], zone_pos[client][0], zone_pos[client][1], zone_pos[client][2], mraz);
	return Plugin_Handled;
}

public void resetAps() {
	for (int i = 0; i < MAX_APARTMENTS; i++) {
		ownedApartments[i][oaId] = -1;
		strcopy(ownedApartments[i][oaTime_of_purchase], 64, "");
		ownedApartments[i][oaPrice_of_purchase] = -1;
		strcopy(ownedApartments[i][oaApartment_Id], 128, "");
		strcopy(ownedApartments[i][oaPlayerid], 20, "");
		strcopy(ownedApartments[i][oaPlayername], 48, "");
		strcopy(ownedApartments[i][oaApartmentName], 255, "");
		strcopy(ownedApartments[i][oaAllowed_players], 550, "");
		ownedApartments[i][oaDoor_locked] = false;
		
		existingApartments[i][eaId] = -1;
		g_iLoadedApartments = 0;
		g_iOwnedApartmentsCount = 0;
	}
}

public void OnMapStart() {
	loadApartments();
	CreateTimer(180.0, evictTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action postloadaps(int client, int args) {
	loadApartments();
}


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	/*
		Allows a Player to an Apartment
		@Param1-> int owner
		@Param2-> int target
		
		@return true if successfull false if not
	
	*/
	CreateNative("aparments_allowPlayer", Native_allowPlayer);
	
	/*
		Checks if a client is the owner of an Apartment
		@Param1 -> int owner
		@Param2 -> apartmentId[128] (zone ID)
		return true or false
	*/
	CreateNative("apartments_isClientOwner", Native_isClientOwner);
	
	/*
		Returns the Buy Price of an Apartment
		@Param1 -> apartmentId[128] (zone ID)
		return Price or -1 if invalid
	*/
	CreateNative("apartments_getBuyPrice", Native_getBuyPrice);
}

public int Native_allowPlayer(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	int target = GetNativeCell(2);
	allowPlayerToApartmentChooser(client, target);
}

public int Native_isClientOwner(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	char apartmentId[128];
	GetNativeString(2, apartmentId, sizeof(apartmentId));
	return isOwnedBy(client, apartmentId);
}

public int Native_getBuyPrice(Handle plugin, int numParams) {
	char apartmentId[128];
	GetNativeString(1, apartmentId, sizeof(apartmentId));
	int id;
	if ((id = getOwnedApartmentFromKey(apartmentId)) != -1)
		return ownedApartments[id][oaPrice_of_purchase];
	return -1;
}

public bool isOwnedBy(int client, char apartmentId[128]) {
	if (StrEqual(apartmentId, ""))
		return false;
	int aptId;
	if ((aptId = getLoadedIdFromApartmentId(apartmentId)) != -1) {
		int ownedId;
		if ((ownedId = ApartmentIdToOwnedId(aptId)) != -1) {
			char playerid[20];
			GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
			if (StrEqual(ownedApartments[ownedId][oaPlayerid], playerid)) {
				return true;
			}
		}
	}
	return false;
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon, int &tickcount) {
	if (IsClientInGame(client) && IsPlayerAlive(client)) {
		if (!(g_iPlayerPrevButtons[client] & IN_USE) && iButtons & IN_USE) {
			int ent = getClientViewObject(client);
			if (ent == -1) {
				g_iPlayerPrevButtons[client] = iButtons;
				return;
			}
			
			char rZone[64];
			Zone_getMostRecentActiveZone(client, rZone);
			if (Zone_CheckIfZoneExists(activeZone[client], true, true) || Zone_CheckIfZoneExists(rZone, true, true)) {
				if (StrEqual(activeZone[client], "") && !StrEqual(rZone, ""))
					strcopy(activeZone[client], 64, rZone);
				if (HasEntProp(ent, Prop_Data, "m_iName")) {
					char itemName[128];
					//GetEntPropString(ent, Prop_Data, "m_iName", itemName, sizeof(itemName));
					GetEntityClassname(ent, itemName, sizeof(itemName));
					if (StrContains(itemName, "door", false) != -1) {
						doorAction(client, activeZone[client], ent);
					}
				}
				//if (StrContains(activeZone[client], "apartment", false) != -1)
				//	apartmentAction(client);
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
	strcopy(prevZone[client], sizeof(prevZone), activeZone[client]);
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
						if (!jobs_isActiveJob(client, "Police")) {
							if (ownedApartments[ownedId][oaDoor_locked]) {
								// PUSH ZONE - DIABLED
								//Zone_GetZonePosition(zone, false, zone_pos[client]);
								//g_hClientTimers[client] = CreateTimer(0.1, Timer_Repeat, client, TIMER_REPEAT);
								//PrintToChat(client, "You can't enter %s", ownedApartments[ownedId][oaApartmentName]);
							} else {
								PrintToConsole(client, "door unlocked");
							}
						} else {
							PrintToConsole(client, "Police");
						}
					} else {
						PrintToConsole(client, "Owner");
					}
				} else {
					PrintToConsole(client, "has Key");
				}
			}
		}
	}
}

public int Zone_OnClientLeave(int client, char[] zone) {
	float pos[3];
	GetClientAbsOrigin(client, pos);
	if (Zone_isPositionInZone(activeZone[client], pos[0], pos[1], pos[2]))
		return;
	if (Zone_isPositionInZone(prevZone[client], pos[0], pos[1], pos[2])) {
		char tempZone[128];
		strcopy(tempZone, sizeof(tempZone), activeZone[client]);
		strcopy(activeZone[client], 128, prevZone[client]);
		strcopy(prevZone[client], 128, tempZone);
	} else {
		strcopy(prevZone[client], sizeof(prevZone), "");
		strcopy(activeZone[client], sizeof(activeZone), "");
		if (StrContains(zone, "apartment_", false) != -1) {
			if (g_hClientTimers[client] != INVALID_HANDLE)
				KillTimer(g_hClientTimers[client]);
			g_hClientTimers[client] = INVALID_HANDLE;
		}
	}
}

public void doorAction(int client, char zone[128], int doorEnt) {
	if (!apartmentExists(zone))
		return;
	char doorname[64];
	GetEntPropString(doorEnt, Prop_Data, "m_iName", doorname, sizeof(doorname));
	char zone2[128];
	strcopy(zone2, sizeof(zone2), zone);
	ReplaceString(zone2, sizeof(zone2), "apartment_", "");
	ReplaceString(doorname, sizeof(doorname), "apartment_", "");
	
	if (StrContains(doorname, zone2) == -1) {
		char rZone[64];
		Zone_getMostRecentActiveZone(client, rZone);
		float cpos[3];
		GetClientAbsOrigin(client, cpos);
		if (!Zone_isPositionInZone(rZone, cpos[0], cpos[1], cpos[2])) {
			strcopy(rZone, 64, "");
			return;
		}
		strcopy(activeZone[client], 128, rZone);
		PrintToConsole(client, "changed Active Zone to: %s | bug this", rZone);
	}
	
	DataPack overPack = CreateDataPack();
	WritePackCell(overPack, EntIndexToEntRef(client));
	WritePackCell(overPack, EntIndexToEntRef(doorEnt));
	CreateTimer(0.0, makeGlowCb, overPack);
	
	int apartmentId;
	int ownedId;
	if ((apartmentId = getLoadedIdFromApartmentId(zone)) != -1) {
		ownedId = ApartmentIdToOwnedId(apartmentId);
		if (ownedId != -1)
			PrintToChat(client, "Apartment '%s' is owned by %s", ownedApartments[ownedId][oaApartmentName], ownedApartments[ownedId][oaPlayername]);
	}
	bool option = false;
	if (isOwnedBy(client, zone)) {
		option = true;
		apartmentCommand(client, 0);
	}
	if (apartmentId != -1) {
		if (existingApartments[apartmentId][eaBuyable] && !existingApartments[apartmentId][eaBought]) {
			option = true;
			apartmentAction(client);
		}
	}
	
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	if (!option && ownedId != -1) {
		if (StrContains(ownedApartments[ownedId][oaAllowed_players], playerid) != -1) {
			allowedAction(client, zone);
		} else if (jobs_isActiveJob(client, "Police") && jobs_getLevel(client) >= 4) {
			raidAction(client, zone, ownedApartments[ownedId][oaDoor_locked]);
		} else if (ownedApartments[ownedId][oaDoor_locked] && inventory_hasPlayerItem(client, "Lockpick")) {
			lockpickAction(client, zone);
		}
	}
}

public void lockpickAction(int client, char zone[128]) {
	Menu apartmentMenu = CreateMenu(lockpickActionHandler);
	char menuTitle[128];
	Format(menuTitle, sizeof(menuTitle), "Raid Apartment");
	SetMenuTitle(apartmentMenu, menuTitle);
	AddMenuItem(apartmentMenu, "lockpick", "Lockpick Door");
	DisplayMenu(apartmentMenu, client, 60);
	strcopy(playerProperties[client][ppZone], 128, zone);
}

public int lockpickActionHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "lockpick")) {
			jobs_startProgressBar(client, 100, "Lockpicking Apartment");
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void jobs_OnProgressBarFinished(int client, char info[64]) {
	if (StrEqual(info, "Lockpicking Apartment")) {
		if (GetRandomInt(0, 20) == 1) {
			changeDoorLock(client, 0);
			PrintToChat(client, "lockpicked Apartment");
			tCrime_addCrime(client, 300);
		} else {
			PrintToChat(client, "lockpicking failed");
			tCrime_addCrime(client, 75);
		}
		if (GetRandomInt(0, 1) == 1) {
			inventory_removePlayerItems(client, "Lockpick", 1, "Lockpick broke");
			tCrime_addCrime(client, 50);
		}
	}
}

public void allowedAction(int client, char zone[128]) {
	Menu apartmentMenu = CreateMenu(apartmentDoorHandler);
	char menuTitle[128];
	Format(menuTitle, sizeof(menuTitle), "Allowed Player @ Apartment Door");
	SetMenuTitle(apartmentMenu, menuTitle);
	AddMenuItem(apartmentMenu, "lock", "Lock Door");
	AddMenuItem(apartmentMenu, "unlock", "Unlock Door");
	DisplayMenu(apartmentMenu, client, 60);
	strcopy(playerProperties[client][ppZone], 128, zone);
}

public int apartmentDoorHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "lock")) {
			changeDoorLock(client, 1);
			PrintToChat(client, "Locked Doors");
		} else if (StrEqual(cValue, "unlock")) {
			changeDoorLock(client, 0);
			PrintToChat(client, "Unlocked Doors");
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void raidAction(int client, char zone[128], bool locked) {
	Menu apartmentMenu = CreateMenu(apartmentDoorRaidHandler);
	char menuTitle[128];
	Format(menuTitle, sizeof(menuTitle), "Raid Apartment");
	SetMenuTitle(apartmentMenu, menuTitle);
	AddMenuItem(apartmentMenu, "raid", ">> RAID <<", locked ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	AddMenuItem(apartmentMenu, "seal", ">> SEAL <<", locked ? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
	DisplayMenu(apartmentMenu, client, 60);
	strcopy(playerProperties[client][ppZone], 128, zone);
}

public int apartmentDoorRaidHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "raid")) {
			changeDoorLock(client, 0);
			PrintToChat(client, "Raided Apartment");
		} else if (StrEqual(cValue, "seal")) {
			changeDoorLock(client, 1);
			PrintToChat(client, "Sealed Apartment");
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
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
				Format(menuTitle, sizeof(menuTitle), "Apartment: %s", ownedApartments[ownedId][oaApartmentName]);
				SetMenuTitle(apartmentMenu, menuTitle);
				AddMenuItem(apartmentMenu, "rename", "Rename Apartment");
				if (tConomy_getCurrency(client) >= 3000)
					AddMenuItem(apartmentMenu, "revoke", "Change Doorlock (3000)");
				else
					AddMenuItem(apartmentMenu, "revoke", "Change Doorlock (3000)", ITEMDRAW_DISABLED);
				AddMenuItem(apartmentMenu, "lock", "Lock Door");
				AddMenuItem(apartmentMenu, "unlock", "Unlock Door");
				char sellPriceDisplay[128];
				Format(sellPriceDisplay, sizeof(sellPriceDisplay), "Sell Apartment for %.1f", ownedApartments[ownedId][oaPrice_of_purchase] * 0.80);
				AddMenuItem(apartmentMenu, "sell", sellPriceDisplay);
				AddMenuItem(apartmentMenu, "rentInfos", "Rent Informations");
				strcopy(playerProperties[client][ppZone], 128, activeZone[client]);
				DisplayMenu(apartmentMenu, client, 60);
			} else {
				PrintToChat(client, "This Apartment does not belong to you");
			}
		}
	}
	return Plugin_Handled;
}

public int apartmentMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "rename")) {
			playerProperties[client][ppInEdit] = 2;
			PrintToChat(client, "Enter the Apartment Name OR 'abort' to cancel");
			apartmentCommand(client, 0);
		} else if (StrEqual(cValue, "revoke")) {
			revokeAllAccessConfirm(client);
		} else if (StrEqual(cValue, "lock")) {
			changeDoorLock(client, 1);
			PrintToChat(client, "Locked Doors");
			apartmentCommand(client, 0);
		} else if (StrEqual(cValue, "unlock")) {
			changeDoorLock(client, 0);
			PrintToChat(client, "Unlocked Doors");
			apartmentCommand(client, 0);
		} else if (StrEqual(cValue, "sell")) {
			sellApartmentConfirm(client);
		} else if (StrEqual(cValue, "rentInfos")) {
			displayRentInfosToClient(client);
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void displayRentInfosToClient(int client) {
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char getRentInfoQuery[2048];
	Format(getRentInfoQuery, sizeof(getRentInfoQuery), "SELECT startrent,endrent,TIMEDIFF(endrent, CURRENT_TIMESTAMP()) as diff, apartment_id FROM t_rpg_apartments INNER JOIN t_rpg_apartment_rent ON t_rpg_apartment_rent.Id = t_rpg_apartments.Id WHERE apartment_id = '%s' AND t_rpg_apartment_rent.playerid = '%s';", activeZone[client], playerid);
	SQL_TQuery(g_DB, SQLGetRentInfoCallback, getRentInfoQuery, client);
}

public void SQLGetRentInfoCallback(Handle owner, Handle hndl, const char[] error, any data) {
	int client = data;
	if (!isValidClient(client))
		return;
	while (SQL_FetchRow(hndl)) {
		char startTime[40];
		char endTime[40];
		char thediff[40];
		char q_aptId[64];
		SQL_FetchStringByName(hndl, "startrent", startTime, sizeof(startTime));
		SQL_FetchStringByName(hndl, "endrent", endTime, sizeof(endTime));
		SQL_FetchStringByName(hndl, "diff", thediff, sizeof(thediff));
		SQL_FetchStringByName(hndl, "apartment_id", q_aptId, sizeof(q_aptId));
		
		Menu m = CreateMenu(rentMenuHandler);
		char startDisplay[64];
		char endDisplay[64];
		char timediffDisplay[64];
		char q_aptIdDisplay[70];
		Format(q_aptIdDisplay, sizeof(q_aptIdDisplay), "Apartment: %s", q_aptId);
		Format(startDisplay, sizeof(startDisplay), "Rented: %s", startTime);
		Format(endDisplay, sizeof(endDisplay), "End of Rent: %s", endTime);
		Format(timediffDisplay, sizeof(timediffDisplay), "Time left to eviciton: %s", thediff);
		
		char splinters[4][12];
		ExplodeString(thediff, ":", splinters, 4, 12);
		int hoursLeft = StringToInt(splinters[0]);
		
		SetMenuTitle(m, q_aptIdDisplay);
		AddMenuItem(m, "x", startDisplay, ITEMDRAW_DISABLED);
		AddMenuItem(m, "x", endDisplay, ITEMDRAW_DISABLED);
		AddMenuItem(m, "x", timediffDisplay, ITEMDRAW_DISABLED);
		AddMenuItem(m, "increase", "Extend Rent by 7 Days", (hoursLeft < 168 || (isVipRank1(client) && (hoursLeft < 336))) ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
		DisplayMenu(m, client, 30);
	}
}

int increaseRentZoneId[MAXPLAYERS + 1];
public int rentMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "increase")) {
			int zoneId;
			if ((zoneId = getLoadedIdFromApartmentId(activeZone[client])) != -1) {
				int ownedId;
				if ((ownedId = ApartmentIdToOwnedId(zoneId)) != -1) {
					increaseRentZoneId[client] = zoneId;
					char playerid[20];
					GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
					if (StrEqual(ownedApartments[ownedId][oaPlayerid], playerid)) {
						Menu apartmentMenu = CreateMenu(doRentMenuHandler);
						char menuTitle[256];
						Format(menuTitle, sizeof(menuTitle), "Extend Rent of: %s", ownedApartments[ownedId][oaApartmentName]);
						SetMenuTitle(apartmentMenu, menuTitle);
						char extendRentDisplay[70];
						
						int aptPrice = RoundToNearest(existingApartments[zoneId][eaApartment_Price] * 0.1);
						if (isVipRank2(client))
							aptPrice = RoundToNearest(aptPrice / 2.0);
						else if (isVipRank1(client))
							aptPrice = RoundToNearest(aptPrice - (aptPrice / 4.0));
						
						Format(extendRentDisplay, sizeof(extendRentDisplay), "Extend Rent by 7 Days for %i$", aptPrice);
						AddMenuItem(apartmentMenu, "x", "Do nothing");
						AddMenuItem(apartmentMenu, "extendRent", extendRentDisplay, tConomy_getCurrency(client) >= aptPrice ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
						
						DisplayMenu(apartmentMenu, client, 60);
					} else {
						PrintToChat(client, "This Apartment does not belong to you");
					}
				}
			}
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public int doRentMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "extendRent")) {
			int aptPrice = RoundToNearest(existingApartments[increaseRentZoneId[client]][eaApartment_Price] * 0.1);
			if (isVipRank2(client))
				aptPrice = RoundToNearest(aptPrice / 2.0);
			else if (isVipRank1(client))
				aptPrice = RoundToNearest(aptPrice - (aptPrice / 4.0));
			
			if (float(tConomy_getCurrency(client)) >= aptPrice) {
				char takeReason[256];
				Format(takeReason, sizeof(takeReason), "Rented Apartment: %s for 7 more Days", existingApartments[increaseRentZoneId[client]][eaApartment_Id]);
				tConomy_removeCurrency(client, aptPrice, takeReason);
				char updateRentQuery[1024];
				Format(updateRentQuery, sizeof(updateRentQuery), "UPDATE t_rpg_apartment_rent SET endrent = TIMESTAMPADD(DAY,7,endrent) WHERE Id = (SELECT Id FROM t_rpg_apartments WHERE apartment_id = '%s');", existingApartments[increaseRentZoneId[client]][eaApartment_Id]);
				SQL_TQuery(g_DB, SQLErrorCheckCallback, updateRentQuery);
				PrintToChat(client, "Extended %s by 7 Days for %i$", existingApartments[increaseRentZoneId[client]][eaApartment_Id], aptPrice);
				displayRentInfosToClient(client);
			}
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}


public void revokeAllAccessConfirm(int client) {
	Menu m = new Menu(revokeAllAccessConfirmHandler);
	SetMenuTitle(m, "Change doorlocks? (3000$)");
	AddMenuItem(m, "no", "no");
	AddMenuItem(m, "revoke", "Confirm");
	DisplayMenu(m, client, 30);
}

public int revokeAllAccessConfirmHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "revoke")) {
			if (tConomy_getCurrency(client) >= 3000) {
				tConomy_removeCurrency(client, 3000, "Changed Doorlock");
				revokeAllAccess(client);
				PrintToChat(client, "Revoked all Allowed Players");
			}
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void sellApartmentConfirm(int client) {
	Menu m = new Menu(confirmSellMenuHandler);
	SetMenuTitle(m, "Do you realy want to sell your apartment?");
	AddMenuItem(m, "no", "no");
	AddMenuItem(m, "sell", "Confirm");
	DisplayMenu(m, client, 30);
}

public int confirmSellMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "sell")) {
			sellApartment(client);
			PrintToChat(client, "Sold Apartment");
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void apartmentAction(int client) {
	int apartmentId;
	if ((apartmentId = getLoadedIdFromApartmentId(activeZone[client])) != -1) {
		if (existingApartments[apartmentId][eaBuyable] && !existingApartments[apartmentId][eaBought]) {
			char val[8];
			IntToString(apartmentId, val, sizeof(val));
			char tempAdd[64];
			Format(tempAdd, sizeof(tempAdd), "Apartment (%s)", activeZone[client]);
			Menu buyApartmentMenu = CreateMenu(buyApartmentHandler);
			SetMenuTitle(buyApartmentMenu, tempAdd);
			char buyApartmentText[512];
			if (tConomy_getCurrency(client) >= existingApartments[apartmentId][eaApartment_Price] && getOwnedApartments(client) < MAX_OWNED) {
				Format(buyApartmentText, sizeof(buyApartmentText), "Rent Apartment (7 Days) for %i", existingApartments[apartmentId][eaApartment_Price]);
				AddMenuItem(buyApartmentMenu, val, buyApartmentText);
			} else {
				Format(buyApartmentText, sizeof(buyApartmentText), "Rent Apartment (7 Days) for %i (no Money | %i/%i Aps)", existingApartments[apartmentId][eaApartment_Price], getOwnedApartments(client), MAX_OWNED);
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
	//PrintToChat(client, "Selected: %i", apartmentId);
}

public int buyApartmentHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		int apartmentId = StringToInt(cValue);
		buyApartment(client, apartmentId);
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void buyApartment(int client, int id) {
	if (existingApartments[id][eaBuyable] && !existingApartments[id][eaBought]) {
		if (tConomy_getCurrency(client) < existingApartments[id][eaApartment_Price]) {
			PrintToChat(client, "You can not afford this Apartment");
			return;
		}
		tConomy_removeCurrency(client, existingApartments[id][eaApartment_Price], "Bought Apartment");
		existingApartments[id][eaBought] = true;
		
		char mapName[128];
		GetCurrentMap(mapName, sizeof(mapName));
		
		char buyApartmentQuery[512];
		Format(buyApartmentQuery, sizeof(buyApartmentQuery), "UPDATE t_rpg_apartments SET bought = 1 WHERE apartment_id = '%s' AND map = '%s';", existingApartments[id][eaApartment_Id], mapName);
		SQL_TQuery(g_DB, SQLErrorCheckCallback, buyApartmentQuery);
		
		char playerid[20];
		GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
		
		char playername[MAX_NAME_LENGTH + 8];
		GetClientName(client, playername, sizeof(playername));
		
		char clean_playername[MAX_NAME_LENGTH * 2 + 16];
		SQL_EscapeString(g_DB, playername, clean_playername, sizeof(clean_playername));
		
		char apartment_name[255];
		Format(apartment_name, sizeof(apartment_name), "%ss Apartment", clean_playername);
		
		Format(buyApartmentQuery, sizeof(buyApartmentQuery), "INSERT IGNORE INTO `t_rpg_boughtApartments` (`Id`, `time_of_purchase`, `price_of_purchase`, `apartment_id`, `playerid`, `playername`, `apartment_name`, `allowed_players`, `door_locked`, `map`) VALUES (NULL, CURRENT_TIMESTAMP, '%i', '%s', '%s', '%s', '%s', '', '0', '%s');", existingApartments[id][eaApartment_Price], existingApartments[id][eaApartment_Id], playerid, clean_playername, apartment_name, mapName);
		SQL_TQuery(g_DB, SQLErrorCheckCallback, buyApartmentQuery);
		
		Format(buyApartmentQuery, sizeof(buyApartmentQuery), "INSERT INTO `t_rpg_apartment_rent` SELECT NULL, Id, '%s', CURRENT_TIMESTAMP, TIMESTAMPADD(Day,7,CURRENT_TIMESTAMP) FROM t_rpg_apartments WHERE apartment_id = '%s';", playerid, existingApartments[id][eaApartment_Id]);
		SQL_TQuery(g_DB, SQLErrorCheckCallback, buyApartmentQuery);
		
		int firstFree = getFirstFreeOwnedApartmentSlot();
		char time[32];
		IntToString(GetTime(), time, sizeof(time));
		ownedApartments[firstFree][oaId] = firstFree;
		strcopy(ownedApartments[firstFree][oaTime_of_purchase], 64, time);
		ownedApartments[firstFree][oaPrice_of_purchase] = existingApartments[id][eaApartment_Price];
		strcopy(ownedApartments[firstFree][oaApartment_Id], 128, existingApartments[id][eaApartment_Id]);
		strcopy(ownedApartments[firstFree][oaPlayerid], 20, playerid);
		strcopy(ownedApartments[firstFree][oaPlayername], 48, playername);
		strcopy(ownedApartments[firstFree][oaApartmentName], 255, apartment_name);
		strcopy(ownedApartments[firstFree][oaAllowed_players], 550, "");
		ownedApartments[firstFree][oaDoor_locked] = false;
		
		if (firstFree > g_iOwnedApartmentsCount)
			g_iOwnedApartmentsCount = firstFree;
		
		PrintToConsole(client, "Assigned %i of %i", firstFree, id);
	}
}

public Action createApartmentCallback(int client, int args) {
	Menu createApartmentMenu = CreateMenu(createApartmentHandler);
	char addApartment[128];
	SetMenuTitle(createApartmentMenu, "Apartment Admin");
	Format(addApartment, sizeof(addApartment), "Create Apartment( %s )", activeZone[client]);
	if (apartmentExists(activeZone[client]) || StrContains(activeZone[client], "apartment_") == -1)
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
		Format(editApartment, sizeof(editApartment), "Edit Apartment( %s )", activeZone[client]);
	else
		Format(editApartment, sizeof(editApartment), "Edit Apartment( %s )", activeZone[client], ITEMDRAW_DISABLED);
	AddMenuItem(createApartmentMenu, "editThis", editApartment);
	AddMenuItem(createApartmentMenu, "delete", "Delete another Apartment");
	AddMenuItem(createApartmentMenu, "edit", "Edit another Apartment - TODO");
	DisplayMenu(createApartmentMenu, client, 30);
	strcopy(playerProperties[client][ppZone], 128, activeZone[client]);
	return Plugin_Handled;
}

public int createApartmentHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "addThis")) {
			playerProperties[client][ppInEdit] = 1;
			PrintToChat(client, "Enter the Apartment Price OR 'abort' to cancel");
		} else if (StrEqual(cValue, "deleteThis")) {
			deleteApartment(playerProperties[client][ppZone]);
			strcopy(playerProperties[client][ppZone], 128, "");
		} else if (StrEqual(cValue, "editThis")) {
			openEditApartment(client, playerProperties[client][ppZone]);
		} else if (StrEqual(cValue, "delete")) {
			loadMenuForDeletion(client);
		} else if (StrEqual(cValue, "edit")) {
			// TODO
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void openEditApartment(int client, char[] apartmentid) {
	Menu editApartment = CreateMenu(editApartmentMenuHandler);
	char editApartmentTitle[128];
	Format(editApartmentTitle, sizeof(editApartmentTitle), "Edit: %s", apartmentid);
	SetMenuTitle(editApartment, editApartmentTitle);
	AddMenuItem(editApartment, "editPrice", "Change Price");
	AddMenuItem(editApartment, "toggleBuyable", "Toggle Buyable");
	AddMenuItem(editApartment, "setFlags", "Set Flags");
	DisplayMenu(editApartment, client, 60);
}

public int editApartmentMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "editPrice")) {
			playerProperties[client][ppInEdit] = 3;
			PrintToChat(client, "Enter the new Apartment Price OR 'abort' to cancel");
		} else if (StrEqual(cValue, "toggleBuyable")) {
			toggleBuyable(client, playerProperties[client][ppZone]);
		} else if (StrEqual(cValue, "setFlags")) {
			playerProperties[client][ppInEdit] = 4;
			PrintToChat(client, "Enter the new Apartment Flags OR 'abort' to cancel");
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void toggleBuyable(int client, char[] apartmentid) {
	int apartmentId;
	if ((apartmentId = getLoadedIdFromApartmentId(apartmentid)) == -1)
		return;
	existingApartments[apartmentId][eaBuyable] = !existingApartments[apartmentId][eaBuyable];
	
	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	
	char updateBuyableQuery[1024];
	Format(updateBuyableQuery, sizeof(updateBuyableQuery), "UPDATE t_rpg_apartments SET buyable = %i WHERE apartment_id = '%s' AND map = '%s';", existingApartments[apartmentId][eaBuyable], apartmentid, mapName);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateBuyableQuery);
	PrintToChat(client, "Changed buyable of %s to %d", apartmentid, existingApartments[apartmentId][eaBuyable]);
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
		
		char cValue[128];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		deleteApartment(cValue);
		
		loadMenuForDeletion(client);
	}
	if (action == MenuAction_End) {
		delete menu;
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
		strcopy(playerProperties[client][ppZone], 128, "");
		return Plugin_Handled;
	} else if (playerProperties[client][ppInEdit] == 2 && StrContains(text, "abort") == -1) {
		PrintToChat(client, "Renamed: %s to: %s", playerProperties[client][ppZone], text);
		
		char clean_apartment_name[128];
		SQL_EscapeString(g_DB, text, clean_apartment_name, sizeof(clean_apartment_name));
		
		char mapName[128];
		GetCurrentMap(mapName, sizeof(mapName));
		
		char updateNameQuery[1024];
		Format(updateNameQuery, sizeof(updateNameQuery), "UPDATE t_rpg_boughtApartments SET apartment_name = '%s' WHERE apartment_id = '%s' AND map = '%s';", clean_apartment_name, playerProperties[client][ppZone], mapName);
		SQL_TQuery(g_DB, SQLErrorCheckCallback, updateNameQuery);
		
		strcopy(ownedApartments[getOwnedApartmentFromKey(playerProperties[client][ppZone])][oaApartmentName], 128, clean_apartment_name);
		playerProperties[client][ppInEdit] = -1;
		strcopy(playerProperties[client][ppZone], 128, "");
		
		return Plugin_Handled;
	} else if (playerProperties[client][ppInEdit] == 3 && StrContains(text, "abort") == -1) {
		changeApartmentPrice(playerProperties[client][ppZone], StringToInt(text));
		PrintToChat(client, "Changed Price of: %s to %i", playerProperties[client][ppZone], StringToInt(text));
		playerProperties[client][ppInEdit] = -1;
		strcopy(playerProperties[client][ppZone], 128, "");
		return Plugin_Handled;
	} else if (playerProperties[client][ppInEdit] == 4 && StrContains(text, "abort") == -1) {
		char rFlags[8];
		strcopy(rFlags, sizeof(rFlags), text);
		changeApartmentFlags(playerProperties[client][ppZone], rFlags);
		PrintToChat(client, "Changed Flags of: %s to %s (max 8 length)", playerProperties[client][ppZone], rFlags);
		playerProperties[client][ppInEdit] = -1;
		strcopy(playerProperties[client][ppZone], 128, "");
		return Plugin_Handled;
	} else if (playerProperties[client][ppInEdit] > 0 && StrContains(text, "abort") != -1) {
		PrintToChat(client, "Aborted [%i]", playerProperties[client][ppInEdit]);
		playerProperties[client][ppInEdit] = -1;
		strcopy(playerProperties[client][ppZone], 128, "");
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public void changeApartmentFlags(char[] apartmentid, char flags[8]) {
	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	
	char createApartmentQuery[4096];
	Format(createApartmentQuery, sizeof(createApartmentQuery), "UPDATE t_rpg_apartments SET flag = '%s' WHERE apartment_id = '%s' AND map = '%s';", flags, apartmentid, mapName);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createApartmentQuery);
	
	int apartmentId;
	if ((apartmentId = getLoadedIdFromApartmentId(apartmentid)) == -1)
		return;
	strcopy(existingApartments[apartmentId][eaFlag], 8, flags);
}

public void changeApartmentPrice(char[] apartmentid, int price) {
	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	
	char createApartmentQuery[4096];
	Format(createApartmentQuery, sizeof(createApartmentQuery), "UPDATE t_rpg_apartments SET apartment_price = %i WHERE apartment_id = '%s' AND map = '%s';", price, apartmentid, mapName);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createApartmentQuery);
	
	int apartmentId;
	if ((apartmentId = getLoadedIdFromApartmentId(apartmentid)) == -1)
		return;
	existingApartments[apartmentId][eaApartment_Price] = price;
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
	
	int aptId;
	if ((aptId = getOwnedApartmentFromKey(apartmentId)) != -1) {
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
	
	int eId;
	if ((eId = getLoadedIdFromApartmentId(apartmentId)) != -1) {
		existingApartments[eId][eaId] = -1;
		strcopy(existingApartments[eId][eaApartment_Id], 128, "");
		existingApartments[eId][eaApartment_Price] = -1;
		existingApartments[eId][eaBuyable] = false;
		strcopy(existingApartments[eId][eaFlag], 8, "");
		existingApartments[eId][eaBought] = false;
	}
	
}

public void loadApartments() {
	resetAps();
	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	
	char loadApartmentsQuery[2048];
	Format(loadApartmentsQuery, sizeof(loadApartmentsQuery), "SELECT apartment_id,apartment_price,buyable,flag,bought FROM t_rpg_apartments WHERE map = '%s';", mapName);
	SQL_TQuery(g_DB, SQLLoadApartmentsQueryCallback, loadApartmentsQuery);
	
	char loadOwnedApartments[2048];
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
		int slot = getFirstFreeOwnedApartmentSlot();
		ownedApartments[slot][oaId] = slot;
		SQL_FetchStringByName(hndl, "time_of_purchase", ownedApartments[slot][oaTime_of_purchase], 64);
		ownedApartments[slot][oaPrice_of_purchase] = SQL_FetchIntByName(hndl, "price_of_purchase");
		SQL_FetchStringByName(hndl, "apartment_id", ownedApartments[slot][oaApartment_Id], 128);
		SQL_FetchStringByName(hndl, "playerid", ownedApartments[slot][oaPlayerid], 20);
		SQL_FetchStringByName(hndl, "playername", ownedApartments[slot][oaPlayername], 48);
		SQL_FetchStringByName(hndl, "apartment_name", ownedApartments[slot][oaApartmentName], 255);
		SQL_FetchStringByName(hndl, "allowed_players", ownedApartments[slot][oaAllowed_players], 550);
		ownedApartments[slot][oaDoor_locked] = SQL_FetchBoolByName(hndl, "door_locked");
		
		
		char aptName[128];
		strcopy(aptName, sizeof(aptName), ownedApartments[slot][oaApartment_Id]);
		ReplaceString(aptName, sizeof(aptName), "apartment_", "", false);
		int entity = -1;
		while ((entity = FindEntityByClassname(entity, "prop_door_rotating")) != INVALID_ENT_REFERENCE) {
			char uniqueId[64];
			GetEntPropString(entity, Prop_Data, "m_iName", uniqueId, sizeof(uniqueId));
			if (StrEqual(aptName, uniqueId)) {
				if (ownedApartments[slot][oaDoor_locked])
					AcceptEntityInput(entity, "lock", -1);
				else
					AcceptEntityInput(entity, "unlock", -1);
			}
		}
		entity = -1;
		while ((entity = FindEntityByClassname(entity, "func_door")) != INVALID_ENT_REFERENCE) {
			char uniqueId[64];
			GetEntPropString(entity, Prop_Data, "m_iName", uniqueId, sizeof(uniqueId));
			if (StrEqual(aptName, uniqueId)) {
				if (ownedApartments[slot][oaDoor_locked])
					AcceptEntityInput(entity, "lock", -1);
				else
					AcceptEntityInput(entity, "unlock", -1);
			}
		}
		if (slot == g_iOwnedApartmentsCount)
			g_iOwnedApartmentsCount++;
	}
}

public int getLoadedIdFromApartmentId(char[] apartmentId) {
	for (int i = 0; i < MAX_APARTMENTS; i++) {
		if (StrEqual(existingApartments[i][eaApartment_Id], apartmentId))
			return i;
	}
	return -1;
}

public int ApartmentIdToOwnedId(int apartmentKey) {
	for (int x = 0; x < MAX_APARTMENTS; x++) {
		if (StrEqual(existingApartments[apartmentKey][eaApartment_Id], ownedApartments[x][oaApartment_Id]))
			return x;
	}
	return -1;
}

public int getFirstFreeOwnedApartmentSlot() {
	for (int i = 0; i < MAX_APARTMENTS; i++)
	if (ownedApartments[i][oaId] == -1)
		return i;
	return -1;
}

public int getFirstFreeApartmentSlot() {
	for (int i = 0; i < MAX_APARTMENTS; i++)
	if (existingApartments[i][eaId] == -1)
		return i;
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
	char checkSum[128];
	strcopy(checkSum, sizeof(checkSum), playerProperties[client][ppZone]);
	
	if (StrEqual(checkSum, ""))
		return;
	
	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	
	char updateDoorLockQuery[1024];
	Format(updateDoorLockQuery, sizeof(updateDoorLockQuery), "UPDATE t_rpg_boughtApartments SET door_locked = %i WHERE apartment_id = '%s' AND map = '%s';", state, playerProperties[client][ppZone], mapName);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateDoorLockQuery);
	int aptId = getOwnedApartmentFromKey(playerProperties[client][ppZone]);
	ownedApartments[aptId][oaDoor_locked] = state == 1;
	PrintToConsole(client, "%i %s %s %i > %s", state, playerProperties[client][ppZone], mapName, aptId, checkSum);
	
	char aptName[64];
	strcopy(aptName, sizeof(aptName), playerProperties[client][ppZone]);
	
	strcopy(playerProperties[client][ppZone], 128, "");
	
	
	ReplaceString(aptName, sizeof(aptName), "apartment_", "", false);
	//PrintToChat(client, ">>%s<<", aptName);
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "prop_door_rotating")) != INVALID_ENT_REFERENCE) {
		char uniqueId[64];
		GetEntPropString(entity, Prop_Data, "m_iName", uniqueId, sizeof(uniqueId));
		if (StrContains(uniqueId, aptName) != -1) {
			if (state)
				AcceptEntityInput(entity, "lock", -1);
			else
				AcceptEntityInput(entity, "unlock", -1);
			PrintToConsole(client, "t1: |%s| |%s| to %i", uniqueId, aptName, state);
		}
	}
	entity = -1;
	while ((entity = FindEntityByClassname(entity, "func_door")) != INVALID_ENT_REFERENCE) {
		char uniqueId[64];
		GetEntPropString(entity, Prop_Data, "m_iName", uniqueId, sizeof(uniqueId));
		if (StrContains(uniqueId, aptName) != -1) {
			if (state)
				AcceptEntityInput(entity, "lock", -1);
			else
				AcceptEntityInput(entity, "unlock", -1);
			PrintToConsole(client, "t2: |%s| |%s| to %i", uniqueId, aptName, state);
		}
	}
}

public void sellApartment(int client) {
	char zone[128];
	strcopy(zone, sizeof(zone), playerProperties[client][ppZone]);
	if (!isOwnedBy(client, zone)) {
		PrintToChat(client, "[-T-] You actually do not own this apartment... try again");
		return;
	}
	int aptId = getOwnedApartmentFromKey(playerProperties[client][ppZone]);
	int sellPrice = RoundToNearest(ownedApartments[aptId][oaPrice_of_purchase] * 0.70);
	char reason[256];
	Format(reason, sizeof(reason), "Sold Apartment %s", zone);
	tConomy_addCurrency(client, sellPrice, reason);
	
	changeDoorLock(client, 0);
	
	evictApartment(zone);
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

public int getOwnedApartments(int client) {
	int owned = 0;
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	for (int i = 0; i < MAX_APARTMENTS; i++) {
		if (StrEqual(playerid, ownedApartments[i][oaPlayerid]))
			owned++;
	}
	return owned;
}

int g_iPlayerTargetKey[MAXPLAYERS + 1];
public void allowPlayerToApartmentChooser(int owner, int target) {
	g_iPlayerTargetKey[owner] = target;
	Menu chooserMenu = CreateMenu(chooserMenuHandler);
	SetMenuTitle(chooserMenu, "Choose the Apartment");
	char playerid[20];
	GetClientAuthId(owner, AuthId_Steam2, playerid, sizeof(playerid));
	for (int i = 0; i < MAX_APARTMENTS; i++) {
		if (StrEqual(playerid, ownedApartments[i][oaPlayerid]))
			AddMenuItem(chooserMenu, ownedApartments[i][oaApartment_Id], ownedApartments[i][oaApartmentName]);
	}
	
	DisplayMenu(chooserMenu, owner, 60);
}

public int chooserMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[128];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (inventory_removePlayerItems(client, "Apartment Key", 1, "Allowed Players to Apartment"))
			allowPlayerToApartment(client, g_iPlayerTargetKey[client], cValue);
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public bool allowPlayerToApartment(int owner, int target, char apartmentId[128]) {
	int aptId;
	if ((aptId = getLoadedIdFromApartmentId(apartmentId)) != -1) {
		int ownedId;
		if ((ownedId = ApartmentIdToOwnedId(aptId)) != -1) {
			char ownerId[20];
			GetClientAuthId(owner, AuthId_Steam2, ownerId, sizeof(ownerId));
			
			if (StrEqual(ownedApartments[ownedId][oaPlayerid], ownerId)) {
				char playerid[20];
				GetClientAuthId(target, AuthId_Steam2, playerid, sizeof(playerid));
				
				if (StrEqual(ownedApartments[ownedId][oaAllowed_players], ""))
					Format(ownedApartments[ownedId][oaAllowed_players], 550, "%s", playerid);
				else
					Format(ownedApartments[ownedId][oaAllowed_players], 550, "%s %s", ownedApartments[ownedId][oaAllowed_players], playerid);
				
				PrintToChat(target, "You've been granted access to %s by %N", apartmentId, owner);
				PrintToChat(owner, "You gave %N access to %s", target, apartmentId);
				updateAccess(apartmentId, ownedId);
				return true;
			}
		}
	}
	return false;
}

public void updateAccess(char apartmentId[128], int id) {
	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	
	char updateAllowedQuery[1024];
	Format(updateAllowedQuery, sizeof(updateAllowedQuery), "UPDATE t_rpg_boughtApartments SET allowed_players = '%s' WHERE apartment_id = '%s' AND map = '%s';", ownedApartments[id][oaAllowed_players], apartmentId, mapName);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateAllowedQuery);
}

public void KnockbackSetVelocity(int client, const float startpoint[3], const float endpoint[3], float magnitude) {
	float vector[3];
	MakeVectorFromPoints(startpoint, endpoint, vector);
	NormalizeVector(vector, vector);
	ScaleVector(vector, magnitude);
	
	
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vector);
}

public void onRoundStart(Handle event, const char[] name, bool dontBroadcast) {
	setDoorLocks();
	for (int i = 0; i < 4096; i++)
	g_iActiveGlows[i] = false;
}

public void setDoorLocks() {
	for (int i = 0; i < g_iOwnedApartmentsCount; i++) {
		char aptName[128];
		strcopy(aptName, sizeof(aptName), ownedApartments[i][oaApartment_Id]);
		//PrintToChatAll("<<<<%s ", aptName);
		ReplaceString(aptName, sizeof(aptName), "apartment_", "", false);
		int entity = -1;
		//PrintToChatAll(">>>%s ", aptName);
		while ((entity = FindEntityByClassname(entity, "prop_door_rotating")) != INVALID_ENT_REFERENCE) {
			char uniqueId[64];
			GetEntPropString(entity, Prop_Data, "m_iName", uniqueId, sizeof(uniqueId));
			if (StrContains(uniqueId, aptName) != -1) {
				//PrintToChatAll("%i]: %d %s %i", i, ownedApartments[i][oaDoor_locked], uniqueId, entity);
				if (ownedApartments[i][oaDoor_locked]) {
					AcceptEntityInput(entity, "lock", -1);
					//PrintToChatAll("Used 'lock' ON %i (%s)", entity, uniqueId);
				} else
					AcceptEntityInput(entity, "unlock", -1);
			}
		}
		entity = -1;
		while ((entity = FindEntityByClassname(entity, "func_door")) != INVALID_ENT_REFERENCE) {
			char uniqueId[64];
			GetEntPropString(entity, Prop_Data, "m_iName", uniqueId, sizeof(uniqueId));
			if (StrContains(uniqueId, aptName) != -1) {
				if (ownedApartments[i][oaDoor_locked])
					AcceptEntityInput(entity, "lock", -1);
				else
					AcceptEntityInput(entity, "unlock", -1);
			}
		}
	}
}

public Action evictTimer(Handle Timer) {
	char findToEvict[1024];
	Format(findToEvict, sizeof(findToEvict), "SELECT apartment_id FROM t_rpg_apartments INNER JOIN t_rpg_apartment_rent ON t_rpg_apartment_rent.Id = t_rpg_apartments.Id WHERE endrent < CURRENT_TIMESTAMP();");
	SQL_TQuery(g_DB, SQLFindToEvictApartments, findToEvict);
}

public void SQLFindToEvictApartments(Handle owner, Handle hndl, const char[] error, any data) {
	while (SQL_FetchRow(hndl)) {
		char evictapartmentId[128];
		SQL_FetchStringByName(hndl, "apartment_id", evictapartmentId, sizeof(evictapartmentId));
		evictApartment(evictapartmentId);
	}
}

public void evictApartment(char apartmentId[128]) {
	int aptId = getOwnedApartmentFromKey(apartmentId);
	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	
	char sellApartmentQuery[4096];
	Format(sellApartmentQuery, sizeof(sellApartmentQuery), "DELETE FROM `t_rpg_boughtApartments` WHERE apartment_id = '%s' AND map = '%s';", apartmentId, mapName);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, sellApartmentQuery);
	
	Format(sellApartmentQuery, sizeof(sellApartmentQuery), "UPDATE `t_rpg_apartments` SET bought = 0 WHERE apartment_id = '%s' AND map = '%s';", apartmentId, mapName);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, sellApartmentQuery);
	
	Format(sellApartmentQuery, sizeof(sellApartmentQuery), "DELETE FROM `t_rpg_apartment_rent` WHERE Id = (SELECT Id from t_rpg_apartments WHERE apartment_id = '%s');", apartmentId);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, sellApartmentQuery);
	
	existingApartments[getLoadedIdFromApartmentId(ownedApartments[aptId][oaApartment_Id])][eaBuyable] = true;
	existingApartments[getLoadedIdFromApartmentId(ownedApartments[aptId][oaApartment_Id])][eaBought] = false;
	
	ownedApartments[aptId][oaId] = -1;
	strcopy(ownedApartments[aptId][oaTime_of_purchase], 64, "");
	ownedApartments[aptId][oaPrice_of_purchase] = -1;
	strcopy(ownedApartments[aptId][oaApartment_Id], 128, "");
	strcopy(ownedApartments[aptId][oaPlayerid], 20, "");
	strcopy(ownedApartments[aptId][oaPlayername], 48, "");
	strcopy(ownedApartments[aptId][oaApartmentName], 255, "");
	strcopy(ownedApartments[aptId][oaAllowed_players], 550, "");
	ownedApartments[aptId][oaDoor_locked] = false;
	furniture_removeAllFurnitureFromApartment(apartmentId);
}

public Action listAps(int client, int args) {
	for (int i = 0; i < g_iLoadedApartments; i++) {
		PrintToConsole(client, "Id: %i time: %s price: %i id2: %i playerid: %s name: %s aptname: %s |l: %d", ownedApartments[i][oaId], ownedApartments[i][oaTime_of_purchase], ownedApartments[i][oaPrice_of_purchase], ownedApartments[i][oaApartment_Id], ownedApartments[i][oaPlayerid], ownedApartments[i][oaPlayername], ownedApartments[i][oaApartmentName], ownedApartments[i][oaDoor_locked]);
	}
	for (int i = 0; i < g_iOwnedApartmentsCount; i++) {
		char aptName[128];
		strcopy(aptName, sizeof(aptName), ownedApartments[i][oaApartment_Id]);
		ReplaceString(aptName, sizeof(aptName), "apartment_", "", false);
		int entity = -1;
		while ((entity = FindEntityByClassname(entity, "prop_door_rotating")) != INVALID_ENT_REFERENCE) {
			char uniqueId[64];
			GetEntPropString(entity, Prop_Data, "m_iName", uniqueId, sizeof(uniqueId));
			if (StrContains(aptName, uniqueId) != -1) {
				if (ownedApartments[i][oaDoor_locked])
					AcceptEntityInput(entity, "lock", -1);
				else
					AcceptEntityInput(entity, "unlock", -1);
			}
		}
		entity = -1;
		while ((entity = FindEntityByClassname(entity, "func_door")) != INVALID_ENT_REFERENCE) {
			char uniqueId[64];
			GetEntPropString(entity, Prop_Data, "m_iName", uniqueId, sizeof(uniqueId));
			if (StrContains(aptName, uniqueId) != -1) {
				if (ownedApartments[i][oaDoor_locked])
					AcceptEntityInput(entity, "lock", -1);
				else
					AcceptEntityInput(entity, "unlock", -1);
			}
		}
	}
	return Plugin_Handled;
}

int g_iClientGlow[MAXPLAYERS + 1];
public Action makeGlowCb(Handle Timer, any datapack) {
	ResetPack(datapack, false);
	int client = EntRefToEntIndex(ReadPackCell(datapack));
	int entity = EntRefToEntIndex(ReadPackCell(datapack));
	CloseHandle(datapack);
	if (!IsValidEntity(entity))
		return;
	char className[64];
	GetEntityClassname(entity, className, sizeof(className));
	if (!StrEqual(className, "prop_door_rotating"))
		return;
	char m_ModelName[PLATFORM_MAX_PATH];
	GetEntPropString(entity, Prop_Data, "m_ModelName", m_ModelName, sizeof(m_ModelName));
	//PrintToChatAll("%s <| s", m_ModelName);
	float fPos[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fPos);
	if (fPos[0] == 0.0 || g_iActiveGlows[entity])
		return;
	float fAngles[3];
	GetEntPropVector(entity, Prop_Send, "m_angRotation", fAngles);
	int doorGlow = CreateEntityByName("prop_dynamic_glow");
	DispatchKeyValue(doorGlow, "model", m_ModelName);
	DispatchKeyValue(doorGlow, "disablereceiveshadows", "1");
	DispatchKeyValue(doorGlow, "disableshadows", "1");
	DispatchKeyValue(doorGlow, "solid", "0");
	DispatchKeyValue(doorGlow, "spawnflags", "256");
	SetEntProp(doorGlow, Prop_Send, "m_CollisionGroup", 11);
	DispatchSpawn(doorGlow);
	SetEntPropFloat(doorGlow, Prop_Send, "m_flModelScale", 1.0);
	TeleportEntity(doorGlow, fPos, fAngles, NULL_VECTOR);
	SetEntProp(doorGlow, Prop_Send, "m_bShouldGlow", true, true);
	SetEntPropFloat(doorGlow, Prop_Send, "m_flGlowMaxDist", 15000.0);
	SetGlowColor(doorGlow, "111 0 255");
	AcceptEntityInput(doorGlow, "SetGlowColor");
	SetEntPropFloat(doorGlow, Prop_Send, "m_flModelScale", 1.0);
	SetVariantString("!activator");
	AcceptEntityInput(doorGlow, "SetParent", entity);
	SDKHook(doorGlow, SDKHook_SetTransmit, Hook_SetTransmit);
	g_iClientGlow[client] = EntIndexToEntRef(doorGlow);
	DataPack overPack = CreateDataPack();
	WritePackCell(overPack, EntIndexToEntRef(doorGlow));
	WritePackCell(overPack, EntIndexToEntRef(entity));
	CreateTimer(2.5, killGlow, overPack);
	g_iActiveGlows[entity] = true;
}

public Action Hook_SetTransmit(int ent, int client) {
	if (ent != EntRefToEntIndex(g_iClientGlow[client]))
		return Plugin_Handled;
	return Plugin_Continue;
}

public Action killGlow(Handle Timer, any datapack) {
	ResetPack(datapack, false);
	int glow = EntRefToEntIndex(ReadPackCell(datapack));
	int entity = EntRefToEntIndex(ReadPackCell(datapack));
	CloseHandle(datapack);
	if (IsValidEntity(glow)) {
		SDKUnhook(glow, SDKHook_SetTransmit, Hook_SetTransmit);
		AcceptEntityInput(glow, "kill");
		g_iActiveGlows[entity] = false;
	}
}

stock void SetGlowColor(int entity, const char[] color)
{
	char colorbuffers[3][4];
	ExplodeString(color, " ", colorbuffers, sizeof(colorbuffers), sizeof(colorbuffers[]));
	int colors[4];
	for (int i = 0; i < 3; i++)
	colors[i] = StringToInt(colorbuffers[i]);
	colors[3] = 255;
	SetVariantColor(colors);
	AcceptEntityInput(entity, "SetGlowColor");
} 