
#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <rpg_jobs_core>
#include <rpg_npc_core>
#include <multicolors>
#include <tConomy>
#include <tCrime>
#include <smlib>
#include <rpg_inventory_core>
#include <rpg_jail>

#pragma newdecls required

#define MAX_PLANTS 1024

char dbconfig[] = "gsxh_multiroot";
Database g_DB;

int g_iPlayerPrevButtons[MAXPLAYERS + 1];
int g_iLastInteractedWith[MAXPLAYERS + 1];

char npctype[128] = "Drug Shop";

int g_iHarvestIndex[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Drugs for T-RP", 
	author = PLUGIN_AUTHOR, 
	description = "Adds drug plants and the drugplanter job to T-RP", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

enum plantProperties {
	pEntRef, 
	String:pOwner[20], 
	pState, 
	pTime, 
	String:pFlags[64], 
	Float:pPos_x, 
	Float:pPos_y, 
	Float:pPos_z, 
	bool:pActive
}

int g_ePlayerPlants[MAX_PLANTS][plantProperties];
int g_iPlantsActive = 0;

int g_iPlayerPlanted[MAXPLAYERS + 1];


public void OnPluginStart() {
	jobs_registerJob("Drug Planter", "Plant drugs to earn money but don't get cought by the Police", 20, 600, 3.0);
	
	HookEvent("round_start", onRoundStart);
	
	RegConsoleCmd("sm_plant", cmdPlantCommand, "plants drugs");
	
	char error[255];
	g_DB = SQL_Connect(dbconfig, true, error, sizeof(error));
	SQL_SetCharset(g_DB, "utf8");
	
	char CreateTableQuery[4096];
	Format(CreateTableQuery, sizeof(CreateTableQuery), "CREATE TABLE IF NOT EXISTS t_rpg_drugs ( `playerid` VARCHAR(20) NOT NULL , `state` INT NOT NULL , `time` INT NOT NULL , `flags` VARCHAR(64) NOT NULL , `pos_x` FLOAT NOT NULL , `pos_y` FLOAT NOT NULL , `pos_z` FLOAT NOT NULL ) ENGINE = InnoDB CHARSET=utf8 COLLATE utf8_bin;");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, CreateTableQuery);
	
	inventory_addItemHandle("Marijuana Seeds", 1);
}

public void inventory_onItemUsed(int client, char itemname[128], int weight, char category[64], char category2[64], int rarity, char timestamp[64]) {
	if (!StrEqual(itemname, "Marijuana Seeds"))
		return;
	Menu m = CreateMenu(defaultItemHandleHandler);
	char display[128];
	Format(display, sizeof(display), "What to do with '%s' ?", itemname);
	SetMenuTitle(m, display);
	AddMenuItem(m, "plant", "Plant Seeds");
	AddMenuItem(m, "throw", "Throw Away");
	int amount = inventory_getPlayerItemAmount(client, itemname);
	if (amount > 1) {
		char displ[128];
		Format(displ, sizeof(displ), "Throw all Away (%i)", amount);
		AddMenuItem(m, "throwall", displ);
	}
	DisplayMenu(m, client, 60);
}

public int defaultItemHandleHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char info[64];
		GetMenuItem(menu, item, info, sizeof(info));
		
		if (StrEqual(info, "throw"))
			inventory_removePlayerItems(client, "Marijuana Seeds", 1, "Thrown away");
		else if (StrEqual(info, "throwall")) {
			int amount = inventory_getPlayerItemAmount(client, "Marijuana Seeds");
			inventory_removePlayerItems(client, "Marijuana Seeds", amount, "Throwed all away");
		} else if (StrEqual(info, "plant")) {
			cmdPlantCommand(client, 0);
		}
	}
}

public void OnClientAuthorized(int client) {
	g_iPlayerPlanted[client] = getActivePlantsOfPlayerAmount(client);
	g_iHarvestIndex[client] = 0;
}

public void OnNpcInteract(int client, char npcType[64], char UniqueId[128], int entIndex) {
	if (!StrEqual(npcType, npctype))
		return;
	g_iLastInteractedWith[client] = entIndex;
	Handle menu = CreateMenu(drugMenuHandler);
	SetMenuTitle(menu, "Drug Dealer");
	if (!jobs_isActiveJob(client, "Drug Planter"))
		AddMenuItem(menu, "takejob", "Quit job and become a Drug Planter");
	if (tConomy_getCurrency(client) >= 100 && jobs_isActiveJob(client, "Drug Planter"))
		AddMenuItem(menu, "seeds", "Buy a seed (100)");
	else
		AddMenuItem(menu, "x", "Buy a seed (100)", ITEMDRAW_DISABLED);
	if (inventory_hasPlayerItem(client, "Fresh Marijuana"))
		AddMenuItem(menu, "sellDrugs", "Sell Fresh Marijuana");
	else
		AddMenuItem(menu, "x", "Sell Fresh Marijuana", ITEMDRAW_DISABLED);
	if (jobs_isActiveJob(client, "Drug Planter") && jobs_getLevel(client) >= 2) {
		if (tConomy_getCurrency(client) >= 1500)
			AddMenuItem(menu, "lockpick", "Buy Lockpick (1500)");
		else
			AddMenuItem(menu, "lockpick", "Buy Lockpick (1500)", ITEMDRAW_DISABLED);
	}
	if (inventory_hasPlayerItem(client, "Fresh Marijuana")) {
		char sellAll[256];
		int itemamount = inventory_getPlayerItemAmount(client, "Fresh Marijuana");
		Format(sellAll, sizeof(sellAll), "Sell %i Fresh Marijuana", itemamount);
		AddMenuItem(menu, "sellAllMarijuana", sellAll);
	}
	
	if (jobs_isActiveJob(client, "Drug Planter") && jobs_getLevel(client) >= 1) {
		if (tConomy_getCurrency(client) >= 250)
			AddMenuItem(menu, "skin", "Buy Niko Skin (250)");
		else
			AddMenuItem(menu, "skin", "Buy Niko Skin (250)", ITEMDRAW_DISABLED);
	}
	
	DisplayMenu(menu, client, 60);
}

public int drugMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
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
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "takejob")) {
			jobs_quitJob(client);
			jobs_giveJob(client, "Drug Planter");
		} else if (StrEqual(cValue, "seeds")) {
			tConomy_removeCurrency(client, 100, "Bought Seeds");
			inventory_givePlayerItem(client, "Marijuana Seeds", 1, "", "Plant seeds", "Drug Item", 1, "Bought from Vendor");
		} else if (StrEqual(cValue, "lockpick")) {
			tConomy_removeCurrency(client, 1500, "Bought Lockpick");
			inventory_givePlayerItem(client, "Lockpick", 1, "", "Criminal", "Apartment Stuff", 1, "Bought from Vendor");
		} else if (StrEqual(cValue, "sellDrugs") && inventory_hasPlayerItem(client, "Fresh Marijuana")) {
			tConomy_addCurrency(client, 50, "Sold Fresh Marijuana");
			inventory_removePlayerItems(client, "Fresh Marijuana", 1, "Sold to Drug Dealer");
		} else if (StrEqual(cValue, "sellAllMarijuana")) {
			int itemamount = inventory_getPlayerItemAmount(client, "Fresh Marijuana");
			if (inventory_removePlayerItems(client, "Fresh Marijuana", itemamount, "Sold to Vendor (Mass Sell)"))
				tConomy_addCurrency(client, 50 * itemamount, "Sold Fresh Marijuana to Vendor");
		} else if (StrEqual(cValue, "skin")) {
			tConomy_removeCurrency(client, 250, "Bought Skin");
			inventory_givePlayerItem(client, "Niko", 0, "", "Skin", "Skin", 1, "Bought from Drug Vendor");
		}
	}
}

public void onRoundStart(Handle event, const char[] name, bool dontBroadcast) {
	for (int i = 0; i < MAX_PLANTS; i++)
	g_ePlayerPlants[i][pActive] = false;
	g_iPlantsActive = 0;
	loadPlants();
}

public void OnMapStart() {
	npc_registerNpcType(npctype);
	CreateTimer(10.0, refreshTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	PrecacheModel("models/custom_prop/marijuana/marijuana_0.mdl", true);
	PrecacheModel("models/custom_prop/marijuana/marijuana_1.mdl", true);
	PrecacheModel("models/custom_prop/marijuana/marijuana_2.mdl", true);
	PrecacheModel("models/custom_prop/marijuana/marijuana_3.mdl", true);
}

public Action refreshTimer(Handle Timer) {
	for (int plant = 0; plant < MAX_PLANTS; plant++) {
		if (g_ePlayerPlants[plant][pActive] && g_ePlayerPlants[plant][pState] < 3) {
			g_ePlayerPlants[plant][pTime] += 10;
			if (g_ePlayerPlants[plant][pTime] >= 60) {
				g_ePlayerPlants[plant][pTime] = 0;
				g_ePlayerPlants[plant][pState]++;
				evolvePlant(g_ePlayerPlants[plant][pEntRef], g_ePlayerPlants[plant][pState]);
			}
			updatePlant(plant);
		}
	}
}

public void updatePlant(int plantId) {
	char updatePlantQuery[1024];
	Format(updatePlantQuery, sizeof(updatePlantQuery), "UPDATE t_rpg_drugs SET time = %i WHERE flags = '%s';", g_ePlayerPlants[plantId][pTime], g_ePlayerPlants[plantId][pFlags]);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updatePlantQuery);
	
	Format(updatePlantQuery, sizeof(updatePlantQuery), "UPDATE t_rpg_drugs SET state = %i WHERE flags = '%s';", g_ePlayerPlants[plantId][pState], g_ePlayerPlants[plantId][pFlags]);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, updatePlantQuery);
}

public void evolvePlant(int entRef, int state) {
	if (state >= 0 && state < 4) {
		int entity = EntRefToEntIndex(entRef);
		if (!IsValidEntity(entity))
			return;
		char modelPath[128];
		Format(modelPath, sizeof(modelPath), "models/custom_prop/marijuana/marijuana_%i.mdl", state);
		SetEntityModel(entity, modelPath);
	}
}

public void loadPlants() {
	char loadPlantsQuery[512];
	Format(loadPlantsQuery, sizeof(loadPlantsQuery), "SELECT playerid,state,time,flags,pos_x,pos_y,pos_z FROM t_rpg_drugs;");
	SQL_TQuery(g_DB, SQLLoadPlantsQuery, loadPlantsQuery);
}

public void SQLLoadPlantsQuery(Handle owner, Handle hndl, const char[] error, any data) {
	while (SQL_FetchRow(hndl)) {
		char plantowner[20];
		SQL_FetchStringByName(hndl, "playerid", plantowner, sizeof(plantowner));
		int state = SQL_FetchIntByName(hndl, "state");
		int time = SQL_FetchIntByName(hndl, "time");
		char flags[64];
		SQL_FetchStringByName(hndl, "flags", flags, sizeof(flags));
		float pos[3];
		pos[0] = SQL_FetchFloatByName(hndl, "pos_x");
		pos[1] = SQL_FetchFloatByName(hndl, "pos_y");
		pos[2] = SQL_FetchFloatByName(hndl, "pos_z");
		spawnPlant(plantowner, state, time, pos, flags);
	}
	for (int i = 1; i < MAXPLAYERS; i++) {
		if (isValidClient(i))
			g_iPlayerPlanted[i] = getActivePlantsOfPlayerAmount(i);
	}
}

public Action cmdPlantCommand(int client, int args) {
	if (g_iPlayerPlanted[client] > (3 + jobs_getLevel(client) / 5)) {
		CPrintToChat(client, "[-T-]{red} You can not have more than %i active plants (%i Active)", (4 + jobs_getLevel(client) / 5), g_iPlayerPlanted[client]);
		return Plugin_Handled;
	}
	
	if (jail_isInJail(client)) {
		CPrintToChat(client, "[-T-]{red} You can't plant drugs in jail...'");
		return Plugin_Handled;
	}
	
	if (inventory_hasPlayerItem(client, "Marijuana Seeds"))
		inventory_removePlayerItems(client, "Marijuana Seeds", 1, "Planted Marijuana");
	else
		return Plugin_Handled;
	
	float pos[3];
	GetClientAbsOrigin(client, pos);
	
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	
	char flags[64];
	int time = GetTime();
	IntToString(time, flags, sizeof(flags));
	
	char createPlantQuery[512];
	Format(createPlantQuery, sizeof(createPlantQuery), "INSERT INTO `t_rpg_drugs` (`playerid`, `state`, `time`, `flags`, `pos_x`, `pos_y`, `pos_z`) VALUES ('%s', '0', '0', '%s', '%.2f', '%f.2', '%f.2');", playerid, flags, pos[0], pos[1], pos[2]);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createPlantQuery);
	
	spawnPlant(playerid, 0, 0, pos, flags);
	tCrime_addCrime(client, 20);
	
	g_iPlayerPlanted[client]++;
	return Plugin_Handled;
}

public void spawnPlant(char owner[20], int state, int time, float pos[3], char flags[64]) {
	int drugPlant = CreateEntityByName("prop_dynamic_override");
	if (drugPlant == -1)
		return;
	char modelPath[128];
	Format(modelPath, sizeof(modelPath), "models/custom_prop/marijuana/marijuana_%i.mdl", state);
	SetEntityModel(drugPlant, modelPath);
	DispatchKeyValue(drugPlant, "Solid", "6");
	SetEntProp(drugPlant, Prop_Send, "m_nSolidType", 6);
	SetEntProp(drugPlant, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_PUSHAWAY);
	DispatchSpawn(drugPlant);
	TeleportEntity(drugPlant, pos, NULL_VECTOR, NULL_VECTOR);
	Entity_SetGlobalName(drugPlant, "Drug Plant");
	
	
	int whereToStore = findLowestUnusedPlantSlot();
	g_ePlayerPlants[whereToStore][pEntRef] = EntIndexToEntRef(drugPlant);
	strcopy(g_ePlayerPlants[whereToStore][pOwner], 20, owner);
	strcopy(g_ePlayerPlants[whereToStore][pFlags], 20, flags);
	g_ePlayerPlants[whereToStore][pState] = state;
	g_ePlayerPlants[whereToStore][pTime] = time;
	g_ePlayerPlants[whereToStore][pPos_x] = pos[0];
	g_ePlayerPlants[whereToStore][pPos_y] = pos[1];
	g_ePlayerPlants[whereToStore][pPos_z] = pos[2];
	g_ePlayerPlants[whereToStore][pActive] = true;
	g_iPlantsActive++;
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon, int &tickcount) {
	if (IsClientInGame(client) && IsPlayerAlive(client)) {
		if (!(g_iPlayerPrevButtons[client] & IN_USE) && iButtons & IN_USE) {
			int ent = GetClientAimTarget(client, false);
			if (!IsValidEntity(ent)) {
				g_iPlayerPrevButtons[client] = iButtons;
				return;
			}
			if (HasEntProp(ent, Prop_Data, "m_iName") && HasEntProp(ent, Prop_Data, "m_iGlobalname")) {
				char entName[256];
				Entity_GetGlobalName(ent, entName, sizeof(entName));
				if (StrEqual(entName, "Drug Plant")) {
					if (findPlantLoadedIdByIndex(ent) == -1) {
						g_iPlayerPrevButtons[client] = iButtons;
						return;
					}
					float pos[3];
					GetEntPropVector(ent, Prop_Data, "m_vecOrigin", pos);
					float ppos[3];
					GetClientAbsOrigin(client, ppos);
					if (GetVectorDistance(ppos, pos) < 100.0) {
						if (jobs_isActiveJob(client, "Police")) {
							jobs_startProgressBar(client, 5, "Confiscate Plant");
							g_iHarvestIndex[client] = ent;
						} else {
							jobs_startProgressBar(client, 10, "Harvest Plant");
							g_iHarvestIndex[client] = ent;
						}
					} else {
						PrintToChat(client, "This Drug plant is too far away (%.2f/300.0)", GetVectorDistance(ppos, pos));
						g_iPlayerPrevButtons[client] = iButtons;
						return;
					}
					//harvestPlant(client, ent, plantId, g_ePlayerPlants[plantId][pState]);
					
				}
			}
		}
		g_iPlayerPrevButtons[client] = iButtons;
	}
}

public void jobs_OnProgressBarInterrupted(int client, char info[64]) {
	g_iHarvestIndex[client] = -1;
}

public void jobs_OnProgressBarFinished(int client, char info[64]) {
	if (StrEqual(info, "Harvest Plant")) {
		int plantId;
		if ((plantId = findPlantLoadedIdByIndex(g_iHarvestIndex[client])) == -1)
			return;
		
		harvestPlant(client, g_iHarvestIndex[client], plantId, g_ePlayerPlants[plantId][pState]);
	} else if (StrEqual(info, "Confiscate Plant")) {
		int plantId;
		if ((plantId = findPlantLoadedIdByIndex(g_iHarvestIndex[client])) == -1)
			return;
		
		jobs_addExperience(client, 50, "Police");
		tConomy_addBankCurrency(client, 50, "Confiscated Plant");
		deletePlant(g_iHarvestIndex[client], plantId);
	}
}

public void harvestPlant(int client, int ent, int plantId, int state) {
	//tConomy_addCurrency(client, 200, "Harvest of Drug Plant");
	
	if (state == 1) {
		for (int i = 0; i < 1; i++) {
			inventory_givePlayerItem(client, "Fresh Marijuana", 2, "", "Plant", "Drug Item", 2, "Harvested Plant");
		}
	} else if (state == 2) {
		for (int i = 0; i < 2; i++) {
			inventory_givePlayerItem(client, "Fresh Marijuana", 2, "", "Plant", "Drug Item", 2, "Harvested Plant");
		}
	} else if (state == 3) {
		for (int i = 0; i < 4; i++) {
			inventory_givePlayerItem(client, "Fresh Marijuana", 2, "", "Plant", "Drug Item", 2, "Harvested Plant");
		}
	}
	
	if (jobs_isActiveJob(client, "Drug Planter"))
		jobs_addExperience(client, 50 + 50 * state, "Drug Planter");
	else
		tCrime_addCrime(client, 10);
	
	deletePlant(ent, plantId);
	
	int jobLevel = jobs_getLevel(client);
	int diff;
	if ((100 - jobLevel * 5) >= 10)
		diff = 100 - jobLevel * 5;
	else
		diff = 10;
	if (GetRandomInt(0, diff) <= 5) {
		char reason[256];
		Format(reason, sizeof(reason), "Harvested with %i%s chance", jobLevel * 5, "%");
		inventory_givePlayerItem(client, "Marijuana Seeds", 1, "", "Plant seeds", "Drug Item", 1, reason);
	}
}

public void deletePlant(int ent, int plantId) {
	char deletePlantsQuery[512];
	Format(deletePlantsQuery, sizeof(deletePlantsQuery), "DELETE FROM t_rpg_drugs WHERE flags = '%s';", plantId);
	SQL_TQuery(g_DB, SQLErrorCheckCallback, deletePlantsQuery);
	
	AcceptEntityInput(ent, "kill");
	
	int owner;
	char playerid[20];
	strcopy(playerid, sizeof(playerid), g_ePlayerPlants[plantId][pOwner]);
	if ((owner = getClientFromAuth2(playerid)) != -1)
		g_iPlayerPlanted[owner]--;
	
	g_ePlayerPlants[plantId][pEntRef] = -1;
	strcopy(g_ePlayerPlants[plantId][pOwner], 20, "");
	g_ePlayerPlants[plantId][pState] = -1;
	g_ePlayerPlants[plantId][pTime] = -1;
	g_ePlayerPlants[plantId][pPos_x] = 0.0;
	g_ePlayerPlants[plantId][pPos_y] = 0.0;
	g_ePlayerPlants[plantId][pPos_z] = 0.0;
	g_ePlayerPlants[plantId][pActive] = false;
}

public int findPlantLoadedIdByIndex(int index) {
	for (int i = 0; i < g_iPlantsActive; i++) {
		if (!g_ePlayerPlants[i][pActive])
			continue;
		if (EntRefToEntIndex(g_ePlayerPlants[i][pEntRef]) == index)
			return i;
	}
	return -1;
}

public int findLowestUnusedPlantSlot() {
	for (int i = 0; i < g_iPlantsActive; i++) {
		if (!g_ePlayerPlants[i][pActive])
			return i;
	}
	return g_iPlantsActive;
}


stock bool isValidClient(int client) {
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client))
		return false;
	
	return true;
}

public int getActivePlantsOfPlayerAmount(int client) {
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	int amount = 0;
	for (int i = 0; i < MAX_PLANTS; i++) {
		if (g_ePlayerPlants[i][pActive])
			if (StrEqual(g_ePlayerPlants[i][pOwner], playerid))
			amount++;
	}
	return amount;
}

public int getClientFromAuth2(char auth2[20]) {
	for (int i = 1; i < MAXPLAYERS; i++) {
		if (isValidClient(i)) {
			char playerid[20];
			GetClientAuthId(i, AuthId_Steam2, playerid, sizeof(playerid));
			if (StrEqual(auth2, playerid)) {
				return i;
			}
		}
	}
	return -1;
}

public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, any data) {
	if (!StrEqual(error, ""))
		LogError(error);
}
