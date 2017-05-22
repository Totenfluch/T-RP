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
#include <rpg_interact>
#include <tConomy>

#pragma newdecls required

int g_iPlayerTarget[MAXPLAYERS + 1];
char g_cInteraction[64] = "Give Money";

public Plugin myinfo = 
{
	name = "[T-RP] Interact: Money", 
	author = PLUGIN_AUTHOR, 
	description = "Adds the Option 'Give Money' to T-RP interact", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart() {  }

public void OnMapStart() {
	interact_registerInteract(g_cInteraction);
}

public void OnClientPostAdminCheck(int client) {
	g_iPlayerTarget[client] = -1;
}

public void OnPlayerInteract(int client, int target, char interaction[64]) {
	if (!StrEqual(g_cInteraction, interaction))
		return;
	
	int moneyInBank = tConomy_getCurrency(client);
	Menu menu = CreateMenu(giveMoneyMenuHandler);
	char menuTitle[256];
	Format(menuTitle, sizeof(menuTitle), "Give %N Money", g_iPlayerTarget[client]);
	SetMenuTitle(menu, menuTitle);
	AddMenuItem(menu, "all", "Everything");
	
	int tempMoney = 20;
	int increaseBy = 20;
	int step = 0;
	int reduce = 0;
	while (tempMoney <= moneyInBank) {
		char cTempMoney[128];
		IntToString(tempMoney, cTempMoney, sizeof(cTempMoney));
		AddMenuItem(menu, cTempMoney, cTempMoney);
		if (++step < (5 - reduce))
			tempMoney += increaseBy;
		else {
			increaseBy *= 5;
			step = 0;
			tempMoney += increaseBy;
			reduce = 1;
		}
	}
	DisplayMenu(menu, client, 60);
}

public int giveMoneyMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		float playerPos[3];
		float entPos[3];
		if (!isValidClient(client))
			return;
		if (!isValidClient(g_iPlayerTarget[client]))
			return;
		GetClientAbsOrigin(client, playerPos);
		GetClientAbsOrigin(g_iPlayerTarget[client], entPos);
		if (GetVectorDistance(playerPos, entPos) > 100.0)
			return;
		char cValue[32];
		char reason1[256];
		char reason2[256];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "all")) {
			int handMoney = tConomy_getCurrency(client);
			if (handMoney <= 0)
				return;
			Format(reason1, sizeof(reason1), "Gave %i to %N", handMoney, g_iPlayerTarget[client]);
			Format(reason2, sizeof(reason2), "Recieved %i from %N", handMoney, client);
			tConomy_removeCurrency(client, handMoney, reason1);
			tConomy_addCurrency(g_iPlayerTarget[client], handMoney, reason2);
		} else {
			int iValue = StringToInt(cValue);
			if (iValue <= tConomy_getCurrency(client)) {
				Format(reason1, sizeof(reason1), "Gave %i to %N", iValue, g_iPlayerTarget[client]);
				Format(reason2, sizeof(reason2), "Recieved %i from %N", iValue, client);
				tConomy_removeCurrency(client, iValue, reason1);
				tConomy_addCurrency(g_iPlayerTarget[client], iValue, reason2);
			} else {
				return;
			}
		}
		
	}
}

public void OnPlayerInteractionStarted(int client, int target) {
	g_iPlayerTarget[client] = target;
}

stock bool isValidClient(int client) {
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client))
		return false;
	
	return true;
}
