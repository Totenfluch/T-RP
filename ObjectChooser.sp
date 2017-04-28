#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR ""
#define PLUGIN_VERSION "0.00"

#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <rpg_devzones>

bool g_bObjectChooserEnabled[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Totenfluch", 
	author = PLUGIN_AUTHOR, 
	description = "Gives the Object Name", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de/"
};

int g_iPlayerPrevButtons[MAXPLAYERS + 1];

public void OnPluginStart()
{
	RegConsoleCmd("sm_oc", ocCb);
	RegConsoleCmd("sm_czone", czone);
}


public Action ocCb(int client, int args) {
	g_bObjectChooserEnabled[client] = !g_bObjectChooserEnabled[client];
	PrintToChat(client, "Changed Objectchooser to %d", g_bObjectChooserEnabled[client]);
	return Plugin_Handled;
}

public Action czone(int client, int args){
	char tbuffer[64];
	bool found = Zone_getMostRecentActiveZone(client, tbuffer);
	PrintToChat(client, ":: Zone:|%s|", found ? tbuffer : "No Active Zone");
	return Plugin_Handled;
}

public void OnClientPostAdminCheck(int client) {
	g_bObjectChooserEnabled[client] = false;
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon, int &tickcount)
{
	
	if (IsClientInGame(client) && IsPlayerAlive(client))
	{
		if (!(g_iPlayerPrevButtons[client] & IN_USE) && iButtons & IN_USE)
		{
			if (g_bObjectChooserEnabled[client]) {
				int TargetObject = GetTargetBlock(client);
				if (IsValidEntity(TargetObject))
				{
					char ObjectName[255];
					Entity_GetGlobalName(TargetObject, ObjectName, sizeof(ObjectName));
					char classname[32];
					GetEdictClassname(TargetObject, classname, 32);
					char ObjectName2[255];
					GetEntPropString(TargetObject, Prop_Data, "m_iName", ObjectName2, sizeof(ObjectName2));
					
					char ObjectName3[255];
					GetEntPropString(TargetObject, Prop_Data, "m_iParent", ObjectName3, sizeof(ObjectName3));
					
					char ObjectName4[255];
					if (HasEntProp(TargetObject, Prop_Data, "m_SlaveName"))
						GetEntPropString(TargetObject, Prop_Data, "m_SlaveName", ObjectName4, sizeof(ObjectName4));
					else
						Format(ObjectName4, sizeof(ObjectName4), "NONE");
					
					
					PrintToChat(client, "Object: ID: |%s| classname: |%s|%s|%s|%s", ObjectName, classname, ObjectName2, ObjectName3, ObjectName4);
				}
			}
		}
		g_iPlayerPrevButtons[client] = iButtons;
	}
}

public int Zone_OnClientEntry(int client, char[] zone) {
	if (g_bObjectChooserEnabled[client])
		PrintToChat(client, "Entry: %s", zone);
}

public int Zone_OnClientLeave(int client, char[] zone) {
	if (g_bObjectChooserEnabled[client])
		PrintToChat(client, "Exit: %s", zone);
}

stock int GetTargetBlock(int client)
{
	int entity = GetClientAimTarget(client, false);
	if (IsValidEdict(entity))
	{
		
		return entity;
	}
	return -1;
}
