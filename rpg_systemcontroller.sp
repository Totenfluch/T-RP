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
#include <smlib>
#include <multicolors>
#include <cstrike>

#pragma newdecls required

#define CSGO_HEGRENADE_AMMO 14
#define CSGO_FLASH_AMMO 15
#define CSGO_SMOKE_AMMO 16
#define INCENDERY_AND_MOLOTOV_AMMO 17
#define	DECOY_AMMO 18


public Plugin myinfo = 
{
	name = "[T-RP] System Controller", 
	author = PLUGIN_AUTHOR, 
	description = "Saves General Player Properties", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

Database g_DB;
char dbconfig[] = "gsxh_multiroot";
bool g_bIsPlayerLoaded[MAXPLAYERS + 1];
bool g_bIsStarted = false;
Handle g_hOnGameStarted;

public void OnPluginStart() {
	char error[255];
	g_DB = SQL_Connect(dbconfig, true, error, sizeof(error));
	SQL_SetCharset(g_DB, "utf8");
	
	/*
		Id	playername	playerid	timestamp	
		int	vchar		vchar		timestamp
	
		HP	Armor	Speed	Gravity	Angles(2)	Pos_x	Pos_y	Pos_z	primaryWeapon	primaryWeaponClip	primaryWeaponAmmo		
		int	int		float	float	float		float	float	float	vchar			int					int
		
		secondaryWeapon	secondaryWeaponClip	secondaryWeaponAmmo	nade1	nade2	nade3	nade4	nade5	flags	extern1	extern2	extern3
		vchar			int					int					vchar	vchar	vchar	vchar	vchar	vchar	vchar	vchar	vchar
	*/
	char createTableQuery[8096];
	Format(createTableQuery, sizeof(createTableQuery), "CREATE TABLE IF NOT EXISTS t_rpg_playercontroller (`Id`BIGINT NOT NULL AUTO_INCREMENT, `playername`VARCHAR(64)CHARACTER SET utf8 COLLATE utf8_bin NOT NULL, `playerid`VARCHAR(20)NOT NULL, `timestamp`TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, `map`VARCHAR(64)CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,`hp`INT NOT NULL, `armor`INT NOT NULL, `speed`FLOAT NOT NULL, `gravity`FLOAT NOT NULL, `angles`FLOAT NOT NULL, `pos_x`FLOAT NOT NULL, `pos_y`FLOAT NOT NULL, `pos_z`FLOAT NOT NULL, `primaryWeapon`VARCHAR(64)NOT NULL, `primaryWeaponClip`INT NOT NULL, `primaryWeaponAmmo`INT NOT NULL, `secondaryWeapon`VARCHAR(64)NOT NULL, `secondaryWeaponClip`INT NOT NULL, `secondaryWeaponAmmo`INT NOT NULL, `nade1`VARCHAR(64)NOT NULL, `nade2`VARCHAR(64)NOT NULL, `nade3`VARCHAR(64)NOT NULL, `nade4`VARCHAR(64)NOT NULL, `nade5`VARCHAR(64)NOT NULL, `flags`VARCHAR(8)NOT NULL, `extern1`VARCHAR(128)NOT NULL, `extern2`VARCHAR(128)NOT NULL, `extern3`VARCHAR(128)NOT NULL, PRIMARY KEY(`Id`), UNIQUE(`playerid`, `map`))ENGINE = InnoDB CHARSET = utf8 COLLATE utf8_bin; ");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createTableQuery);
	
	HookEvent("player_spawn", onPlayerSpawn, EventHookMode_Post);
	HookEvent("round_start", onRoundStart, EventHookMode_Post);
	HookEvent("round_end", onRoundEnd, EventHookMode_Post);
	HookEvent("cs_match_end_restart", onGameRestart);
	HookEvent("round_prestart", onGamePreRestart);
	
	RegConsoleCmd("sm_loaded", amILoaded, "shows if loaded");
	
	SetServerConvars();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	/*
		Returns if a client is loaded
		
		@Param1 -> int client
		
		@return boolean loaded or not
	*/
	CreateNative("rpg_isClientLoaded", Native_isClientLoaded);
	
	/*
		Returns if game has started
		
		@Param none
		
		@return boolean started or not
	*/
	CreateNative("rpg_hasGameStarted", Native_hasGameStarted);
	
	/*
		Forward when the game starts
		
		@Params none
		
		@return -
	*/
	g_hOnGameStarted = CreateGlobalForward("OnRpStarted", ET_Ignore);
}

public int Native_isClientLoaded(Handle plugin, int numParams) {
	return g_bIsPlayerLoaded[GetNativeCell(1)];
}

public int Native_hasGameStarted(Handle plugin, int numParams) {
	return g_bIsStarted;
}

public Action onGameRestart(Handle event, const char[] name, bool dontBroadcast) {
	if (!g_bIsStarted)
		return;
	for (int i = 1; i < MAXPLAYERS; i++) {
		if (!g_bIsPlayerLoaded[i])
			continue;
		if (!isValidClient(i))
			continue;
		g_bIsPlayerLoaded[i] = false;
		
		savePlayer(i);
	}
}

public Action onGamePreRestart(Handle event, const char[] name, bool dontBroadcast) {
	if (!g_bIsStarted)
		return;
	for (int i = 1; i < MAXPLAYERS; i++) {
		if (!g_bIsPlayerLoaded[i])
			continue;
		if (!isValidClient(i))
			continue;
		g_bIsPlayerLoaded[i] = false;
		
		savePlayer(i);
	}
}

public Action amILoaded(int client, int args) {
	PrintToChat(client, "Loaded: %d | Started: %d", g_bIsPlayerLoaded[client], g_bIsStarted);
	
	int weaponIndex;
	
	char primaryWeapon[64];
	int primaryWeaponAmmo;
	int primaryWeaponClip;
	if ((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1) {
		Entity_GetClassName(weaponIndex, primaryWeapon, sizeof(primaryWeapon));
		primaryWeaponClip = Weapon_GetPrimaryClip(weaponIndex);
		primaryWeaponAmmo = GetEntProp(weaponIndex, Prop_Send, "m_iPrimaryReserveAmmoCount");
	}
	
	char secondaryWeapon[64];
	int secondaryWeaponAmmo;
	int secondaryWeaponClip;
	if ((weaponIndex = GetPlayerWeaponSlot(client, 1)) != -1) {
		Entity_GetClassName(weaponIndex, secondaryWeapon, sizeof(secondaryWeapon));
		secondaryWeaponClip = Weapon_GetPrimaryClip(weaponIndex);
		secondaryWeaponAmmo = GetEntProp(weaponIndex, Prop_Send, "m_iPrimaryReserveAmmoCount");
	}
	
	char nades[64][64];
	int i = 0;
	for (int b = getClientHEGrenades(client); b > 0; b--)
	strcopy(nades[i++], 64, "weapon_hegrenade");
	for (int b = getClientSmokeGrenades(client); b > 0; b--)
	strcopy(nades[i++], 64, "weapon_smokegrenade");
	for (int b = getClientFlashbangs(client); b > 0; b--)
	strcopy(nades[i++], 64, "weapon_flashbang");
	for (int b = getClientDecoyGrenades(client); b > 0; b--)
	strcopy(nades[i++], 64, "weapon_decoy");
	for (int b = getClientIncendaryGrenades(client); b > 0; b--)
	strcopy(nades[i++], 64, "weapon_molotov");
	
	PrintToChat(client, "%s %s %s %s %s %i %i %i %i %i", nades[0], nades[1], nades[2], nades[3], nades[4], getClientHEGrenades(client), getClientSmokeGrenades(client), getClientFlashbangs(client), getClientDecoyGrenades(client), getClientIncendaryGrenades(client));
	PrintToChat(client, "pp:%i ps:%i  | sp:%i ss:%i", primaryWeaponClip, primaryWeaponAmmo, secondaryWeaponClip, secondaryWeaponAmmo);
	return Plugin_Handled;
}



public void onPlayerSpawn(Handle event, const char[] name, bool dontBroadcast) {
	if (!g_bIsStarted)
		return;
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsPlayerAlive(client) || (GetClientTeam(client) != 3 && GetClientTeam(client) != 2))
		return;
	if (g_bIsPlayerLoaded[client])
		return;
	
	loadPlayer(client);
}

public void onRoundStart(Handle event, const char[] name, bool dontBroadcast) {
	SetServerConvars();
	if (!g_bIsStarted)
		return;
}

public void onRoundEnd(Handle event, const char[] name, bool dontBroadcast) {
	if (!g_bIsStarted)
		return;
	for (int i = 1; i < MAXPLAYERS; i++) {
		if (!g_bIsPlayerLoaded[i])
			continue;
		if (!isValidClient(i))
			continue;
		g_bIsPlayerLoaded[i] = false;
		
		savePlayer(i);
	}
}

public void loadPlayer(int client) {
	if (!g_bIsPlayerLoaded[client])
		CreateTimer(0.1, delayedLoad, client);
}

public Action delayedLoad(Handle Timer, int client) {
	if (!IsClientConnected(client))
		return;
	if (!g_bIsStarted)
		return;
	if (!IsPlayerAlive(client) || (GetClientTeam(client) != 3 && GetClientTeam(client) != 2))
		return;
	if (g_bIsPlayerLoaded[client])
		return;
	CPrintToChat(client, "{orange}[{purple}-T-{orange}] {red}Trying to load you ({orange}%N{red})...", client);
	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char loadQueryString[1024];
	Format(loadQueryString, sizeof(loadQueryString), "SELECT * FROM t_rpg_playercontroller WHERE playerid = '%s' AND map = '%s';", playerid, mapName);
	SQL_TQuery(g_DB, SQLLoadPlayerCallback, loadQueryString, GetClientUserId(client));
}

public void SQLLoadPlayerCallback(Handle owner, Handle hndl, const char[] error, any data) {
	int client = GetClientOfUserId(data);
	if (!isValidClient(client))
		return;
	if (g_bIsPlayerLoaded[client])
		return;
	while (SQL_FetchRow(hndl)) {
		int Hp = SQL_FetchIntByName(hndl, "hp");
		int Armor = SQL_FetchIntByName(hndl, "armor");
		float Speed = SQL_FetchFloatByName(hndl, "speed");
		float Gravity = SQL_FetchFloatByName(hndl, "gravity");
		float Angles[3];
		Angles[1] = SQL_FetchFloatByName(hndl, "angles");
		float Position[3];
		Position[0] = SQL_FetchFloatByName(hndl, "pos_x");
		Position[1] = SQL_FetchFloatByName(hndl, "pos_y");
		Position[2] = SQL_FetchFloatByName(hndl, "pos_z");
		char primaryWeapon[64];
		SQL_FetchStringByName(hndl, "primaryWeapon", primaryWeapon, sizeof(primaryWeapon));
		int primaryWeaponClip = SQL_FetchIntByName(hndl, "primaryWeaponClip");
		int primaryWeaponAmmo = SQL_FetchIntByName(hndl, "primaryWeaponAmmo");
		
		char secondaryWeapon[64];
		SQL_FetchStringByName(hndl, "secondaryWeapon", secondaryWeapon, sizeof(secondaryWeapon));
		int secondaryWeaponClip = SQL_FetchIntByName(hndl, "secondaryWeaponClip");
		int secondaryWeaponAmmo = SQL_FetchIntByName(hndl, "secondaryWeaponAmmo");
		
		char nade1[64];
		SQL_FetchStringByName(hndl, "nade1", nade1, sizeof(nade1));
		char nade2[64];
		SQL_FetchStringByName(hndl, "nade2", nade2, sizeof(nade2));
		char nade3[64];
		SQL_FetchStringByName(hndl, "nade3", nade3, sizeof(nade3));
		char nade4[64];
		SQL_FetchStringByName(hndl, "nade4", nade4, sizeof(nade4));
		char nade5[64];
		SQL_FetchStringByName(hndl, "nade5", nade5, sizeof(nade5));
		
		char extern1[64];
		SQL_FetchStringByName(hndl, "extern1", extern1, sizeof(extern1));
		
		char extern2[64];
		SQL_FetchStringByName(hndl, "extern2", extern2, sizeof(extern2));
		
		if (Hp != 0)
			SetEntityHealth(client, Hp);
		if (Armor != 0)
			SetEntProp(client, Prop_Data, "m_ArmorValue", Armor, 1);
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", Speed);
		SetEntityGravity(client, Gravity);
		if (Position[0] != 0.0 && Position[1] != 0.0)
			TeleportEntity(client, Position, Angles, NULL_VECTOR);
		int weaponIndex;
		if (!StrEqual(primaryWeapon, "")) {
			GivePlayerItem(client, primaryWeapon);
			Client_SetWeaponAmmo(client, primaryWeapon, _, _, primaryWeaponClip, primaryWeaponAmmo);
			if ((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1)
				SetEntProp(weaponIndex, Prop_Send, "m_iPrimaryReserveAmmoCount", primaryWeaponAmmo);
		}
		if (!StrEqual(secondaryWeapon, "")) {
			GivePlayerItem(client, secondaryWeapon);
			Client_SetWeaponAmmo(client, secondaryWeapon, _, _, secondaryWeaponClip, secondaryWeaponAmmo);
			if ((weaponIndex = GetPlayerWeaponSlot(client, 1)) != -1)
				SetEntProp(weaponIndex, Prop_Send, "m_iPrimaryReserveAmmoCount", secondaryWeaponAmmo);
		}
		if (!StrEqual(nade1, ""))
			GivePlayerItem(client, nade1);
		if (!StrEqual(nade2, ""))
			GivePlayerItem(client, nade2);
		if (!StrEqual(nade3, ""))
			GivePlayerItem(client, nade3);
		if (!StrEqual(nade4, ""))
			GivePlayerItem(client, nade4);
		if (!StrEqual(nade5, ""))
			GivePlayerItem(client, nade5);
		
		if (StrContains(extern1, "taser") != -1)
			GivePlayerItem(client, "weapon_taser");
		
		if (StrContains(extern2, "helmet") != -1 && Armor != 0)
			SetEntProp(client, Prop_Send, "m_bHasHelmet", 1);
		
		CPrintToChat(client, "{orange}[{purple}-T-{orange}] {green}Sucessfully load you ({orange}%N{green})!", client);
	}
	g_bIsPlayerLoaded[client] = true;
}

public void OnClientDisconnect(int client) {
	if (g_bIsPlayerLoaded[client])
		savePlayer(client);
}

public void savePlayer(int client) {
	PrintToServer("Saving... %N", client);
	g_bIsPlayerLoaded[client] = false;
	int Hp;
	if (IsPlayerAlive(client))
		Hp = GetClientHealth(client);
	else
		Hp = 0;
	
	int Armor;
	if (IsPlayerAlive(client))
		Armor = GetClientArmor(client);
	else
		Armor = 0;
	
	float Speed;
	if (IsPlayerAlive(client))
		Speed = GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue");
	else
		Speed = 1.0;
	
	float Gravity;
	if (IsPlayerAlive(client))
		Gravity = GetEntityGravity(client);
	else
		Gravity = 1.0;
	
	float Angles[3];
	if (IsPlayerAlive(client))
		GetClientAbsAngles(client, Angles);
	else
		Angles[2] = 0.0;
	
	float Position[3];
	if (IsPlayerAlive(client))
		GetClientAbsOrigin(client, Position);
	else {
		Position[0] = 0.0;
		Position[1] = 0.0;
		Position[2] = 0.0;
	}
	
	int weaponIndex;
	
	char primaryWeapon[64];
	int primaryWeaponAmmo;
	int primaryWeaponClip;
	if ((weaponIndex = GetPlayerWeaponSlot(client, 0)) != -1) {
		Entity_GetClassName(weaponIndex, primaryWeapon, sizeof(primaryWeapon));
		primaryWeaponClip = Weapon_GetPrimaryClip(weaponIndex);
		primaryWeaponAmmo = GetEntProp(weaponIndex, Prop_Send, "m_iPrimaryReserveAmmoCount");
		RemovePlayerItem(client, weaponIndex);
		RemoveEdict(weaponIndex);
	}
	
	char secondaryWeapon[64];
	int secondaryWeaponAmmo;
	int secondaryWeaponClip;
	if ((weaponIndex = GetPlayerWeaponSlot(client, 1)) != -1) {
		Entity_GetClassName(weaponIndex, secondaryWeapon, sizeof(secondaryWeapon));
		secondaryWeaponClip = Weapon_GetPrimaryClip(weaponIndex);
		secondaryWeaponAmmo = GetEntProp(weaponIndex, Prop_Send, "m_iPrimaryReserveAmmoCount");
		RemovePlayerItem(client, weaponIndex);
		RemoveEdict(weaponIndex);
	}
	
	
	char nades[64][64];
	int i = 0;
	for (int b = getClientHEGrenades(client); b > 0; b--)
	strcopy(nades[i++], 64, "weapon_hegrenade");
	for (int b = getClientSmokeGrenades(client); b > 0; b--)
	strcopy(nades[i++], 64, "weapon_smokegrenade");
	for (int b = getClientFlashbangs(client); b > 0; b--)
	strcopy(nades[i++], 64, "weapon_flashbang");
	for (int b = getClientDecoyGrenades(client); b > 0; b--)
	strcopy(nades[i++], 64, "weapon_decoy");
	for (int b = getClientIncendaryGrenades(client); b > 0; b--)
	strcopy(nades[i++], 64, "weapon_molotov");
	
	removeNades(client);
	
	char extern1[64];
	if (Client_HasWeapon(client, "weapon_taser"))
		strcopy(extern1, sizeof(extern1), "taser");
	else
		strcopy(extern1, sizeof(extern1), "");
	
	char extern2[64];
	if (GetEntProp(client, Prop_Send, "m_bHasHelmet") == 1)
		strcopy(extern2, sizeof(extern2), "helmet");
	else
		strcopy(extern2, sizeof(extern2), "");
	
	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char playername[MAX_NAME_LENGTH + 8];
	GetClientName(client, playername, sizeof(playername));
	
	char clean_playername[MAX_NAME_LENGTH * 2 + 16];
	SQL_EscapeString(g_DB, playername, clean_playername, sizeof(clean_playername));
	
	
	char deleteOldQuery[1024];
	Format(deleteOldQuery, sizeof(deleteOldQuery), "DELETE FROM t_rpg_playercontroller WHERE playerid = '%s' AND map = '%s';", playerid, mapName);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, deleteOldQuery);
	
	char insertDataQuery[4096];
	Format(insertDataQuery, sizeof(insertDataQuery), "INSERT INTO `t_rpg_playercontroller` (`Id`, `playername`, `playerid`, `timestamp`, `map`, `hp`, `armor`, `speed`, `gravity`, `angles`, `pos_x`, `pos_y`, `pos_z`, `primaryWeapon`, `primaryWeaponClip`, `primaryWeaponAmmo`, `secondaryWeapon`, `secondaryWeaponClip`, `secondaryWeaponAmmo`, `nade1`, `nade2`, `nade3`, `nade4`, `nade5`, `flags`, `extern1`, `extern2`, `extern3`) VALUES (NULL, '%s', '%s', CURRENT_TIMESTAMP, '%s', '%i', '%i', '%.2f', '%.2f', '%.2f', '%.2f', '%.2f', '%.2f', '%s', '%i', '%i', '%s', '%i', '%i', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s');", 
		clean_playername, playerid, mapName, Hp, Armor, Speed, Gravity, Angles[1], Position[0], Position[1], Position[2], primaryWeapon, primaryWeaponClip, primaryWeaponAmmo, secondaryWeapon, secondaryWeaponClip, secondaryWeaponAmmo, nades[0], nades[1], nades[2], nades[3], nades[4], "FLAGS", extern1, extern2, "EXTERN3");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, insertDataQuery);
	//PrintToServer("'%s', '%s', '%s', '%i', '%i', '%.2f', '%.2f', '%.2f', '%.2f', '%.2f', '%.2f', '%s', '%i', '%i', '%s', '%i', '%i', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s')", clean_playername, playerid, mapName, Hp, Armor, Speed, Gravity, Angles[1], Position[0], Position[1], Position[2], primaryWeapon, primaryWeaponClip, primaryWeaponAmmo, secondaryWeapon, secondaryWeaponClip, secondaryWeaponAmmo, nades[0], nades[1], nades[2], nades[3], nades[4], "FLAGS", "EXTERN1", "EXTERN2", "EXTERN3");
	//PrintToServer("Saved!");
}


public int getClientHEGrenades(int client) {
	return GetEntProp(client, Prop_Send, "m_iAmmo", _, CSGO_HEGRENADE_AMMO);
}

public int getClientSmokeGrenades(int client) {
	return GetEntProp(client, Prop_Send, "m_iAmmo", _, CSGO_SMOKE_AMMO);
}

public int getClientFlashbangs(int client) {
	return GetEntProp(client, Prop_Send, "m_iAmmo", _, CSGO_FLASH_AMMO);
}

public int getClientDecoyGrenades(int client) {
	return GetEntProp(client, Prop_Send, "m_iAmmo", _, DECOY_AMMO);
}

public int getClientIncendaryGrenades(int client) {
	return GetEntProp(client, Prop_Send, "m_iAmmo", _, INCENDERY_AND_MOLOTOV_AMMO);
}

public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, any data) {
	if (!StrEqual(error, ""))
		LogError(error);
}

public bool isValidClient(int client) {
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client))
		return false;
	
	return true;
}

public void OnMapEnd() {
	for (int i = 1; i < MAXPLAYERS; i++) {
		if (!isValidClient(i))
			continue;
		if (g_bIsPlayerLoaded[i])
			savePlayer(i);
	}
	g_bIsStarted = false;
}

public void OnMapStart() {
	ServerCommand("mp_restartgame 1");
	CreateTimer(10.0, restart);
}

public Action restart(Handle Timer) {
	ServerCommand("mp_restartgame 1");
	CreateTimer(5.0, reloadPlayers);
}

public Action reloadPlayers(Handle Timer) {
	for (int i = 1; i < MAXPLAYERS; i++) {
		if (!isValidClient(i))
			continue;
		loadPlayer(i);
	}
	g_bIsStarted = true;
	PrintToChatAll("[-T-] RP has been fully loaded");
	Call_StartForward(g_hOnGameStarted);
	Call_Finish();
}



public void SetServerConvars() {
	ConVar cvWinConditions = FindConVar("mp_ignore_round_win_conditions");
	ConVar mp_respawn_on_death_ct = FindConVar("mp_respawn_on_death_ct");
	ConVar mp_respawn_on_death_t = FindConVar("mp_respawn_on_death_t");
	ConVar sv_max_queries_sec = FindConVar("sv_max_queries_sec");
	ConVar mp_do_warmup_period = FindConVar("mp_do_warmup_period");
	ConVar mp_warmuptime = FindConVar("mp_warmuptime");
	ConVar mp_match_can_clinch = FindConVar("mp_match_can_clinch");
	ConVar mp_match_end_changelevel = FindConVar("mp_match_end_changelevel");
	ConVar mp_match_end_restart = FindConVar("mp_match_end_restart");
	ConVar mp_freezetime = FindConVar("mp_freezetime");
	ConVar mp_match_restart_delay = FindConVar("mp_match_restart_delay");
	ConVar mp_endmatch_votenextleveltime = FindConVar("mp_endmatch_votenextleveltime");
	ConVar mp_endmatch_votenextmap = FindConVar("mp_endmatch_votenextmap");
	ConVar mp_halftime = FindConVar("mp_halftime");
	ConVar bot_zombie = FindConVar("bot_zombie");
	ConVar sv_disable_immunity_alpha = FindConVar("sv_disable_immunity_alpha");
	ConVar mp_teammates_are_enemies = FindConVar("mp_teammates_are_enemies");
	ConVar mp_death_drop_gun = FindConVar("mp_death_drop_gun");
	ConVar sv_ladder_scale_speed = FindConVar("sv_ladder_scale_speed");
	ConVar g_hMaxRounds = FindConVar("mp_maxrounds");
	ConVar mp_round_restart_delay = FindConVar("mp_round_restart_delay");
	
	SetConVarBool(cvWinConditions, true);
	SetConVarInt(g_hMaxRounds, 1);
	SetConVarFloat(mp_freezetime, 0.0);
	
	ConVar mp_respawnwavetime_ct = FindConVar("mp_respawnwavetime_ct");
	ConVar mp_respawnwavetime_t = FindConVar("mp_respawnwavetime_t");
	SetConVarInt(mp_respawn_on_death_ct, 1);
	SetConVarInt(mp_respawn_on_death_t, 1);
	SetConVarFloat(mp_respawnwavetime_ct, 3.0);
	SetConVarFloat(mp_respawnwavetime_t, 3.0);
	
	SetConVarInt(sv_max_queries_sec, 6);
	SetConVarBool(mp_endmatch_votenextmap, false);
	SetConVarFloat(mp_warmuptime, 1.0);
	SetConVarBool(mp_match_can_clinch, false);
	SetConVarBool(mp_match_end_changelevel, false);
	SetConVarBool(mp_match_end_restart, false);
	SetConVarInt(mp_match_restart_delay, 1);
	SetConVarFloat(mp_endmatch_votenextleveltime, 1.0);
	
	SetConVarBool(mp_halftime, false);
	SetConVarBool(bot_zombie, true);
	SetConVarBool(mp_do_warmup_period, false);
	SetConVarBool(sv_disable_immunity_alpha, true);
	SetConVarBool(mp_teammates_are_enemies, true);
	SetConVarBool(mp_death_drop_gun, true);
	SetConVarFloat(sv_ladder_scale_speed, 1.0);
	SetConVarInt(mp_round_restart_delay, 0);
	ServerCommand("sm_cvar mp_tagging_scale 20");
	ServerCommand("mp_warmup_end");
	
	SetConVarBounds(FindConVar("mp_roundtime"), ConVarBound_Upper, true, 1501102101.0);
	
	ServerCommand("mp_roundtime 1501102101");
	
	ServerCommand("sm_cvar sm_voiceradius_live_distance 350");
}

int g_iaGrenadeOffsets[] =  { 15, 17, 16, 14, 18, 17 };

stock void removeNades(int client) {
	while (removeWeaponBySlot(client, 3)) {  }
	for (int i = 0; i < 6; i++)
	SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, g_iaGrenadeOffsets[i]);
}

stock bool removeWeaponBySlot(int client, int slot) {
	int entity = GetPlayerWeaponSlot(client, slot);
	if (IsValidEdict(entity)) {
		RemovePlayerItem(client, entity);
		AcceptEntityInput(entity, "Kill");
		return true;
	}
	return false;
}
