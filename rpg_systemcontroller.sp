#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <smlib>

#pragma newdecls required

//m_iAmmo array index
int HEGRENADE_AMMO = 11;
int FLASH_AMMO = 12;
int SMOKE_AMMO = 13;

//CS:GO ONLY
int INC_AMMO = 16;
int DECOY_AMMO = 17;

public Plugin myinfo = 
{
	name = "PlayerController for T-RP", 
	author = PLUGIN_AUTHOR, 
	description = "Saves General Player Properties", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

Database g_DB;
char dbconfig[] = "gsxh_multiroot";
bool g_bIsPlayerLoaded[MAXPLAYERS + 1];
bool g_bIsStarted = false;

public void OnPluginStart() {
	char error[255];
	g_DB = SQL_Connect(dbconfig, true, error, sizeof(error));
	SQL_SetCharset(g_DB, "utf8");
	
	/*
		Id	playername	playerid	timestamp	
		int	vchar		vchar		timestamp
	
		HP	Armor	Speed	Gravity	Angles(2)	Pos_x	Pos_y	Pos_z	primaryWeapon	primaryWeaponClip	primaryWeaponAmmo		
		int	int		float	float	float		float	float	float	vchar			int					int
		
		secondaryWeapon	secondaryWeaponClip	secondaryWeaponAmmo	nade1	nade2	nade3	nade4	nade5	flags	extern	extern2	extern3
		vchar			int					int					vchar	vchar	vchar	vchar	vchar	vchar	vchar	vchar	extern3
	*/
	char createTableQuery[8096];
	Format(createTableQuery, sizeof(createTableQuery), "CREATE TABLE IF NOT EXISTS t_rpg_playercontroller (`Id`BIGINT NULL DEFAULT NULL AUTO_INCREMENT, `playername`VARCHAR(64)CHARACTER SET utf8 COLLATE utf8_bin NOT NULL, `playerid`VARCHAR(20)NOT NULL, `timestamp`TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, `map`VARCHAR(64)CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,`hp`INT NOT NULL, `armor`INT NOT NULL, `speed`FLOAT NOT NULL, `gravity`FLOAT NOT NULL, `angles`FLOAT NOT NULL, `pos_x`FLOAT NOT NULL, `pos_y`FLOAT NOT NULL, `pos_z`FLOAT NOT NULL, `primaryWeapon`VARCHAR(64)NOT NULL, `primaryWeaponClip`INT NOT NULL, `primaryWeaponAmmo`INT NOT NULL, `secondaryWeapon`VARCHAR(64)NOT NULL, `secondaryWeaponClip`INT NOT NULL, `secondaryWeaponAmmo`INT NOT NULL, `nade1`VARCHAR(64)NOT NULL, `nade2`VARCHAR(64)NOT NULL, `nade3`VARCHAR(64)NOT NULL, `nade4`VARCHAR(64)NOT NULL, `nade5`VARCHAR(64)NOT NULL, `flags`VARCHAR(8)NOT NULL, `extern1`VARCHAR(128)NOT NULL, `extern2`VARCHAR(128)NOT NULL, `extern3`VARCHAR(128)NOT NULL, PRIMARY KEY(`Id`), UNIQUE(`playerid`))ENGINE = InnoDB CHARSET = utf8 COLLATE utf8_bin; ");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createTableQuery);
	
	HookEvent("player_spawn", onPlayerSpawn, EventHookMode_Post);
	HookEvent("round_start", onRoundStart, EventHookMode_Post);
	HookEvent("round_end", onRoundEnd, EventHookMode_Post);
	
	RegConsoleCmd("sm_loaded", amILoaded, "shows if loaded");
	
	SetServerConvars();
}

public Action amILoaded(int client, int args) {
	PrintToChat(client, "Loaded: %d | Started: %d", g_bIsPlayerLoaded[client], g_bIsStarted);
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
	for (int i = 1; i < MAXPLAYERS; i++) {
		if (!isValidClient(i))
			continue;
		if (g_bIsPlayerLoaded[i])
			continue;
		
		loadPlayer(i);
	}
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
	PrintToChat(client, "Loading...");
	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char loadQueryString[1024];
	Format(loadQueryString, sizeof(loadQueryString), "SELECT * FROM t_rpg_playercontroller WHERE playerid = '%s' AND map = '%s';", playerid, mapName);
	SQL_TQuery(g_DB, SQLLoadPlayerCallback, loadQueryString, client);
}

public void SQLLoadPlayerCallback(Handle owner, Handle hndl, const char[] error, any data) {
	int client = data;
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
		
		if (Hp != 0)
			SetEntityHealth(client, Hp);
		if (Armor != 0)
			SetEntProp(client, Prop_Data, "m_ArmorValue", Armor, 1);
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", Speed);
		SetEntityGravity(client, Gravity);
		TeleportEntity(client, Position, Angles, NULL_VECTOR);
		if (!StrEqual(primaryWeapon, "")) {
			GivePlayerItem(client, primaryWeapon);
			Client_SetWeaponAmmo(client, secondaryWeapon, primaryWeaponAmmo, _, primaryWeaponClip, _);
		}
		if (!StrEqual(secondaryWeapon, "")) {
			GivePlayerItem(client, secondaryWeapon);
			Client_SetWeaponAmmo(client, secondaryWeapon, secondaryWeaponAmmo, _, secondaryWeaponClip, _);
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
		PrintToChat(client, "Loaded!");
		g_bIsPlayerLoaded[client] = true;
	}
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
		primaryWeaponAmmo = Weapon_GetSecondaryClip(weaponIndex);
		RemovePlayerItem(client, weaponIndex);
		RemoveEdict(weaponIndex);
	}
	
	char secondaryWeapon[64];
	int secondaryWeaponAmmo;
	int secondaryWeaponClip;
	if ((weaponIndex = GetPlayerWeaponSlot(client, 1)) != -1) {
		Entity_GetClassName(weaponIndex, secondaryWeapon, sizeof(secondaryWeapon));
		secondaryWeaponClip = Weapon_GetPrimaryClip(weaponIndex);
		secondaryWeaponAmmo = Weapon_GetSecondaryClip(weaponIndex);
		RemovePlayerItem(client, weaponIndex);
		RemoveEdict(weaponIndex);
	}
	
	char nades[5][64];
	int i = 0;
	for (; i < getClientHEGrenades(client); i++)
	strcopy(nades[i], 64, "weapon_hegrenade");
	for (; i < getClientSmokeGrenades(client); i++)
	strcopy(nades[i], 64, "weapon_smokegrenade");
	for (; i < getClientFlashbangs(client); i++)
	strcopy(nades[i], 64, "weapon_flashbang");
	for (; i < getClientDecoyGrenades(client); i++)
	strcopy(nades[i], 64, "weapon_decoy");
	for (; i < getClientIncendaryGrenades(client); i++)
	strcopy(nades[i], 64, "weapon_molotov");
	
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
		clean_playername, playerid, mapName, Hp, Armor, Speed, Gravity, Angles[1], Position[0], Position[1], Position[2], primaryWeapon, primaryWeaponClip, primaryWeaponAmmo, secondaryWeapon, secondaryWeaponClip, secondaryWeaponAmmo, nades[0], nades[1], nades[2], nades[3], nades[4], "FLAGS", "EXTERN1", "EXTERN2", "EXTERN3");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, insertDataQuery);
	PrintToServer("'%s', '%s', '%s', '%i', '%i', '%.2f', '%.2f', '%.2f', '%.2f', '%.2f', '%.2f', '%s', '%i', '%i', '%s', '%i', '%i', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s')", clean_playername, playerid, mapName, Hp, Armor, Speed, Gravity, Angles[1], Position[0], Position[1], Position[2], primaryWeapon, primaryWeaponClip, primaryWeaponAmmo, secondaryWeapon, secondaryWeaponClip, secondaryWeaponAmmo, nades[0], nades[1], nades[2], nades[3], nades[4], "FLAGS", "EXTERN1", "EXTERN2", "EXTERN3");
	PrintToServer("Saved!");
}

public int getClientHEGrenades(int client) {
	return GetEntProp(client, Prop_Data, "m_iAmmo", _, HEGRENADE_AMMO);
}

public int getClientSmokeGrenades(int client) {
	return GetEntProp(client, Prop_Data, "m_iAmmo", _, SMOKE_AMMO);
}

public int getClientFlashbangs(int client) {
	return GetEntProp(client, Prop_Data, "m_iAmmo", _, FLASH_AMMO);
}

public int getClientDecoyGrenades(int client) {
	return GetEntProp(client, Prop_Data, "m_iAmmo", _, DECOY_AMMO);
}

public int getClientIncendaryGrenades(int client) {
	return GetEntProp(client, Prop_Data, "m_iAmmo", _, INC_AMMO);
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
	
	SetConVarBounds(FindConVar("mp_roundtime"), ConVarBound_Upper, true, 1501102101.0);
	
	ServerCommand("mp_roundtime 1501102101");
}