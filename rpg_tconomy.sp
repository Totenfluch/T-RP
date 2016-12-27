#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <multicolors>

#pragma newdecls required

int g_iMoney[MAXPLAYERS + 1];
int g_iBankedMoney[MAXPLAYERS + 1];
bool g_bLoaded[MAXPLAYERS + 1];

char dbconfig[] = "gsxh_multiroot";
Database g_DB;

char currencyName[] = "tCoins";

public Plugin myinfo = 
{
	name = "tConomy", 
	author = PLUGIN_AUTHOR, 
	description = "Enonmy System for T-RP", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart() {
	RegConsoleCmd("sm_money", cmdMoney, "Displays your current Money");
	RegAdminCmd("sm_givemoney", cmdGiveMoney, ADMFLAG_ROOT, "Give a Client Currency");
	RegAdminCmd("sm_givebankedmoney", cmdGiveBankedMoney, ADMFLAG_ROOT, "Give a Client Banked Currency");
	
	char error[255];
	g_DB = SQL_Connect(dbconfig, true, error, sizeof(error));
	SQL_SetCharset(g_DB, "utf8");
	
	char createTableQuery[4096];
	Format(createTableQuery, sizeof(createTableQuery), 
		"CREATE TABLE IF NOT EXISTS `t_rpg_tConomy` ( \
  `Id` bigint(20) NOT NULL AUTO_INCREMENT, \
  `playerid` varchar(20) COLLATE utf8_bin NOT NULL, \
  `playername` varchar(64) COLLATE utf8_bin NOT NULL, \
  `currency` int(11) NOT NULL, \
  `bankCurrency` int(11) NOT NULL, \
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, \
  PRIMARY KEY (`Id`), \
  UNIQUE KEY `playerid` (`playerid`) \
  )ENGINE = InnoDB DEFAULT CHARSET = utf8 COLLATE = utf8_bin;");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createTableQuery);
	
	char createTableQuery2[4096];
	Format(createTableQuery2, sizeof(createTableQuery2), "CREATE TABLE IF NOT EXISTS `t_rpg_tConomy_log` ( `Id` INT NULL DEFAULT NULL AUTO_INCREMENT , `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , `playerid` VARCHAR(20) NOT NULL , `amount` INT NOT NULL , `reason` VARCHAR(512) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL , PRIMARY KEY (`Id`)) ENGINE = InnoDB CHARSET=utf8 COLLATE utf8_bin;");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createTableQuery2);
}

public void OnClientDisconnect(int client) {
	g_bLoaded[client] = false;
}

public Action cmdMoney(int client, int args) {
	CPrintToChat(client, "{green}[{purple}tConomy{green}] {orange}You have {purple}%i{orange} {purple}%s", g_iMoney[client], currencyName);
	return Plugin_Handled;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	/*
		Adds Currency to a Players Account
		
		@Param1 -> int client
		@Param2 -> int amount
		@Param3 -> char reason[256]
		
		@return money after change
	*/
	CreateNative("tConomy_addCurrency", Native_addCurrency);
	
	/*
		Removes Currency to a Players Account
		
		@Param1 -> int client
		@Param2 -> int amount
		@Param3 -> char reason[256]
		
		@return money after change
	*/
	CreateNative("tConomy_removeCurrency", Native_removeCurrency);
	
	/*
		Sets Currency on a Players Account
		
		@Param1 -> int client
		@Param2 -> int amount
		@Param3 -> char reason[256]
		
		@return money after change
	*/
	CreateNative("tConomy_setCurrency", Native_setCurrency);
	
	/*
		Gets the Clients Currency amount
		
		@Param1 -> int client
		
		@return money owned
	*/
	CreateNative("tConomy_getCurrency", Native_getCurrency);
	
	
	
	/*
		Adds Currency to a Players Bank  Account
		
		@Param1 -> int client
		@Param2 -> int amount
		@Param3 -> char reason[256]
		
		@return money after change
	*/
	CreateNative("tConomy_addBankCurrency", Native_addBankCurrency);
	
	/*
		Removes Currency to a Players Bank Account
		
		@Param1 -> int client
		@Param2 -> int amount
		@Param3 -> char reason[256]
		
		@return money after change
	*/
	CreateNative("tConomy_removeBankCurrency", Native_removeBankCurrency);
	
	/*
		Sets Currency on a Players Bank Account
		
		@Param1 -> int client
		@Param2 -> int amount
		@Param3 -> char reason[256]
		
		@return money after change
	*/
	CreateNative("tConomy_setBankCurrency", Native_setBankCurrency);
	
	/*
		Gets the Clients Bank Currency amount
		
		@Param1 -> int client
		
		@return money owned
	*/
	CreateNative("tConomy_getBankCurrency", Native_getBankCurrency);
	
	/*
		Return if a client is loaded
		
		@Param1 -> int client
		
		@return true if loaded
	*/
	CreateNative("tConomy_isClientLoaded", Native_isClientLoaded);
}

public int Native_addCurrency(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	int amount = GetNativeCell(2);
	char reason[256];
	GetNativeString(3, reason, sizeof(reason));
	addCurrency(client, amount, reason, false);
	return g_iMoney[client];
}

public int Native_removeCurrency(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	int amount = GetNativeCell(2);
	char reason[256];
	GetNativeString(3, reason, sizeof(reason));
	removeCurrency(client, amount, reason, false);
	return g_iMoney[client];
}

public int Native_setCurrency(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	int amount = GetNativeCell(2);
	char reason[256];
	GetNativeString(3, reason, sizeof(reason));
	setCurrency(client, amount, reason, false);
	return g_iMoney[client];
}

public int Native_addBankCurrency(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	int amount = GetNativeCell(2);
	char reason[256];
	GetNativeString(3, reason, sizeof(reason));
	addCurrency(client, amount, reason, true);
	return g_iBankedMoney[client];
}

public int Native_removeBankCurrency(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	int amount = GetNativeCell(2);
	char reason[256];
	GetNativeString(3, reason, sizeof(reason));
	removeCurrency(client, amount, reason, true);
	return g_iBankedMoney[client];
}

public int Native_setBankCurrency(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	int amount = GetNativeCell(2);
	char reason[256];
	GetNativeString(3, reason, sizeof(reason));
	setCurrency(client, amount, reason, true);
	return g_iBankedMoney[client];
}

public int Native_getCurrency(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	return g_iMoney[client];
}

public int Native_getBankCurrency(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	return g_iBankedMoney[client];
}

public int Native_isClientLoaded(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	return g_bLoaded[client];
}

public void OnClientPostAdminCheck(int client) {
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	char addClientQuery[512];
	
	char playername[MAX_NAME_LENGTH + 8];
	GetClientName(client, playername, sizeof(playername));
	char clean_playername[MAX_NAME_LENGTH * 2 + 16];
	SQL_EscapeString(g_DB, playername, clean_playername, sizeof(clean_playername));
	
	Format(addClientQuery, sizeof(addClientQuery), "INSERT IGNORE INTO `t_rpg_tConomy` (`Id`, `playerid`, `playername`, `currency`, `bankCurrency`, `timestamp`) VALUES (NULL, '%s', '%s', '0', '0', CURRENT_TIMESTAMP);", playerid, clean_playername);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, addClientQuery);
	
	g_bLoaded[client] = false;
	CreateTimer(1.0, loadMoney, client);
}

public void addCurrency(int client, int amount, char reason[256], bool isBank) {
	if (!g_bLoaded[client])return;
	logtConomyAction(client, amount, reason, isBank);
	
	if (isBank)
		g_iBankedMoney[client] += amount;
	else
		g_iMoney[client] += amount;
	
	forceCurrencyUpdateQuery(client);
	forceNameUpdate(client);
}

public void removeCurrency(int client, int amount, char reason[256], bool isBank) {
	if (!g_bLoaded[client])return;
	logtConomyAction(client, -amount, reason, isBank);
	
	if (isBank)
		g_iBankedMoney[client] -= amount;
	else
		g_iMoney[client] -= amount;
	
	forceCurrencyUpdateQuery(client);
	forceNameUpdate(client);
}

public void setCurrency(int client, int amount, char reason[256], bool isBank) {
	if (!g_bLoaded[client])return;
	char reason2[256];
	Format(reason2, sizeof(reason2), "SET %s", reason);
	logtConomyAction(client, amount, reason2, isBank);
	
	if (isBank)
		g_iBankedMoney[client] = amount;
	else
		g_iMoney[client] = amount;
	
	forceCurrencyUpdateQuery(client);
	forceNameUpdate(client);
}

public int getCurrency(int client, bool isBank) {
	if (!g_bLoaded[client])return -1;
	if (isBank)
		return g_iBankedMoney[client];
	else
		return g_iMoney[client];
}

public Action loadMoney(Handle Timer, int client) {
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	char loadMoneyQuery[512];
	Format(loadMoneyQuery, sizeof(loadMoneyQuery), "SELECT currency,bankCurrency FROM t_rpg_tConomy WHERE playerid = '%s'", playerid);
	SQL_TQuery(g_DB, SQLLoadMoneyQueryCallback, loadMoneyQuery, client);
}

public void logtConomyAction(int client, int amount, char reason[256], bool isBank) {
	if (amount == 0)
		return;
	char playerLog[256];
	if (isBank)
		Format(playerLog, sizeof(playerLog), "{green}[{purple}tConomy{green}] {orange}Your Banked {purple}%s{orange} have been changed by {purple}%i{orange}{orange} (%s)", currencyName, amount, reason);
	else
		Format(playerLog, sizeof(playerLog), "{green}[{purple}tConomy{green}] {orange}Your {purple}%s{orange} have been changed by {purple}%i {orange} (%s)", currencyName, amount, reason);
	
	CPrintToChat(client, playerLog);
	
	char realReason[256];
	if (isBank)
		Format(realReason, sizeof(realReason), "BANK %s", reason);
	else
		Format(realReason, sizeof(realReason), "Currency %s", reason);
	
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	char logQuery[512];
	Format(logQuery, sizeof(logQuery), "INSERT INTO `t_rpg_tConomy_log` (`Id`, `timestamp`, `playerid`, `amount`, `reason`) VALUES (NULL, CURRENT_TIMESTAMP, '%s', '%i', '%s');", playerid, amount, realReason);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, logQuery);
}

public void forceNameUpdate(int client) {
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char playername[MAX_NAME_LENGTH + 8];
	GetClientName(client, playername, sizeof(playername));
	char clean_playername[MAX_NAME_LENGTH * 2 + 16];
	SQL_EscapeString(g_DB, playername, clean_playername, sizeof(clean_playername));
	
	char playernameUpdateQuery[512];
	Format(playernameUpdateQuery, sizeof(playernameUpdateQuery), "UPDATE t_rpg_tConomy SET playername = '%s' WHERE playerid = '%s'", clean_playername, playerid);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, playernameUpdateQuery);
}

public void forceCurrencyUpdateQuery(int client) {
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char bankCurrencyUpdateQuery[512];
	Format(bankCurrencyUpdateQuery, sizeof(bankCurrencyUpdateQuery), "UPDATE t_rpg_tConomy SET bankCurrency = %i WHERE playerid = '%s'", g_iBankedMoney[client], playerid);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, bankCurrencyUpdateQuery);
	
	char CurrencyUpdateQuery[512];
	Format(CurrencyUpdateQuery, sizeof(CurrencyUpdateQuery), "UPDATE t_rpg_tConomy SET currency = %i WHERE playerid = '%s'", g_iMoney[client], playerid);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, CurrencyUpdateQuery);
}

public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, any data) {
	if (!StrEqual(error, ""))
		LogError(error);
}

public Action cmdGiveMoney(int client, int args) {
	if (args < 2) {
		ReplyToCommand(client, "[SM tConomy] Usage: sm_givemoney <target> <amount>");
		return Plugin_Handled;
	}
	
	char tempCurrencyString[64];
	GetCmdArg(2, tempCurrencyString, sizeof(tempCurrencyString));
	
	int tempCurrency = StringToInt(tempCurrencyString);
	if (tempCurrency < -100000 || tempCurrency > 100000)
		ReplyToCommand(client, "Invalind Amount | < -100000 || > 100000");
	
	char pattern[MAX_NAME_LENGTH + 8];
	char buffer[MAX_NAME_LENGTH + 8];
	GetCmdArg(1, pattern, sizeof(pattern));
	int targets[64];
	bool ml = false;
	
	int count = ProcessTargetString(pattern, client, targets, sizeof(targets), COMMAND_FILTER_ALIVE, buffer, sizeof(buffer), ml);
	
	char reason[256];
	Format(reason, sizeof(reason), "Given by %N", client);
	
	if (count <= 0)
		ReplyToCommand(client, "Invalid or Bad Target");
	else {
		for (int i = 0; i < count; i++) {
			int target = targets[i];
			if (tempCurrency >= 0)
				addCurrency(target, tempCurrency, reason, false);
			else
				removeCurrency(target, tempCurrency, reason, false);
		}
	}
	
	return Plugin_Handled;
}

public Action cmdGiveBankedMoney(int client, int args) {
	if (args < 2) {
		ReplyToCommand(client, "[SM tConomy] Usage: sm_givebankedmoney <target> <amount>");
		return Plugin_Handled;
	}
	
	char tempCurrencyString[64];
	GetCmdArg(2, tempCurrencyString, sizeof(tempCurrencyString));
	
	int tempCurrency = StringToInt(tempCurrencyString);
	if (tempCurrency < -100000 || tempCurrency > 100000)
		ReplyToCommand(client, "Invalid Amount | < -100000 || > 100000");
	
	char pattern[MAX_NAME_LENGTH + 8];
	char buffer[MAX_NAME_LENGTH + 8];
	GetCmdArg(1, pattern, sizeof(pattern));
	int targets[64];
	bool ml = false;
	
	int count = ProcessTargetString(pattern, client, targets, sizeof(targets), COMMAND_FILTER_ALIVE, buffer, sizeof(buffer), ml);
	
	char reason[256];
	Format(reason, sizeof(reason), "Given by %N", client);
	
	if (count <= 0)
		ReplyToCommand(client, "Invalid or Bad Target");
	else {
		for (int i = 0; i < count; i++) {
			int target = targets[i];
			if (tempCurrency >= 0)
				addCurrency(target, tempCurrency, reason, true);
			else
				removeCurrency(target, tempCurrency, reason, true);
		}
	}
	
	return Plugin_Handled;
}

public void SQLLoadMoneyQueryCallback(Handle owner, Handle hndl, const char[] error, any data) {
	while (SQL_FetchRow(hndl)) {
		int client = data;
		g_iMoney[client] = SQL_FetchIntByName(hndl, "curency");
		g_iBankedMoney[client] = SQL_FetchIntByName(hndl, "bankCurrency");
		g_bLoaded[client] = true;
	}
} 