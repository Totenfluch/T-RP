#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <smlib>

int spawned_car[MAXPLAYERS + 1];
int cars_spawned[MAXPLAYERS + 1];
int g_iCarOwned[MAXPLAYERS + 1];
int cars_type[2049];
int car_driver_view[2049];
int Cars_Driver_Prop[2049];
int buttons2;

bool CarOn[2049];
int ViewEnt[2048];
bool CarView[2049];
bool Driving[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Drivables for T-RP", 
	author = PLUGIN_AUTHOR, 
	description = "Adds Vehicles to T-RP", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart() {
	RegConsoleCmd("sm_vehicle", cmdVehicleSpawn);
}

public void OnMapStart() {
	PrecacheModel("models/natalya/vehicles/natalya_mustang_csgo_2016.mdl", true);
}

public void OnClientDisconnect(int client) {
	removeVehicle(client);
}

public void removeVehicle(int client) {
	if (g_iCarOwned[client] != -1 && g_iCarOwned[client] != 0) {
		int iEnt = EntRefToEntIndex(g_iCarOwned[client]);
		if (IsValidEntity(iEnt))
			AcceptEntityInput(iEnt, "kill");
	}
}

public Action cmdVehicleSpawn(int client, int args) {
	removeVehicle(client);
	
	float pos[3];
	float angles[3];
	GetClientAbsOrigin(client, pos);
	GetClientAbsAngles(client, angles);
	
	
	int ent = CreateEntityByName("prop_vehicle_driveable");
	AcceptEntityInput(ent, "Unlock", 1);
	Cars_Driver_Prop[ent] = -1;
	DispatchKeyValue(ent, "vehiclescript", "scripts/vehicles/natalyas_mustang.txt");
	DispatchKeyValue(ent, "model", "models/natalya/vehicles/natalya_mustang_csgo_2016.mdl");
	DispatchKeyValueFloat(ent, "MaxPitch", 360.00);
	DispatchKeyValueFloat(ent, "MinPitch", -360.00);
	DispatchKeyValueFloat(ent, "MaxYaw", 90.00);
	char vehicleName[64];
	Format(vehicleName, sizeof(vehicleName), "%Ns car", client);
	DispatchKeyValue(ent, "targetname", vehicleName);
	DispatchKeyValue(ent, "solid", "6");
	DispatchKeyValue(ent, "skin", "1");
	DispatchKeyValue(ent, "actionScale", "1");
	DispatchKeyValue(ent, "EnableGun", "0");
	DispatchKeyValue(ent, "ignorenormals", "0");
	DispatchKeyValue(ent, "fadescale", "1");
	DispatchKeyValue(ent, "fademindist", "-1");
	DispatchKeyValue(ent, "VehicleLocked", "0");
	DispatchKeyValue(ent, "screenspacefade", "0");
	DispatchKeyValue(ent, "spawnflags", "256");
	DispatchKeyValue(ent, "setbodygroup", "511");
	SetEntProp(ent, Prop_Send, "m_nSolidType", 2);
	DispatchSpawn(ent);
	ActivateEntity(ent);
	Entity_SetGlobalName(ent, vehicleName);
	SetEntProp(ent, Prop_Data, "m_nNextThinkTick", -1);
	
	spawned_car[client] = ent;
	cars_spawned[client] += 1;
	g_iCarOwned[client] = EntIndexToEntRef(ent);
	
	TeleportEntity(ent, pos, angles, NULL_VECTOR);
	SetEntProp(ent, Prop_Data, "m_nNextThinkTick", -1);
	SDKHook(ent, SDKHook_Think, OnThink);
	
	return Plugin_Handled;
}



public void LeaveVehicle(int client)
{
	int vehicle = GetEntPropEnt(client, Prop_Send, "m_hVehicle");
	if (IsValidEntity(vehicle))
	{
		// Put client in Exit attachment.
		char car_ent_name[128];
		GetTargetName(vehicle, car_ent_name, sizeof(car_ent_name));
		SetVariantString(car_ent_name);
		AcceptEntityInput(client, "SetParent");
		SetVariantString("vehicle_driver_exit");
		AcceptEntityInput(client, "SetParentAttachment");
		
		float ExitAng[3];
		GetEntPropVector(vehicle, Prop_Data, "m_angRotation", ExitAng);
		ExitAng[0] = 0.0;
		ExitAng[1] += 90.0;
		ExitAng[2] = 0.0;
		
		
		AcceptEntityInput(client, "ClearParent");
		
		SetEntPropEnt(client, Prop_Send, "m_hVehicle", -1);
		
		SetEntPropEnt(vehicle, Prop_Send, "m_hPlayer", -1);
		
		SetEntityMoveType(client, MOVETYPE_WALK);
		
		SetEntProp(client, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_PLAYER);
		
		int hud = GetEntProp(client, Prop_Send, "m_iHideHUD");
		hud &= ~HIDEHUD_WEAPONSELECTION;
		hud &= ~HIDEHUD_CROSSHAIR;
		hud &= ~HIDEHUD_INVEHICLE;
		SetEntProp(client, Prop_Send, "m_iHideHUD", hud);
		
		int EntEffects = GetEntProp(client, Prop_Send, "m_fEffects");
		EntEffects &= ~32;
		SetEntProp(client, Prop_Send, "m_fEffects", EntEffects);
		
		float ViewOffset[3];
		GetEntPropVector(vehicle, Prop_Data, "m_savedViewOffset", ViewOffset);
		SetEntPropVector(client, Prop_Data, "m_vecViewOffset", ViewOffset);
		
		SetEntProp(vehicle, Prop_Send, "m_nSpeed", 0);
		SetEntPropFloat(vehicle, Prop_Send, "m_flThrottle", 0.0);
		AcceptEntityInput(vehicle, "TurnOff");
		
		SetEntPropFloat(vehicle, Prop_Data, "m_flTurnOffKeepUpright", 0.0);
		
		SetEntProp(vehicle, Prop_Send, "m_iTeamNum", 0);
		
		TeleportEntity(client, NULL_VECTOR, ExitAng, NULL_VECTOR);
		SetClientViewEntity(client, client);
		
	}
	
	if (vehicle > 0)
	{
		if (IsValidEntity(Cars_Driver_Prop[vehicle]))
		{
			AcceptEntityInput(Cars_Driver_Prop[vehicle], "Kill");
			RemoveEdict(Cars_Driver_Prop[vehicle]);
			Cars_Driver_Prop[vehicle] = -1;
		}
	}
	
	// Fix no weapon
	int plyr_gun2 = GetPlayerWeaponSlot(client, 2);
	if (IsValidEntity(plyr_gun2))
	{
		RemovePlayerItem(client, plyr_gun2);
		RemoveEdict(plyr_gun2);
		GivePlayerItem(client, "weapon_knife", 0);
	}
}

stock void GetTargetName(int entity, char[] buf, int len)
{
	GetEntPropString(entity, Prop_Data, "m_iName", buf, len);
}

public void OnEntityDestroyed(int entity)
{
	char ClassName[30];
	if (IsValidEdict(entity))
	{
		GetEdictClassname(entity, ClassName, sizeof(ClassName));
		if (StrEqual("prop_vehicle_driveable", ClassName, false))
		{
			int Driver = GetEntPropEnt(entity, Prop_Send, "m_hPlayer");
			if (Driver != -1)
			{
				LeaveVehicle(Driver);
				CarOn[entity] = false;
			}
		}
	}
	SDKUnhook(entity, SDKHook_Think, OnThink);
}


public Action OnPlayerRunCmd(client, &buttons, &impulse, float vel[3], float angles[3], &weapon)
{
	static bool PressingUse[MAXPLAYERS + 1];
	static bool DuckBuffer[MAXPLAYERS + 1];
	static OldButtons[MAXPLAYERS + 1];
	int use = 0;
	use = 1;
	
	if (use == 1)
	{
		if (!(OldButtons[client] & IN_USE) && (buttons & IN_USE))
		{
			if (!PressingUse[client])
			{
				if (GetEntPropEnt(client, Prop_Send, "m_hVehicle") != -1)
				{
					LeaveVehicle(client);
					buttons &= ~IN_USE;
					PressingUse[client] = true;
					OldButtons[client] = buttons;
					return Plugin_Handled;
				}
				else
				{
					int Ent;
					Ent = GetClientAimTarget(client, false);
					if (IsValidEdict(Ent))
					{
						char ClassName[255];
						GetEdictClassname(Ent, ClassName, 255);
						
						//Valid:
						if (StrEqual(ClassName, "prop_vehicle_driveable", false))
						{
							float origin[3];
							float car_origin[3];
							float distance;
							
							GetClientAbsOrigin(client, origin);
							GetEntPropVector(Ent, Prop_Send, "m_vecOrigin", car_origin);
							distance = GetVectorDistance(origin, car_origin, false);
							
							// It is a car.  See if it is locked or not, and if it is in range.
							if ((!GetEntProp(Ent, Prop_Data, "m_bLocked")) && (distance <= 88.00))
							{
								// Car in range, unlocked.
								int Driver = GetEntPropEnt(Ent, Prop_Send, "m_hPlayer");
								if (Driver == -1)
								{
									AcceptEntityInput(Ent, "use", client);
									PressingUse[client] = true;
									OldButtons[client] = buttons;
									return Plugin_Handled;
								}
							}
							else
							{
								EmitSoundToAll("doors/default_locked.wav", Ent, SNDCHAN_AUTO, SNDLEVEL_NORMAL);
							}
						}
					}
				}
			}
			PressingUse[client] = true;
		}
		else
		{
			PressingUse[client] = false;
		}
	}
	else
	{
		buttons &= ~IN_USE;
	}
	if (buttons & IN_RELOAD)
	{
		int car = GetEntPropEnt(client, Prop_Send, "m_hVehicle");
		if (car != -1)
		{
			AcceptEntityInput(car, "TurnOn");
			CarOn[car] = true;
		}
	}
	if (impulse == 100)
	{
		int car = GetEntPropEnt(client, Prop_Send, "m_hVehicle");
		if (car != -1)
		{
			//LightToggle(client);
		}
	}
	if (buttons & IN_DUCK)
	{
		if (!DuckBuffer[client])
		{
			int car = GetEntPropEnt(client, Prop_Send, "m_hVehicle");
			if (car != -1)
			{
				ViewToggle(client);
			}
		}
		DuckBuffer[client] = true;
	}
	else
	{
		DuckBuffer[client] = false;
	}
	OldButtons[client] = buttons;
	return Plugin_Continue;
}

public void ViewToggle(int client)
{
	int car = GetEntPropEnt(client, Prop_Send, "m_hVehicle");
	
	char car_ent_name[128];
	GetTargetName(car, car_ent_name, sizeof(car_ent_name));
	if (CarView[client] == true)
	{
		SetVariantString(car_ent_name);
		AcceptEntityInput(client, "SetParent");
		CarView[client] = false;
		SetVariantString("vehicle_driver_eyes");
		AcceptEntityInput(client, "SetParentAttachment");
		return;
	}
	if (CarView[client] == false)
	{
		SetVariantString(car_ent_name);
		AcceptEntityInput(client, "SetParent");
		CarView[client] = true;
		SetVariantString("vehicle_3rd");
		AcceptEntityInput(client, "SetParentAttachment");
		return;
	}
}

public OnThink(int entity)
{
	int Driver = GetEntPropEnt(entity, Prop_Send, "m_hPlayer");
	if (ViewEnt[Driver] != 0 && ViewEnt[Driver] != -1)
		if (IsValidEntity(EntRefToEntIndex(ViewEnt[Driver])))
	{
		if (Driver > 0)
		{
			if (IsClientInGame(Driver) && IsPlayerAlive(Driver))
			{
				SetEntProp(entity, Prop_Data, "m_nNextThinkTick", 1);
				SetEntPropFloat(entity, Prop_Data, "m_flTurnOffKeepUpright", 1.0);
				
				SetClientViewEntity(Driver, EntRefToEntIndex(ViewEnt[Driver]));
				Driving[Driver] = true;
				
				int t = cars_type[entity];
				if (car_driver_view[t] == 1)
				{
					if (Cars_Driver_Prop[entity] == -1)
					{
						int prop = CreateEntityByName("prop_physics_override");
						if (IsValidEntity(prop))
						{
							char model[128];
							GetClientModel(Driver, model, sizeof(model));
							DispatchKeyValue(prop, "model", model);
							DispatchKeyValue(prop, "skin", "0");
							ActivateEntity(prop);
							DispatchSpawn(prop);
							
							int enteffects = GetEntProp(prop, Prop_Send, "m_fEffects");
							enteffects |= 1;
							enteffects |= 128;
							enteffects |= 512;
							SetEntProp(prop, Prop_Send, "m_fEffects", enteffects);
							
							char car_ent_name[128];
							GetTargetName(entity, car_ent_name, sizeof(car_ent_name));
							
							SetVariantString(car_ent_name);
							AcceptEntityInput(prop, "SetParent", prop, prop, 0);
							SetVariantString("vehicle_driver_eyes");
							AcceptEntityInput(prop, "SetParentAttachment", prop, prop, 0);
							Cars_Driver_Prop[entity] = prop;
						}
					}
				}
				else Cars_Driver_Prop[entity] = -1;
			}
		}
	}
	if (GetEntProp(entity, Prop_Send, "m_bEnterAnimOn") == 1)
	{
		SetEntProp(entity, Prop_Send, "m_nSequence", 0);
		
		char authid[20];
		GetClientAuthId(Driver, AuthId_Steam2, authid, sizeof(authid));
		SetVariantString(authid);
		DispatchKeyValue(Driver, "targetname", authid);
		
		char targetName[100];
		
		float sprite_rgb[3];
		sprite_rgb[0] = 0.0;
		sprite_rgb[1] = 0.0;
		sprite_rgb[2] = 0.0;
		
		GetTargetName(entity, targetName, sizeof(targetName));
		
		int sprite = CreateEntityByName("env_sprite");
		
		DispatchKeyValue(sprite, "model", "materials/sprites/dot.vmt");
		DispatchKeyValue(sprite, "renderamt", "0");
		DispatchKeyValue(sprite, "renderamt", "0");
		DispatchKeyValueVector(sprite, "rendercolor", sprite_rgb);
		
		DispatchSpawn(sprite);
		
		float vec[3];
		float ang[3];
		
		GetClientAbsOrigin(Driver, vec);
		GetClientAbsAngles(Driver, ang);
		
		TeleportEntity(sprite, vec, ang, NULL_VECTOR);
		SetClientViewEntity(Driver, sprite);
		
		SetVariantString("!activator");
		AcceptEntityInput(sprite, "SetParent", Driver);
		
		SetVariantString(targetName);
		AcceptEntityInput(Driver, "SetParent");
		
		SetVariantString("vehicle_driver_eyes");
		AcceptEntityInput(Driver, "SetParentAttachment");
		
		//		SetEntProp(entity, Prop_Send, "m_nSolidType", 2);
		
		ViewEnt[Driver] = EntIndexToEntRef(sprite);
		
		
		SetEntProp(entity, Prop_Send, "m_bEnterAnimOn", 0);
		SetEntProp(entity, Prop_Send, "m_nSequence", 0);
		
		
		AcceptEntityInput(entity, "TurnOn");
		CarOn[entity] = true;
		
		/*
		for (new client = 1; client <= MaxClients; client++) 
		{ 
			if (IsClientInGame(client) && IsPlayerAlive(client))
			{
				if (client != Driver)
				{
					TeleportEntity(client, NULL_VECTOR, CurrentEyeAngle[client], NULL_VECTOR);
				}
			}
		}
		*/
	}
	if (Driver > 0)
	{
		Driving[Driver] = true;
		buttons2 = GetClientButtons(Driver);
		// Brake Lights on or Off
		
		if (buttons2 & IN_ATTACK) {
			EmitSoundToAll("vehicles/mustang_horn.mp3", Driver, SNDCHAN_AUTO, SNDLEVEL_AIRCRAFT);
		}
		
		
	}
	float ang[3];
	GetEntPropVector(entity, Prop_Data, "m_angRotation", ang);
	
	
} 