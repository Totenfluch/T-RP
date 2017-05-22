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
#define PLUGIN_VERSION "1.2"

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <autoexecconfig>

#pragma newdecls required

char dbconfig[] = "gsxh_multiroot";
Database g_DB;

/*
	https://wiki.alliedmods.net/Checking_Admin_Flags_(SourceMod_Scripting)
	19 -> Custom5
	20 -> Custom6
*/

Handle g_hTestPoliceDuration;
int g_iTestPoliceDuration;

Handle g_hFlag;
int g_iFlags[20];
int g_iFlagCount = 0;


bool g_bIspolice[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[T-RP] tPolice Whitelist", 
	author = PLUGIN_AUTHOR, 
	description = "police functionality for the GGC", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart() {
	char error[255];
	g_DB = SQL_Connect(dbconfig, true, error, sizeof(error));
	SQL_SetCharset(g_DB, "utf8");
	
	char createTableQuery[4096];
	Format(createTableQuery, sizeof(createTableQuery), 
		"CREATE TABLE IF NOT EXISTS tPolice (`Id`BIGINT NOT NULL AUTO_INCREMENT, `timestamp`TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,\
	`playername`VARCHAR(36)CHARACTER SET utf8 COLLATE utf8_bin NOT NULL, `playerid`VARCHAR(20)NOT NULL, `enddate`TIMESTAMP NOT NULL,\
	`admin_playername`VARCHAR(36)CHARACTER SET utf8 COLLATE utf8_bin NOT NULL, `admin_playerid`VARCHAR(20)NOT NULL, PRIMARY KEY(`Id`))\
	ENGINE = InnoDB CHARSET = utf8 COLLATE utf8_bin; ");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createTableQuery);
	
	
	AutoExecConfig_SetFile("tPolice");
	AutoExecConfig_SetCreateFile(true);
	
	g_hFlag = AutoExecConfig_CreateConVar("tPolice_flag", "19", "20=Custom6, 19=Custom5 etc. Numeric Flag See: 'https://wiki.alliedmods.net/Checking_Admin_Flags_(SourceMod_Scripting)' for Definitions ---- Multiple flags seperated with Space: '16 17 18 19' !!");
	g_hTestPoliceDuration = AutoExecConfig_CreateConVar("tPolice_testPoliceDuration", "15", "Test police duration in minutes");
	
	AutoExecConfig_CleanFile();
	AutoExecConfig_ExecuteFile();
	
	RegAdminCmd("sm_tpolice", cmdtPolice, ADMFLAG_ROOT, "Opens the tPolice menu");
	RegAdminCmd("sm_addpolice", cmdAddpolice, ADMFLAG_ROOT, "Adds a police Usage: sm_addpolice \"<SteamID>\" <Duration in Month> \"<Name>\"");
	RegConsoleCmd("sm_policeofficers", cmdListPolices, "Shows all Police Officer");
	RegConsoleCmd("sm_police", openpolicePanel, "Opens the police Menu");
}

public void OnConfigsExecuted() {
	g_iFlagCount = 0;
	g_iTestPoliceDuration = GetConVarInt(g_hTestPoliceDuration);
	char cFlags[256];
	GetConVarString(g_hFlag, cFlags, sizeof(cFlags));
	char cSplinters[20][6];
	for (int i = 0; i < 20; i++)
	strcopy(cSplinters[i], 6, "");
	ExplodeString(cFlags, " ", cSplinters, 20, 6);
	for (int i = 0; i < 20; i++) {
		if (StrEqual(cSplinters[i], ""))
			break;
		g_iFlags[g_iFlagCount++] = StringToInt(cSplinters[i]);
	}
}

public Action openpolicePanel(int client, int args) {
	if (g_bIspolice[client]) {
		char playerid[20];
		GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
		
		char getDatesQuery[1024];
		Format(getDatesQuery, sizeof(getDatesQuery), "SELECT timestamp,enddate,DATEDIFF(enddate, NOW()) as timeleft FROM tPolice WHERE playerid = '%s';", playerid);
		
		SQL_TQuery(g_DB, getDatesQueryCallback, getDatesQuery, client);
	}
	return Plugin_Handled;
	
}

public void getDatesQueryCallback(Handle owner, Handle hndl, const char[] error, any data) {
	int client = data;
	char ends[128];
	char started[128];
	char left[64];
	while (SQL_FetchRow(hndl)) {
		SQL_FetchString(hndl, 0, started, sizeof(started));
		SQL_FetchString(hndl, 1, ends, sizeof(ends));
		SQL_FetchString(hndl, 2, left, sizeof(left));
	}
	
	Menu policePanelMenu = CreateMenu(policePanelMenuHandler);
	char m_started[256];
	char m_ends[256];
	Format(m_started, sizeof(m_started), "Started: %s", started);
	Format(m_ends, sizeof(m_ends), "Ends: %s (%s Days)", ends, left);
	SetMenuTitle(policePanelMenu, "police Panel");
	AddMenuItem(policePanelMenu, "x", m_started, ITEMDRAW_DISABLED);
	AddMenuItem(policePanelMenu, "x", m_ends, ITEMDRAW_DISABLED);
	DisplayMenu(policePanelMenu, client, 60);
}

public int policePanelMenuHandler(Handle menu, MenuAction action, int client, int item) {
	char cValue[32];
	GetMenuItem(menu, item, cValue, sizeof(cValue));
	if (action == MenuAction_Select) {
		// TODO ?
	}
	if (action == MenuAction_End) { 
    	delete menu; 
	}
}

public Action cmdAddpolice(int client, int args) {
	if (args != 3) {
		CPrintToChat(client, "{olive}[-T-] {lightred}Invalid Params Usage: sm_addpolice \"<SteamID>\" <Duration in Month> \"<Name>\"");
		return Plugin_Handled;
	}
	
	char input[22];
	GetCmdArg(1, input, sizeof(input));
	char duration[8];
	GetCmdArg(2, duration, sizeof(duration));
	int d1 = StringToInt(duration);
	StripQuotes(input);
	char input2[20];
	strcopy(input2, sizeof(input2), input);
	char name[MAX_NAME_LENGTH + 8];
	GetCmdArg(3, name, sizeof(name));
	StripQuotes(name);
	char clean_name[MAX_NAME_LENGTH * 2 + 16];
	SQL_EscapeString(g_DB, name, clean_name, sizeof(clean_name));
	
	grantPoliceEx(client, input2, d1, clean_name);
	return Plugin_Handled;
}

public Action cmdtPolice(int client, int args) {
	Menu mainChooser = CreateMenu(mainChooserHandler);
	SetMenuTitle(mainChooser, "Totenfluchs tPolice Control");
	AddMenuItem(mainChooser, "add", "Add Police Access");
	AddMenuItem(mainChooser, "remove", "Remove Police Access");
	AddMenuItem(mainChooser, "extend", "Extend Police Access");
	AddMenuItem(mainChooser, "list", "List Police Officers (Info)");
	DisplayMenu(mainChooser, client, 60);
	return Plugin_Handled;
}

public Action cmdListPolices(int client, int args) {
	char showOffpoliceQuery[1024];
	Format(showOffpoliceQuery, sizeof(showOffpoliceQuery), "SELECT playername,playerid FROM tPolice WHERE NOW() < enddate;");
	SQL_TQuery(g_DB, SQLShowOffpoliceQuery, showOffpoliceQuery, client);
}

public void SQLShowOffpoliceQuery(Handle owner, Handle hndl, const char[] error, any data) {
	int client = data;
	Menu showOffMenu = CreateMenu(noMenuHandler);
	SetMenuTitle(showOffMenu, ">>> Police Officers <<<");
	while (SQL_FetchRow(hndl)) {
		char playerid[20];
		char playername[MAX_NAME_LENGTH + 8];
		SQL_FetchString(hndl, 0, playername, sizeof(playername));
		SQL_FetchString(hndl, 1, playerid, sizeof(playerid));
		AddMenuItem(showOffMenu, playerid, playername, ITEMDRAW_DISABLED);
	}
	DisplayMenu(showOffMenu, client, 60);
}

public int noMenuHandler(Handle menu, MenuAction action, int client, int item) {  }

public int mainChooserHandler(Handle menu, MenuAction action, int client, int item) {
	char cValue[32];
	GetMenuItem(menu, item, cValue, sizeof(cValue));
	if (action == MenuAction_Select) {
		if (StrEqual(cValue, "add")) {
			showDurationSelect(client, 1);
		} else if (StrEqual(cValue, "remove")) {
			showAllPoliceOfficerToAdmin(client);
		} else if (StrEqual(cValue, "extend")) {
			extendSelect(client);
		} else if (StrEqual(cValue, "list")) {
			listUsers(client);
		}
	}
	if (action == MenuAction_End) { 
    	delete menu; 
	}
}

int g_iReason[MAXPLAYERS + 1];
public void showDurationSelect(int client, int reason) {
	Menu selectDuration = CreateMenu(selectDurationHandler);
	SetMenuTitle(selectDuration, "Select the Duration");
	AddMenuItem(selectDuration, "testPolice", "Trial Police");
	AddMenuItem(selectDuration, "1", "1 Month");
	AddMenuItem(selectDuration, "2", "2 Month");
	AddMenuItem(selectDuration, "3", "3 Month");
	AddMenuItem(selectDuration, "4", "4 Month");
	AddMenuItem(selectDuration, "5", "5 Month");
	AddMenuItem(selectDuration, "6", "6 Month");
	AddMenuItem(selectDuration, "9", "9 Month");
	AddMenuItem(selectDuration, "12", "12 Month");
	g_iReason[client] = reason;
	DisplayMenu(selectDuration, client, 60);
}

int g_iDurationSelected[MAXPLAYERS + 1];
public int selectDurationHandler(Handle menu, MenuAction action, int client, int item) {
	char cValue[32];
	GetMenuItem(menu, item, cValue, sizeof(cValue));
	if (action == MenuAction_Select) {
		if (StrEqual(cValue, "testPolice")) {
			g_iDurationSelected[client] = g_iTestPoliceDuration;
			g_iReason[client] = 3;
			showPlayerSelectMenu(client, g_iReason[client]);
		} else {
			g_iDurationSelected[client] = StringToInt(cValue);
			showPlayerSelectMenu(client, g_iReason[client]);
		}
	}
	if (action == MenuAction_End) { 
    	delete menu; 
	}
}

public void showPlayerSelectMenu(int client, int reason) {
	Handle menu;
	char menuTitle[255];
	if (reason == 1) {
		menu = CreateMenu(targetChooserMenuHandler);
		Format(menuTitle, sizeof(menuTitle), "Select a Player to grant %i Month", g_iDurationSelected[client]);
	} else if (reason == 2) {
		menu = CreateMenu(extendChooserMenuHandler);
		Format(menuTitle, sizeof(menuTitle), "Select a Player to extend %i Month", g_iDurationSelected[client]);
	} else if (reason == 3) {
		menu = CreateMenu(targetChooserMenuHandler);
		Format(menuTitle, sizeof(menuTitle), "Select a Player to grant Test Police (%i Minutes)", g_iDurationSelected[client]);
	}
	if (menu == INVALID_HANDLE)
		return;
	SetMenuTitle(menu, menuTitle);
	int pAmount = 0;
	for (int i = 1; i <= MAXPLAYERS; i++) {
		if (i == client)
			continue;
		
		if (!isValidClient(i))
			continue;
		
		if (IsFakeClient(i))
			continue;
		
		if (reason == 2) {
			if (!g_bIspolice[i])
				continue;
		} else if (reason == 1) {
			if (g_bIspolice[i])
				continue;
		}
		
		char Id[64];
		IntToString(i, Id, sizeof(Id));
		
		char targetName[MAX_NAME_LENGTH + 1];
		GetClientName(i, targetName, sizeof(targetName));
		
		AddMenuItem(menu, Id, targetName);
		pAmount++;
	}
	if (pAmount == 0)
		CPrintToChat(client, "{red}No matching clients found (Noone there or everyone is already Police/Admin)");
	
	DisplayMenu(menu, client, 30);
}

public int targetChooserMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char info[64];
		GetMenuItem(menu, item, info, sizeof(info));
		
		int target = StringToInt(info);
		if (!isValidClient(target) || !IsClientInGame(target)) {
			CPrintToChat(client, "{red}Invalid Target");
			return;
		}
		
		grantPolice(client, target, g_iDurationSelected[client], g_iReason[client]);
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void grantPolice(int admin, int client, int duration, int reason) {
	char admin_playerid[20];
	GetClientAuthId(admin, AuthId_Steam2, admin_playerid, sizeof(admin_playerid));
	char admin_playername[MAX_NAME_LENGTH + 8];
	GetClientName(admin, admin_playername, sizeof(admin_playername));
	char clean_admin_playername[MAX_NAME_LENGTH * 2 + 16];
	SQL_EscapeString(g_DB, admin_playername, clean_admin_playername, sizeof(clean_admin_playername));
	
	
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	char playername[MAX_NAME_LENGTH + 8];
	GetClientName(client, playername, sizeof(playername));
	char clean_playername[MAX_NAME_LENGTH * 2 + 16];
	SQL_EscapeString(g_DB, playername, clean_playername, sizeof(clean_playername));
	
	
	char addpoliceQuery[4096];
	Format(addpoliceQuery, sizeof(addpoliceQuery), "INSERT INTO `tPolice` (`Id`, `timestamp`, `playername`, `playerid`, `enddate`, `admin_playername`, `admin_playerid`) VALUES (NULL, CURRENT_TIMESTAMP, '%s', '%s', CURRENT_TIMESTAMP, '%s', '%s');", clean_playername, playerid, clean_admin_playername, admin_playerid);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, addpoliceQuery);
	
	char updateTime[1024];
	if (reason != 3)
		Format(updateTime, sizeof(updateTime), "UPDATE tPolice SET enddate = DATE_ADD(enddate, INTERVAL %i MONTH) WHERE playerid = '%s';", duration, playerid);
	else
		Format(updateTime, sizeof(updateTime), "UPDATE tPolice SET enddate = DATE_ADD(enddate, INTERVAL %i MINUTE) WHERE playerid = '%s';", duration, playerid);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateTime);
	
	CPrintToChat(admin, "{green}Added {orange}%s{green} as Police Officer with {orange}%i{green} %s", playername, duration, reason == 3 ? "Minutes":"Month");
	CPrintToChat(client, "{green}You've been granted {orange}%i{green} %s of {orange}police{green} by {orange}%N", duration, reason == 3 ? "Minutes":"Month", admin);
	setFlags(client);
}

public void grantPoliceEx(int admin, char playerid[20], int duration, char[] pname) {
	char admin_playerid[20];
	GetClientAuthId(admin, AuthId_Steam2, admin_playerid, sizeof(admin_playerid));
	char admin_playername[MAX_NAME_LENGTH + 8];
	GetClientName(admin, admin_playername, sizeof(admin_playername));
	char clean_admin_playername[MAX_NAME_LENGTH * 2 + 16];
	SQL_EscapeString(g_DB, admin_playername, clean_admin_playername, sizeof(clean_admin_playername));
	
	char addpoliceQuery[4096];
	Format(addpoliceQuery, sizeof(addpoliceQuery), "INSERT INTO `tPolice` (`Id`, `timestamp`, `playername`, `playerid`, `enddate`, `admin_playername`, `admin_playerid`) VALUES (NULL, CURRENT_TIMESTAMP, '%s', '%s', CURRENT_TIMESTAMP, '%s', '%s');", pname, playerid, clean_admin_playername, admin_playerid);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, addpoliceQuery);
	
	char updateTime[1024];
	Format(updateTime, sizeof(updateTime), "UPDATE tPolice SET enddate = DATE_ADD(enddate, INTERVAL %i MONTH) WHERE playerid = '%s';", duration, playerid);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateTime);
	
	CPrintToChat(admin, "{green}Added {orange}%s{green} as police with {orange}%i{green} Month", playerid, duration);
}

public void OnClientPostAdminCheck(int client) {
	g_bIspolice[client] = false;
	char cleanUp[256];
	Format(cleanUp, sizeof(cleanUp), "DELETE FROM tPolice WHERE enddate < NOW();");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, cleanUp);
	
	loadpolice(client);
}

public void loadpolice(int client) {
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	char ispoliceQuery[1024];
	Format(ispoliceQuery, sizeof(ispoliceQuery), "SELECT * FROM tPolice WHERE playerid = '%s' AND enddate > NOW();", playerid);
	SQL_TQuery(g_DB, SQLCheckpoliceQuery, ispoliceQuery, client);
}

public void SQLCheckpoliceQuery(Handle owner, Handle hndl, const char[] error, any data) {
	int client = data;
	while (SQL_FetchRow(hndl)) {
		setFlags(client);
	}
}

public void setFlags(int client) {
	g_bIspolice[client] = true;
	for (int i = 0; i < g_iFlagCount; i++)
	SetUserFlagBits(client, GetUserFlagBits(client) | (1 << g_iFlags[i]));
}

public void OnRebuildAdminCache(AdminCachePart part) {
	if (part == AdminCache_Admins)
		reloadPoliceOfficer();
}

public void reloadPoliceOfficer() {
	for (int i = 1; i < MAXPLAYERS; i++) {
		if (!isValidClient(i))
			continue;
		loadpolice(i);
	}
}

public void showAllPoliceOfficerToAdmin(int client) {
	char selectAllPoliceOfficer[1024];
	Format(selectAllPoliceOfficer, sizeof(selectAllPoliceOfficer), "SELECT playername,playerid FROM tPolice WHERE NOW() < enddate;");
	SQL_TQuery(g_DB, SQLListPolicesForRemoval, selectAllPoliceOfficer, client);
}

public void SQLListPolicesForRemoval(Handle owner, Handle hndl, const char[] error, any data) {
	int client = data;
	Menu menuToRemoveClients = CreateMenu(menuToRemoveClientsHandler);
	SetMenuTitle(menuToRemoveClients, "Delete a Police Officer");
	while (SQL_FetchRow(hndl)) {
		char playerid[20];
		char playername[MAX_NAME_LENGTH + 8];
		SQL_FetchString(hndl, 0, playername, sizeof(playername));
		SQL_FetchString(hndl, 1, playerid, sizeof(playerid));
		AddMenuItem(menuToRemoveClients, playerid, playername);
	}
	DisplayMenu(menuToRemoveClients, client, 60);
}

public int menuToRemoveClientsHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char info[20];
		char display[MAX_NAME_LENGTH + 8];
		int flags;
		GetMenuItem(menu, item, info, sizeof(info), flags, display, sizeof(display));
		deletepolice(info);
		showAllPoliceOfficerToAdmin(client);
		CPrintToChat(client, "{green}Removed {orange}%ss{green} Police Status {green}({orange}%s{green})", display, info);
	}
	if (action == MenuAction_End) { 
    	delete menu; 
	}
}

public void deletepolice(char playerid[20]) {
	char deletepoliceQuery[512];
	Format(deletepoliceQuery, sizeof(deletepoliceQuery), "DELETE FROM tPolice WHERE playerid = '%s';", playerid);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, deletepoliceQuery);
}

public void extendSelect(int client) {
	showDurationSelect(client, 2);
}

public int extendChooserMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char info[64];
		GetMenuItem(menu, item, info, sizeof(info));
		
		int target = StringToInt(info);
		if (!isValidClient(target) || !IsClientInGame(target)) {
			CPrintToChat(client, "{red}Invalid Target");
			return;
		}
		
		int userTarget = GetClientUserId(target);
		extendpolice(client, userTarget, g_iDurationSelected[client]);
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void extendpolice(int client, int userTarget, int duration) {
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	char playername[MAX_NAME_LENGTH + 8];
	GetClientName(client, playername, sizeof(playername));
	char clean_playername[MAX_NAME_LENGTH * 2 + 16];
	SQL_EscapeString(g_DB, playername, clean_playername, sizeof(clean_playername));
	
	char updateQuery[1024];
	Format(updateQuery, sizeof(updateQuery), "UPDATE tPolice SET enddate = DATE_ADD(enddate, INTERVAL %i MONTH) WHERE playerid = '%s';", duration, playerid);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateQuery);
	
	Format(updateQuery, sizeof(updateQuery), "UPDATE tPolice SET playername = '%s' WHERE playerid = '%s';", clean_playername, playerid);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateQuery);
	
	CPrintToChat(client, "{green}Extended {orange}%s{green} Police Status by {orange}%i{green} Month", playername, duration);
}

public void listUsers(int client) {
	char listPolicesQuery[1024];
	Format(listPolicesQuery, sizeof(listPolicesQuery), "SELECT playername,playerid FROM tPolice WHERE enddate > NOW();");
	SQL_TQuery(g_DB, SQLListPolicesQuery, listPolicesQuery, client);
}

public void SQLListPolicesQuery(Handle owner, Handle hndl, const char[] error, any data) {
	int client = data;
	Menu menuToRemoveClients = CreateMenu(listPolicesMenuHandler);
	SetMenuTitle(menuToRemoveClients, "All Police Officers");
	while (SQL_FetchRow(hndl)) {
		char playerid[20];
		char playername[MAX_NAME_LENGTH + 8];
		SQL_FetchString(hndl, 0, playername, sizeof(playername));
		SQL_FetchString(hndl, 1, playerid, sizeof(playerid));
		AddMenuItem(menuToRemoveClients, playerid, playername);
	}
	DisplayMenu(menuToRemoveClients, client, 60);
}

public int listPolicesMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[20];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		char detailsQuery[512];
		Format(detailsQuery, sizeof(detailsQuery), "SELECT playername,playerid,enddate,timestamp,admin_playername,admin_playerid FROM tPolice WHERE playerid = '%s';", cValue);
		SQL_TQuery(g_DB, SQLDetailsQuery, detailsQuery, client);
	}
	if (action == MenuAction_End) { 
    	delete menu; 
	}
}

public void SQLDetailsQuery(Handle owner, Handle hndl, const char[] error, any data) {
	int client = data;
	Menu detailsMenu = CreateMenu(detailsMenuHandler);
	bool hasData = false;
	while (SQL_FetchRow(hndl) && !hasData) {
		char playerid[20];
		char playername[MAX_NAME_LENGTH + 8];
		char startDate[128];
		char endDate[128];
		char adminname[MAX_NAME_LENGTH + 8];
		char adminplayerid[20];
		SQL_FetchString(hndl, 0, playername, sizeof(playername));
		SQL_FetchString(hndl, 1, playerid, sizeof(playerid));
		SQL_FetchString(hndl, 2, endDate, sizeof(endDate));
		SQL_FetchString(hndl, 3, startDate, sizeof(startDate));
		SQL_FetchString(hndl, 4, adminname, sizeof(adminname));
		SQL_FetchString(hndl, 5, adminplayerid, sizeof(adminplayerid));
		
		char title[64];
		Format(title, sizeof(title), "Details: %s", playername);
		SetMenuTitle(detailsMenu, title);
		
		char playeridItem[64];
		Format(playeridItem, sizeof(playeridItem), "STEAM_ID: %s", playerid);
		AddMenuItem(detailsMenu, "x", playeridItem, ITEMDRAW_DISABLED);
		
		char endItem[64];
		Format(endItem, sizeof(endItem), "Ends: %s", endDate);
		AddMenuItem(detailsMenu, "x", endItem, ITEMDRAW_DISABLED);
		
		char startItem[64];
		Format(startItem, sizeof(startItem), "Started: %s", startDate);
		AddMenuItem(detailsMenu, "x", startItem, ITEMDRAW_DISABLED);
		
		char adminNItem[64];
		Format(adminNItem, sizeof(adminNItem), "By Admin: %s", adminname);
		AddMenuItem(detailsMenu, "x", adminNItem, ITEMDRAW_DISABLED);
		
		char adminIItem[64];
		Format(adminIItem, sizeof(adminIItem), "Admin ID: %s", adminplayerid);
		AddMenuItem(detailsMenu, "x", adminIItem, ITEMDRAW_DISABLED);
		
		hasData = true;
	}
	DisplayMenu(detailsMenu, client, 60);
}

public int detailsMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		
	} else if (action == MenuAction_Cancel) {
		listUsers(client);
	}
}

stock bool isValidClient(int client) {
	return (1 <= client <= MaxClients && IsClientInGame(client));
}

stock bool ispoliceCheck(int client) {
	return CheckCommandAccess(client, "sm_lul", (1 << g_iFlag), true);
}

public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, any data) {
	if (!StrEqual(error, ""))
		LogError(error);
} 