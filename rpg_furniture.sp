#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <rpg_inventory_core>
#include <tConomy>
#include <smlib>

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


enum EditItem {
	eiRef, 
	bool:eiEditing
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
	RegConsoleCmd("sm_furniture", openFurnitureMenu, "Opens the Furniture Menu");
	RegAdminCmd("sm_reloadfurniture", cmdReloadFurniture, ADMFLAG_ROOT, "Reload the Furniture");
	RegConsoleCmd("sm_builder", cmdBuild, "Edits Furniture");
}

public void OnMapStart() {
	inventory_addItemHandle("Furniture", 2);
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

public Action openFurnitureMenu(int client, int args) {
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
	return Plugin_Handled;
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
	
	spawnFurniture(client, id);
}


public void spawnFurniture(int client, int id) {
	int furnitureEnt = CreateEntityByName("prop_dynamic_override");
	if (furnitureEnt == -1)
		return;
	char modelPath[128];
	Format(modelPath, sizeof(modelPath), LoadedFurnitureItems[id][lfModelPath]);
	SetEntityModel(furnitureEnt, modelPath);
	DispatchKeyValue(furnitureEnt, "Solid", "6");
	SetEntProp(furnitureEnt, Prop_Send, "m_nSolidType", 6);
	SetEntProp(furnitureEnt, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_PUSHAWAY);
	
	char cId[64];
	IntToString(id, cId, sizeof(cId));
	
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	Format(cId, sizeof(cId), "%i %s", id, playerid);
	
	SetEntPropString(furnitureEnt, Prop_Data, "m_iName", cId);
	DispatchSpawn(furnitureEnt);
	float pos[3];
	pos = GetAimOrigin(client);
	TeleportEntity(furnitureEnt, pos, NULL_VECTOR, NULL_VECTOR);
	Entity_SetGlobalName(furnitureEnt, LoadedFurnitureItems[id][lfName]);
	
	char itemName2[128];
	strcopy(itemName2, sizeof(itemName2), LoadedFurnitureItems[id][lfName]);
	inventory_removePlayerItems(client, itemName2, 1, "Placed Item");
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
}

public Action cmdBuild(int client, int args) {
	int id;
	if ((id = GetClientAimTarget(client, false)) < 0)
		return Plugin_Handled;
	
	char entName[64];
	Entity_GetGlobalName(id, entName, sizeof(entName));
	
	char uniqueId[40];
	GetEntPropString(id, Prop_Data, "m_iName", uniqueId, sizeof(uniqueId));
	
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	if (StrContains(uniqueId, playerid) == -1) {
		PrintToChat(client, "[-T-] You do not own that Item.");
		return Plugin_Handled;
	}
	
	
	PlayerEditItems[client][eiRef] = EntIndexToEntRef(id);
	PlayerEditItems[client][eiEditing] = true;
	
	PrintToChat(client, "[-T-] Now editing %s", entName);
	PrintToChat(client, "[-T-] R to Teleport, A & D for Angles JUMP for up E to Exit");
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 0.0);
	
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon, int &tickcount) {
	if (IsClientInGame(client) && IsPlayerAlive(client)) {
		if (PlayerEditItems[client][eiEditing]) {
			if (!(g_iPlayerPrevButtons[client] & IN_USE) && iButtons & IN_USE) {
				PlayerEditItems[client][eiRef] = -1;
				PlayerEditItems[client][eiEditing] = false;
				PrintToChat(client, "[-T-] Finished Editing");
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
			}
			if (!(g_iPlayerPrevButtons[client] & IN_JUMP) && iButtons & IN_JUMP) {
				int ent = EntRefToEntIndex(PlayerEditItems[client][eiRef]);
				float pos[3];
				GetEntPropVector(ent, Prop_Data, "m_vecOrigin", pos);
				pos[2] += 1;
				float clientPos[3];
				GetClientAbsOrigin(client, clientPos);
				if (GetVectorDistance(clientPos, pos) > 400.0)
					PrintToChat(client, "[-T-] Too far away...");
				else
					TeleportEntity(ent, pos, NULL_VECTOR, NULL_VECTOR);
				TeleportEntity(ent, pos, NULL_VECTOR, NULL_VECTOR);
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
				if (GetVectorDistance(clientPos, pos) > 400.0)
					PrintToChat(client, "[-T-] Too far away...");
				else
					TeleportEntity(ent, pos, NULL_VECTOR, NULL_VECTOR);
				TeleportEntity(ent, pos, NULL_VECTOR, NULL_VECTOR);
				iButtons ^= IN_DUCK;
				return Plugin_Changed;
			}
			if (!(g_iPlayerPrevButtons[client] & IN_RELOAD) && iButtons & IN_RELOAD) {
				int ent = EntRefToEntIndex(PlayerEditItems[client][eiRef]);
				float pos[3];
				pos = GetAimOrigin(client);
				float clientPos[3];
				GetClientAbsOrigin(client, clientPos);
				if (GetVectorDistance(clientPos, pos) > 500.0)
					PrintToChat(client, "[-T-] Too far away...");
				else
					TeleportEntity(ent, pos, NULL_VECTOR, NULL_VECTOR);
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