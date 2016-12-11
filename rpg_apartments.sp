#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <devzones>
#include <tConomy>

#pragma newdecls required


#define MAX_APARTMENTS 512

int g_iPlayerPrevButtons[MAXPLAYERS + 1];
char g_cDBConfig[] = "gsxh_multiroot";
char activeZone[MAXPLAYERS + 1][128];

Database g_DB;


enum existingApartment {
	eaId, 
	String:eaApartment_Id[128], // = Zone ID
	eaApartment_Price, 
	bool:eaBuyable, 
	String:eaFlag[8], 
	bool:eaBought
}

int existingApartments[MAX_APARTMENTS][existingApartment];


enum ownedApartment {
	oaId, 
	String:oaTime_of_purchase[64], 
	oaPrice_of_purchase, 
	String:oaApartment_Id[128], // = Zone ID
	String:oaPlayerid[20], 
	String:oaPlayername[48], 
	String:oaApartmentName[255], 
	String:oaAllowed_players[550], 
	bool:oaDoor_locked
}

int ownedApartments[MAX_APARTMENTS][ownedApartment];


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
		Id		apartment_id	apartment_price	buyable	flag	bought
		int		vchar			int				bool	vchar	boolean
		
		
		Table Struct (2) (bought Table)
		Id	time_of_purchase	price_of_purchase	apartment_id	playerid	playername	apartment_name	allowed_players	door_locked	
		int	timestamp			int					vchar			vchar		vchar		vchar			vchar			bool
	*/
	
	char error[255];
	g_DB = SQL_Connect(g_cDBConfig, true, error, sizeof(error));
	SQL_SetCharset(g_DB, "utf8");
	
	char createExistingApartmentsTable[4096];
	Format(createExistingApartmentsTable, sizeof(createExistingApartmentsTable), "CREATE TABLE IF NOT EXISTS `t_rpg_apartments` ( `Id` BIGINT NULL DEFAULT NULL AUTO_INCREMENT , `apartment_id` VARCHAR(128) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL , `apartment_price` INT NOT NULL , `buyable` BOOLEAN NOT NULL , `flag` VARCHAR(8) NOT NULL , `bought` BOOLEAN NOT NULL , UNIQUE KEY `apartment_id` (`apartment_id`), PRIMARY KEY (`Id`)) ENGINE = InnoDB CHARSET=utf8 COLLATE utf8_bin;");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createExistingApartmentsTable);
	
	char createBoughtApartmentsTable[4096];
	Format(createBoughtApartmentsTable, sizeof(createBoughtApartmentsTable), "CREATE TABLE IF NOT EXISTS `t_rpg_boughtApartments` ( `Id` BIGINT NULL DEFAULT NULL AUTO_INCREMENT , `time_of_purchase` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , `price_of_purchase` INT NOT NULL , `apartment_id` VARCHAR(128) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL , `playerid` VARCHAR(20) NOT NULL , `playername` VARCHAR(48) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL , `apartment_name` VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL , `allowed_players` VARCHAR(550) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL , `door_locked` BOOLEAN NOT NULL , UNIQUE KEY `apartment_id` (`apartment_id`), PRIMARY KEY (`Id`)) ENGINE = InnoDB CHARSET=utf8 COLLATE utf8_bin;");
	SQL_TQuery(g_DB, SQLErrorCheckCallback, createBoughtApartmentsTable);
	
	
	RegAdminCmd("sm_createApartment", createApartmentCallback, ADMFLAG_ROOT);
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
				if (HasEntProp(ent, Prop_Data, "m_iName")){
					char itemName[128];
					GetEntPropString(ent, Prop_Data, "m_iName", itemName, sizeof(itemName));
					if(StrContains(itemName, "door", false)){
						doorAction(client, activeZone[client], ent);
					}
				}
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
}

public int Zone_OnClientLeave(int client, char[] zone) {
	strcopy(activeZone[client], sizeof(activeZone), "");
}

public void doorAction(int client, char[] zone, int doorEnt){

}

public Action createApartmentCallback(int client, int args) {
	/*
		* Add
		* Remove
		* Exit
		
		Add -> Show available Zones on click -> Add -> Sync with DB
		Remove -> show all apartments from table > Remove -> Sync with db
	*/
	
	
	return Plugin_Handled;
}


public int getLoadedIdFromApartmentId(char apartmentId[128]){
	for (int i = 0; i < MAX_APARTMENTS; i++){
		if(StrEqual(existingApartments[i][eaApartment_Id], apartmentId))
			return i;
	}
	return -1;
}