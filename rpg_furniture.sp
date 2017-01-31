#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <rpg_apartments>
#include <rpg_npc_core>
#include <rpg_inventory_core>
#include <tConomy>
#include <smlib>
#include <devzones>

#pragma newdecls required


#define MAX_FURNITURE 1024

enum LoadedFurniture {
	lfId, 
	bool:lfActive, 
	String:lfName[64], 
	String:lfModelPath[128], 
	String:lfBuff[64], 
	Float:lfSize, 
	lfPrice, 
	String:lfFlags[8]
}

int LoadedFurnitureItems[MAX_FURNITURE][LoadedFurniture];
int g_iLoadedFurniture;

int g_iPlayerPrevButtons[MAXPLAYERS + 1];
char activeZone[MAXPLAYERS + 1][128];
int g_iLastInteractedWith[MAXPLAYERS + 1];

char dbconfig[] = "gsxh_multiroot";
Database g_DB;

char npctype[128] = "Furniture Vendor";

enum EditItem {
	eiRef, 
	String:eiUniqueId[64], 
	bool:eiEditing, 
	bool:eiInAdmin
}

int PlayerEditItems[MAXPLAYERS + 1][EditItem];


public Plugin myinfo = 
{
	name = "Furniture for Apartments in T-RP", 
	author = PLUGIN_AUTHOR, 
	description = "Adds Furniture to Apartments in T-RP", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart() {
	//RegConsoleCmd("sm_furniture", openFurnitureMenu, "Opens the Furniture Menu");
	RegAdminCmd("sm_reloadfurniture", cmdReloadFurniture, ADMFLAG_ROOT, "Reload the Furniture");
	RegConsoleCmd("sm_builder", cmdBuild, "Edits Furniture");
	RegAdminCmd("sm_abuilder", cmdAdminBuilder, ADMFLAG_ROOT, "Opens the Admin Builder Menu");
	
	HookEvent("round_start", onRoundStart);
	
	char error[255];
	g_DB = SQL_Connect(dbconfig, true, error, sizeof(error));
	SQL_SetCharset(g_DB, "utf8");
	
	char createTableQuery[4096];
	Format(createTableQuery, sizeof(createTableQuery), "CREATE TABLE IF NOT EXISTS t_rpg_furniture ( `Id` BIGINT NOT NULL AUTO_INCREMENT , `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , `playername` VARCHAR(40) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL , `playerid` VARCHAR(20) NOT NULL, `uniqueId` VARCHAR(64) NOT NULL, `map` VARCHAR(64) NOT NULL , `name` VARCHAR(64) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL , `model` VARCHAR(128) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL , `price` INT NOT NULL , `pos_x` FLOAT NOT NULL , `pos_y` FLOAT NOT NULL , `pos_z` FLOAT NOT NULL , `angle_x` FLOAT NOT NULL , `angle_y` FLOAT NOT NULL , `angle_z` FLOAT NOT NULL , PRIMARY KEY (`Id`)) ENGINE = InnoDB CHARSET=utf8 COLLATE utf8_bin;");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createTableQuery);
}

public void OnMapStart() {
	npc_registerNpcType(npctype);
	inventory_addItemHandle("Furniture", 4);
	inventory_addItemHandle("Apartment", 4);
	loadFurniture();
}

public void clearAllLoadedFurniture() {
	g_iLoadedFurniture = 0;
	for (int i = 0; i < MAX_FURNITURE; i++)
	clearLoadedFurniture(i);
}

public void clearLoadedFurniture(int id) {
	LoadedFurnitureItems[id][lfActive] = false;
	strcopy(LoadedFurnitureItems[id][lfName], 64, "");
	strcopy(LoadedFurnitureItems[id][lfModelPath], 128, "");
	strcopy(LoadedFurnitureItems[id][lfFlags], 8, "");
	strcopy(LoadedFurnitureItems[id][lfBuff], 64, "");
	LoadedFurnitureItems[id][lfSize] = -1.0;
	LoadedFurnitureItems[id][lfPrice] = -1;
	LoadedFurnitureItems[id][lfId] = -1;
}

public bool loadFurniture() {
	clearAllLoadedFurniture();
	
	KeyValues kv = new KeyValues("rpg_furniture");
	kv.ImportFromFile("addons/sourcemod/configs/rpg_furniture.txt");
	
	if (!kv.GotoFirstSubKey())
		return false;
	
	
	char buffer[64];
	do
	{
		kv.GetSectionName(buffer, sizeof(buffer));
		strcopy(LoadedFurnitureItems[g_iLoadedFurniture][lfName], 64, buffer);
		
		char tempVars[64];
		kv.GetString("model", tempVars, 64);
		strcopy(LoadedFurnitureItems[g_iLoadedFurniture][lfModelPath], 128, tempVars);
		PrecacheModel(tempVars, true);
		
		kv.GetString("size", tempVars, 64);
		LoadedFurnitureItems[g_iLoadedFurniture][lfSize] = StringToFloat(tempVars);
		
		kv.GetString("price", tempVars, 64);
		LoadedFurnitureItems[g_iLoadedFurniture][lfPrice] = StringToInt(tempVars);
		
		kv.GetString("flags", tempVars, 64);
		strcopy(LoadedFurnitureItems[g_iLoadedFurniture][lfFlags], 8, tempVars);
		
		kv.GetString("buff", tempVars, 64);
		strcopy(LoadedFurnitureItems[g_iLoadedFurniture][lfBuff], 64, tempVars);
		
		LoadedFurnitureItems[g_iLoadedFurniture][lfActive] = true;
		
		LoadedFurnitureItems[g_iLoadedFurniture][lfId] = g_iLoadedFurniture;
		g_iLoadedFurniture++;
		
	} while (kv.GotoNextKey());
	
	delete kv;
	return true;
}

public Action cmdReloadFurniture(int client, int args) {
	loadFurniture();
	PrintToChat(client, "Loaded %i Furnitures", g_iLoadedFurniture);
	return Plugin_Handled;
}

public void openFurnitureMenu(int client) {
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
	
	Handle menu = CreateMenu(furnitureMenuHandler);
	char menuTitle[128];
	Format(menuTitle, sizeof(menuTitle), "Loaded Furniture (%i)", g_iLoadedFurniture);
	SetMenuTitle(menu, menuTitle);
	for (int i = 0; i < g_iLoadedFurniture; i++) {
		char cId[8];
		IntToString(i, cId, sizeof(cId));
		AddMenuItem(menu, cId, LoadedFurnitureItems[i][lfName]);
	}
	DisplayMenu(menu, client, 60);
}

public int furnitureMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char info[8];
		GetMenuItem(menu, item, info, sizeof(info));
		int id = StringToInt(info);
		Handle menu2 = CreateMenu(furnitureItemMenuHandler);
		SetMenuTitle(menu2, LoadedFurnitureItems[id][lfName]);
		char display[64];
		Format(display, sizeof(display), "Model: %s", LoadedFurnitureItems[id][lfModelPath]);
		AddMenuItem(menu2, "x", display, ITEMDRAW_DISABLED);
		Format(display, sizeof(display), "Price: %i", LoadedFurnitureItems[id][lfPrice]);
		AddMenuItem(menu2, "x", display, ITEMDRAW_DISABLED);
		Format(display, sizeof(display), "Size: %.2f", LoadedFurnitureItems[id][lfSize]);
		AddMenuItem(menu2, "x", display, ITEMDRAW_DISABLED);
		Format(display, sizeof(display), "Buff: %s", LoadedFurnitureItems[id][lfBuff]);
		AddMenuItem(menu2, "x", display, ITEMDRAW_DISABLED);
		Format(display, sizeof(display), "Flags: %s", LoadedFurnitureItems[id][lfBuff]);
		AddMenuItem(menu2, "x", display, ITEMDRAW_DISABLED);
		AddMenuItem(menu2, info, "Buy");
		DisplayMenu(menu2, client, 60);
	}
	if (action == MenuAction_Cancel) {
		if (isValidClient(client))
			cmdReloadFurniture(client, 0);
	}
}

public int furnitureItemMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char info[8];
		GetMenuItem(menu, item, info, sizeof(info));
		int id = StringToInt(info);
		char itemName[128];
		strcopy(itemName, sizeof(itemName), LoadedFurnitureItems[id][lfName]);
		
		if (tConomy_getCurrency(client) >= LoadedFurnitureItems[id][lfPrice]) {
			char reason[256];
			Format(reason, sizeof(reason), "Bought %s", LoadedFurnitureItems[id][lfName]);
			tConomy_removeCurrency(client, LoadedFurnitureItems[id][lfPrice], reason);
			inventory_givePlayerItem(client, itemName, 100, "", "Furniture", "Apartment Stuff", 0, reason);
		}
		
	}
}

public void inventory_onItemUsed(int client, char itemname[128], int weight, char category[64], char category2[64], int rarity, char timestamp[64]) {
	if (!StrEqual(category, "Furniture"))
		return;
	int id;
	char itemName2[64];
	strcopy(itemName2, sizeof(itemName2), itemname);
	if ((id = getLoadedIdByName(itemName2)) == -1)
		return;
	
	firstSpawnFurniture(client, id);
}

public void firstSpawnFurniture(int client, int id) {
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	float pos[3];
	pos = GetAimOrigin(client);
	
	float angles[3];
	angles[0] = 0.0;
	angles[1] = 0.0;
	angles[2] = 0.0;
	
	float clientPos[3];
	GetClientAbsOrigin(client, clientPos);
	if (GetVectorDistance(clientPos, pos) > 400.0) {
		PrintToChat(client, "[-T-] Too far away...");
		return;
	}
	
	if (Zone_CheckIfZoneExists(activeZone[client], true, true)) {
		if (Zone_isPositionInZone(activeZone[client], pos[0], pos[1], pos[2])) {
			if (apartments_isClientOwner(client, activeZone[client])) {
				// Hurra!
			} else {
				PrintToChat(client, "[-T-] You do not own this Apartment");
				return;
			}
		} else {
			PrintToChat(client, "[-T-] Not in your Apartment");
			return;
		}
	} else {
		PrintToChat(client, "[-T-] Not an Apartment");
		return;
	}
	
	char uniqueId[64];
	Format(uniqueId, sizeof(uniqueId), "%i %s %i", id, playerid, GetTime());
	char playername[MAX_NAME_LENGTH + 8];
	GetClientName(client, playername, sizeof(playername));
	char clean_playername[MAX_NAME_LENGTH * 2 + 16];
	SQL_EscapeString(g_DB, playername, clean_playername, sizeof(clean_playername));
	
	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	
	if (!spawnFurniture(id, playerid, pos, angles, uniqueId))
		return;
	
	char addFurnitureQuery[2048];
	Format(addFurnitureQuery, sizeof(addFurnitureQuery), "INSERT IGNORE INTO `t_rpg_furniture`(`Id`, `timestamp`, `playername`, `playerid`, `uniqueId`, `map`, `name`, `model`, `price`, `pos_x`, `pos_y`, `pos_z`, `angle_x`, `angle_y`, `angle_z`)VALUES(NULL, CURRENT_TIMESTAMP, '%s', '%s', '%s', '%s', '%s', '%s', '%i', '%.2f', '%.2f', '%.2f', '%.2f', '%.2f', '%.2f');", clean_playername, playerid, uniqueId, mapName, LoadedFurnitureItems[id][lfName], LoadedFurnitureItems[id][lfModelPath], LoadedFurnitureItems[id][lfPrice], pos[0], pos[1], pos[2], angles[0], angles[1], angles[2]);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, addFurnitureQuery);
	
	char itemName2[128];
	strcopy(itemName2, sizeof(itemName2), LoadedFurnitureItems[id][lfName]);
	
	DataPack dp = CreateDataPack();
	ResetPack(dp, true);
	WritePackCell(dp, GetClientUserId(client));
	WritePackString(dp, itemName2);
	WritePackCell(dp, 1);
	WritePackString(dp, "Placed Item");
	
	CreateTimer(0.1, removeItemDelayed, dp);
}

public Action removeItemDelayed(Handle Timer, any data) {
	int client;
	char itemName[128];
	int amount;
	char reason[256];
	ResetPack(data);
	client = GetClientOfUserId(ReadPackCell(data));
	ReadPackString(data, itemName, sizeof(itemName));
	amount = ReadPackCell(data);
	ReadPackString(data, reason, sizeof(reason));
	CloseHandle(data);
	
	inventory_removePlayerItems(client, itemName, amount, reason);
}

public bool spawnFurniture(int id, char playerid[20], float pos[3], float angles[3], char uniqueId[64]) {
	int furnitureEnt = CreateEntityByName("prop_dynamic_override");
	if (furnitureEnt == -1)
		return false;
	char modelPath[128];
	Format(modelPath, sizeof(modelPath), LoadedFurnitureItems[id][lfModelPath]);
	SetEntityModel(furnitureEnt, modelPath);
	DispatchKeyValue(furnitureEnt, "Solid", "6");
	SetEntProp(furnitureEnt, Prop_Send, "m_nSolidType", 6);
	SetEntProp(furnitureEnt, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_PUSHAWAY);
	
	SetEntPropString(furnitureEnt, Prop_Data, "m_iName", uniqueId);
	DispatchSpawn(furnitureEnt);
	
	TeleportEntity(furnitureEnt, pos, angles, NULL_VECTOR);
	Entity_SetGlobalName(furnitureEnt, LoadedFurnitureItems[id][lfName]);
	return true;
}

stock float[3] GetAimOrigin(int client) {
	float vAngles[3];
	float fOrigin[3];
	float hOrigin[3];
	GetClientEyePosition(client, fOrigin);
	GetClientEyeAngles(client, vAngles);
	
	Handle trace = TR_TraceRayFilterEx(fOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
	
	if (TR_DidHit(trace))
	{
		TR_GetEndPosition(hOrigin, trace);
		CloseHandle(trace);
		return hOrigin;
	}
	
	CloseHandle(trace);
	return hOrigin;
}

public void OnClientPostAdminCheck(int client) {
	PlayerEditItems[client][eiRef] = -1;
	strcopy(activeZone[client], sizeof(activeZone), "");
	PlayerEditItems[client][eiInAdmin] = false;
}

public Action cmdBuild(int client, int args) {
	PlayerEditItems[client][eiInAdmin] = false;
	int id;
	if ((id = GetClientAimTarget(client, false)) < 0) {
		PrintToChat(client, "[-T-] Invalid Item");
		return Plugin_Handled;
	}
	
	char entName[64];
	Entity_GetGlobalName(id, entName, sizeof(entName));
	
	char uniqueId[64];
	GetEntPropString(id, Prop_Data, "m_iName", uniqueId, sizeof(uniqueId));
	
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	if (StrContains(uniqueId, playerid) < 2) {
		PrintToChat(client, "[-T-] You do not own that Item.");
		return Plugin_Handled;
	}
	
	Menu buildMenu = CreateMenu(buildMenuHandler);
	SetMenuTitle(buildMenu, "Modify Furniture (keep Aiming at the Item!)");
	AddMenuItem(buildMenu, "edit", "Edit Position");
	AddMenuItem(buildMenu, "stash", "Put Furniture in Inventory");
	AddMenuItem(buildMenu, "delete", "Delete Furniture");
	DisplayMenu(buildMenu, client, 60);
	
	return Plugin_Handled;
}

public int buildMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		
		int id;
		if ((id = GetClientAimTarget(client, false)) < 0) {
			PrintToChat(client, "[-T-] Invalid Item");
			return 0;
		}
		char entName[64];
		Entity_GetGlobalName(id, entName, sizeof(entName));
		
		char uniqueId[64];
		GetEntPropString(id, Prop_Data, "m_iName", uniqueId, sizeof(uniqueId));
		
		char playerid[20];
		GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
		
		char globalName[128];
		Entity_GetGlobalName(id, globalName, sizeof(globalName));
		
		if (StrContains(uniqueId, playerid) < 2) {
			PrintToChat(client, "[-T-] You do not own that Item.");
			return 0;
		}
		
		if (StrEqual(cValue, "edit")) {
			strcopy(PlayerEditItems[client][eiUniqueId], 64, uniqueId);
			PlayerEditItems[client][eiRef] = EntIndexToEntRef(id);
			PlayerEditItems[client][eiEditing] = true;
			PlayerEditItems[client][eiInAdmin] = false;
			
			PrintToChat(client, "[-T-] Now editing %s", entName);
			PrintToChat(client, "[-T-] Hold R for Placement, A & D for Angles JUMP for up, Crouch for down and E to Exit");
			SetEntityMoveType(client, MOVETYPE_NONE);
		} else if (StrEqual(cValue, "stash")) {
			char mapName[128];
			GetCurrentMap(mapName, sizeof(mapName));
			
			char updateFurnitureQuery[256];
			Format(updateFurnitureQuery, sizeof(updateFurnitureQuery), "DELETE FROM t_rpg_furniture WHERE map = '%s' AND uniqueId = '%s';", mapName, uniqueId);
			SQL_TQuery(g_DB, SQLErrorCheckCallback, updateFurnitureQuery);
			
			AcceptEntityInput(id, "kill");
			inventory_givePlayerItem(client, globalName, 100, "", "Furniture", "Apartment Stuff", 1, "Stashed Furniture");
		} else if (StrEqual(cValue, "delete")) {
			char mapName[128];
			GetCurrentMap(mapName, sizeof(mapName));
			
			char updateFurnitureQuery[256];
			Format(updateFurnitureQuery, sizeof(updateFurnitureQuery), "DELETE FROM t_rpg_furniture WHERE map = '%s' AND uniqueId = '%s';", mapName, uniqueId);
			SQL_TQuery(g_DB, SQLErrorCheckCallback, updateFurnitureQuery);
			
			AcceptEntityInput(id, "kill");
			PrintToChat(client, "[-T-] Deleted %s", globalName);
		}
	}
	return 1;
}

public Action cmdAdminBuilder(int client, int args) {
	PlayerEditItems[client][eiInAdmin] = true;
	int id;
	if ((id = GetClientAimTarget(client, false)) < 0) {
		PrintToChat(client, "[-T-] Invalid Item");
		return Plugin_Handled;
	}
	
	char entName[64];
	Entity_GetGlobalName(id, entName, sizeof(entName));
	
	char uniqueId[64];
	GetEntPropString(id, Prop_Data, "m_iName", uniqueId, sizeof(uniqueId));
	
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	Menu buildMenu = CreateMenu(adminBuildMenuHandler);
	SetMenuTitle(buildMenu, "Modify Furniture (keep Aiming at the Item!)");
	AddMenuItem(buildMenu, "edit", "Edit Position");
	AddMenuItem(buildMenu, "stash", "Put Furniture in Inventory");
	AddMenuItem(buildMenu, "delete", "Delete Furniture");
	DisplayMenu(buildMenu, client, 60);
	
	return Plugin_Handled;
}

public int adminBuildMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		
		int id;
		if ((id = GetClientAimTarget(client, false)) < 0) {
			PrintToChat(client, "[-T-] Invalid Item");
			return 0;
		}
		char entName[64];
		Entity_GetGlobalName(id, entName, sizeof(entName));
		
		char uniqueId[64];
		GetEntPropString(id, Prop_Data, "m_iName", uniqueId, sizeof(uniqueId));
		
		char playerid[20];
		GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
		
		char globalName[128];
		Entity_GetGlobalName(id, globalName, sizeof(globalName));
		
		if (StrEqual(cValue, "edit")) {
			strcopy(PlayerEditItems[client][eiUniqueId], 64, uniqueId);
			PlayerEditItems[client][eiRef] = EntIndexToEntRef(id);
			PlayerEditItems[client][eiEditing] = true;
			PlayerEditItems[client][eiInAdmin] = true;
			PrintToChat(client, "[-T-] Now editing %s", entName);
			PrintToChat(client, "[-T-] Hold R for Placement, A & D for Angles JUMP for up, Crouch for down and E to Exit");
			SetEntityMoveType(client, MOVETYPE_NONE);
		} else if (StrEqual(cValue, "stash")) {
			char mapName[128];
			GetCurrentMap(mapName, sizeof(mapName));
			
			char updateFurnitureQuery[256];
			Format(updateFurnitureQuery, sizeof(updateFurnitureQuery), "DELETE FROM t_rpg_furniture WHERE map = '%s' AND uniqueId = '%s';", mapName, uniqueId);
			SQL_TQuery(g_DB, SQLErrorCheckCallback, updateFurnitureQuery);
			
			AcceptEntityInput(id, "kill");
			inventory_givePlayerItem(client, globalName, 100, "", "Furniture", "Apartment Stuff", 1, "Stashed Furniture");
		} else if (StrEqual(cValue, "delete")) {
			char mapName[128];
			GetCurrentMap(mapName, sizeof(mapName));
			
			char updateFurnitureQuery[256];
			Format(updateFurnitureQuery, sizeof(updateFurnitureQuery), "DELETE FROM t_rpg_furniture WHERE map = '%s' AND uniqueId = '%s';", mapName, uniqueId);
			SQL_TQuery(g_DB, SQLErrorCheckCallback, updateFurnitureQuery);
			
			AcceptEntityInput(id, "kill");
			PrintToChat(client, "[-T-] Deleted %s", globalName);
		}
	}
	return 1;
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon, int &tickcount) {
	if (IsClientInGame(client) && IsPlayerAlive(client)) {
		if (PlayerEditItems[client][eiEditing]) {
			if (!(g_iPlayerPrevButtons[client] & IN_USE) && iButtons & IN_USE) {
				char uId[64];
				strcopy(uId, sizeof(uId), PlayerEditItems[client][eiUniqueId]);
				updateFurnitureToMySQL(EntRefToEntIndex(PlayerEditItems[client][eiRef]), uId);
				PlayerEditItems[client][eiRef] = -1;
				PlayerEditItems[client][eiEditing] = false;
				strcopy(PlayerEditItems[client][eiUniqueId], 64, "");
				PrintToChat(client, "[-T-] Finished Editing");
				SetEntityMoveType(client, MOVETYPE_WALK);
			}
			if (!(g_iPlayerPrevButtons[client] & IN_JUMP) && iButtons & IN_JUMP) {
				int ent = EntRefToEntIndex(PlayerEditItems[client][eiRef]);
				float pos[3];
				GetEntPropVector(ent, Prop_Data, "m_vecOrigin", pos);
				pos[2] += 1;
				float clientPos[3];
				GetClientAbsOrigin(client, clientPos);
				if ((GetVectorDistance(clientPos, pos) > 400.0) && !PlayerEditItems[client][eiInAdmin])
					PrintToChat(client, "[-T-] Too far away...");
				
				if (Zone_CheckIfZoneExists(activeZone[client], true, true) || PlayerEditItems[client][eiInAdmin]) {
					if (Zone_isPositionInZone(activeZone[client], pos[0], pos[1], pos[2]) || PlayerEditItems[client][eiInAdmin]) {
						if (apartments_isClientOwner(client, activeZone[client]) || PlayerEditItems[client][eiInAdmin]) {
							TeleportEntity(ent, pos, NULL_VECTOR, NULL_VECTOR);
						} else {
							PrintToChat(client, "[-T-] You do not own this Apartment");
						}
					} else {
						PrintToChat(client, "[-T-] Not in your Apartment");
					}
				} else {
					PrintToChat(client, "[-T-] Not an Apartment");
				}
				
				iButtons ^= IN_JUMP;
				return Plugin_Changed;
			}
			if (!(g_iPlayerPrevButtons[client] & IN_DUCK) && iButtons & IN_DUCK) {
				int ent = EntRefToEntIndex(PlayerEditItems[client][eiRef]);
				float pos[3];
				GetEntPropVector(ent, Prop_Data, "m_vecOrigin", pos);
				pos[2] -= 1;
				float clientPos[3];
				GetClientAbsOrigin(client, clientPos);
				if ((GetVectorDistance(clientPos, pos) > 400.0) && !PlayerEditItems[client][eiInAdmin])
					PrintToChat(client, "[-T-] Too far away...");
				
				if (Zone_CheckIfZoneExists(activeZone[client], true, true) || PlayerEditItems[client][eiInAdmin]) {
					if (Zone_isPositionInZone(activeZone[client], pos[0], pos[1], pos[2]) || PlayerEditItems[client][eiInAdmin]) {
						if (apartments_isClientOwner(client, activeZone[client]) || PlayerEditItems[client][eiInAdmin]) {
							TeleportEntity(ent, pos, NULL_VECTOR, NULL_VECTOR);
						} else {
							PrintToChat(client, "[-T-] You do not own this Apartment");
						}
					} else {
						PrintToChat(client, "[-T-] Not in your Apartment");
					}
				} else {
					PrintToChat(client, "[-T-] Not an Apartment");
				}
				
				iButtons ^= IN_DUCK;
				return Plugin_Changed;
			}
			if (!(g_iPlayerPrevButtons[client] & IN_RELOAD) && iButtons & IN_RELOAD) {
				int ent = EntRefToEntIndex(PlayerEditItems[client][eiRef]);
				float pos[3];
				pos = GetAimOrigin(client);
				float clientPos[3];
				GetClientAbsOrigin(client, clientPos);
				if ((GetVectorDistance(clientPos, pos) > 400.0) && !PlayerEditItems[client][eiInAdmin])
					PrintToChat(client, "[-T-] Too far away...");
				
				if (Zone_CheckIfZoneExists(activeZone[client], true, true) || PlayerEditItems[client][eiInAdmin]) {
					if (Zone_isPositionInZone(activeZone[client], pos[0], pos[1], pos[2]) || PlayerEditItems[client][eiInAdmin]) {
						if (apartments_isClientOwner(client, activeZone[client]) || PlayerEditItems[client][eiInAdmin]) {
							TeleportEntity(ent, pos, NULL_VECTOR, NULL_VECTOR);
						} else {
							PrintToChat(client, "[-T-] You do not own this Apartment");
						}
					} else {
						PrintToChat(client, "[-T-] Not in your Apartment");
					}
				} else {
					PrintToChat(client, "[-T-] Not an Apartment");
				}
				
				iButtons ^= IN_RELOAD;
				return Plugin_Changed;
			}
			if (!(g_iPlayerPrevButtons[client] & IN_MOVELEFT) && iButtons & IN_MOVELEFT) {
				int ent = EntRefToEntIndex(PlayerEditItems[client][eiRef]);
				float angles[3];
				GetEntPropVector(ent, Prop_Data, "m_angRotation", angles);
				angles[1] += 1;
				TeleportEntity(ent, NULL_VECTOR, angles, NULL_VECTOR);
				iButtons &= ~IN_MOVELEFT;
				iButtons &= IN_MOVERIGHT;
				return Plugin_Changed;
			}
			if (!(g_iPlayerPrevButtons[client] & IN_MOVERIGHT) && iButtons & IN_MOVERIGHT) {
				int ent = EntRefToEntIndex(PlayerEditItems[client][eiRef]);
				float angles[3];
				GetEntPropVector(ent, Prop_Data, "m_angRotation", angles);
				angles[1] -= 1;
				TeleportEntity(ent, NULL_VECTOR, angles, NULL_VECTOR);
				iButtons &= ~IN_MOVERIGHT;
				iButtons &= IN_MOVELEFT;
				return Plugin_Changed;
			}
		}
		g_iPlayerPrevButtons[client] = iButtons;
	}
	return Plugin_Continue;
}

public void updateFurnitureToMySQL(int index, char uniqueId[64]) {
	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	
	float pos[3];
	GetEntPropVector(index, Prop_Data, "m_vecOrigin", pos);
	float angles[3];
	GetEntPropVector(index, Prop_Data, "m_angRotation", angles);
	
	char updateFurnitureQuery[256];
	Format(updateFurnitureQuery, sizeof(updateFurnitureQuery), "UPDATE t_rpg_furniture SET pos_x = %.2f WHERE map = '%s' AND uniqueId = '%s';", pos[0], mapName, uniqueId);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateFurnitureQuery);
	Format(updateFurnitureQuery, sizeof(updateFurnitureQuery), "UPDATE t_rpg_furniture SET pos_y = %.2f WHERE map = '%s' AND uniqueId = '%s';", pos[1], mapName, uniqueId);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateFurnitureQuery);
	Format(updateFurnitureQuery, sizeof(updateFurnitureQuery), "UPDATE t_rpg_furniture SET pos_z = %.2f WHERE map = '%s' AND uniqueId = '%s';", pos[2], mapName, uniqueId);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateFurnitureQuery);
	Format(updateFurnitureQuery, sizeof(updateFurnitureQuery), "UPDATE t_rpg_furniture SET angle_x = %.2f WHERE map = '%s' AND uniqueId = '%s';", angles[0], mapName, uniqueId);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateFurnitureQuery);
	Format(updateFurnitureQuery, sizeof(updateFurnitureQuery), "UPDATE t_rpg_furniture SET angle_y = %.2f WHERE map = '%s' AND uniqueId = '%s';", angles[1], mapName, uniqueId);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateFurnitureQuery);
	Format(updateFurnitureQuery, sizeof(updateFurnitureQuery), "UPDATE t_rpg_furniture SET angle_z = %.2f WHERE map = '%s' AND uniqueId = '%s';", angles[2], mapName, uniqueId);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updateFurnitureQuery);
}


public bool TraceEntityFilterPlayer(int entity, int contentsMask) {
	for (int i = 0; i < MAXPLAYERS; i++) {
		if (PlayerEditItems[i][eiRef] != -1 && PlayerEditItems[i][eiRef] != 0) {
			int ent = EntRefToEntIndex(PlayerEditItems[i][eiRef]);
			if (IsValidEntity(ent))
				if (ent == entity)
				return false;
		}
	}
	return (entity > GetMaxClients());
}

public int getLoadedIdByName(char name[64]) {
	for (int i = 0; i < g_iLoadedFurniture; i++) {
		if (StrEqual(LoadedFurnitureItems[i][lfName], name))
			return i;
	}
	return -1;
}


stock bool isValidClient(int client) {
	return (1 <= client <= MaxClients && IsClientInGame(client));
}

public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, any data) {
	if (!StrEqual(error, ""))
		LogError(error);
}

public void onRoundStart(Handle event, const char[] name, bool dontBroadcast) {
	loadFurnitureFromDatabase();
}

public void loadFurnitureFromDatabase() {
	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	
	char loadFurnitureQuery[1024];
	Format(loadFurnitureQuery, sizeof(loadFurnitureQuery), "SELECT * FROM t_rpg_furniture WHERE map = '%s';", mapName);
	SQL_TQuery(g_DB, loadFurnitureQueryCallback, loadFurnitureQuery);
}

public void loadFurnitureQueryCallback(Handle owner, Handle hndl, const char[] error, any data) {
	while (SQL_FetchRow(hndl)) {
		char uniqueId[64];
		char name[64];
		char model[128];
		
		float pos[3];
		float angles[3];
		
		char playername[40];
		char playerid[20];
		
		SQL_FetchStringByName(hndl, "uniqueId", uniqueId, sizeof(uniqueId));
		SQL_FetchStringByName(hndl, "name", name, sizeof(name));
		SQL_FetchStringByName(hndl, "model", model, sizeof(model));
		
		pos[0] = SQL_FetchFloatByName(hndl, "pos_x");
		pos[1] = SQL_FetchFloatByName(hndl, "pos_y");
		pos[2] = SQL_FetchFloatByName(hndl, "pos_z");
		angles[0] = SQL_FetchFloatByName(hndl, "angle_x");
		angles[1] = SQL_FetchFloatByName(hndl, "angle_y");
		angles[2] = SQL_FetchFloatByName(hndl, "angle_z");
		
		SQL_FetchStringByName(hndl, "playername", playername, sizeof(playername));
		SQL_FetchStringByName(hndl, "playerid", playerid, sizeof(playerid));
		
		int theId;
		if ((theId = getLoadedIdByName(name)) != -1)
			spawnFurniture(theId, playerid, pos, angles, uniqueId);
		
	}
}

public int Zone_OnClientEntry(int client, char[] zone) {
	strcopy(activeZone[client], sizeof(activeZone), zone);
}

public int Zone_OnClientLeave(int client, char[] zone) {
	strcopy(activeZone[client], sizeof(activeZone), "");
}

public void OnNpcInteract(int client, char npcType[64], char UniqueId[128], int entIndex) {
	if (!StrEqual(npcType, npctype))
		return;
	g_iLastInteractedWith[client] = entIndex;
	openFurnitureMenu(client);
} 