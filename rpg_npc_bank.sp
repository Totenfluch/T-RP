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
#include <rpg_npc_core>
#include <tConomy>
#include <multicolors>

#pragma newdecls required

char my_npcType[128] = "Bank";

int g_iLastInteractedWith[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[T-RP] Npc: Bank", 
	author = PLUGIN_AUTHOR, 
	description = "Adds a Bank System to T-RP", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart() {
	npc_registerNpcType(my_npcType);
}

public void OnNpcInteract(int client, char npcType[64], char UniqueId[128], int entIndex) {
	if (!StrEqual(my_npcType, npcType))
		return;
	g_iLastInteractedWith[client] = entIndex;
	Handle menu = CreateMenu(bankMenuHandler);
	char menuTitle[128];
	Format(menuTitle, sizeof(menuTitle), "Balance: %i", tConomy_getBankCurrency(client));
	SetMenuTitle(menu, menuTitle);
	AddMenuItem(menu, "withdraw", "Withdraw Money");
	AddMenuItem(menu, "deposit", "Deposit Money");
	AddMenuItem(menu, "transfer", "Transfer Money");
	DisplayMenu(menu, client, 60);
	
}

public int bankMenuHandler(Handle menu, MenuAction action, int client, int item) {
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
		if (StrEqual(cValue, "withdraw")) {
			openWithdrawMenu(client);
		} else if (StrEqual(cValue, "deposit")) {
			openDepositMenu(client);
		} else if (StrEqual(cValue, "transfer")) {
			openTransferMenu(client);
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void openWithdrawMenu(int client) {
	int moneyInBank = tConomy_getBankCurrency(client);
	Menu menu = CreateMenu(withdrawMenuHandler);
	char menuTitle[256];
	Format(menuTitle, sizeof(menuTitle), "Withdraw Money (max %i)", moneyInBank);
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

public int withdrawMenuHandler(Handle menu, MenuAction action, int client, int item) {
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
		if (StrEqual(cValue, "all")) {
			int bankMoney = tConomy_getBankCurrency(client);
			tConomy_addCurrency(client, bankMoney, "Withdraw from Bank");
			tConomy_removeBankCurrency(client, bankMoney, "Withdraw from Bank");
		} else {
			int iValue = StringToInt(cValue);
			if (iValue <= tConomy_getBankCurrency(client)) {
				tConomy_removeBankCurrency(client, iValue, "Withdraw from Bank");
				tConomy_addCurrency(client, iValue, "Withdraw from Bank");
			} else {
				return;
			}
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void openDepositMenu(int client) {
	int moneyInHand = tConomy_getCurrency(client);
	Menu menu = CreateMenu(depositMenuHandler);
	char menuTitle[256];
	Format(menuTitle, sizeof(menuTitle), "Deposit Money (max %i)", moneyInHand);
	SetMenuTitle(menu, menuTitle);
	AddMenuItem(menu, "all", "Everything");
	
	int tempMoney = 20;
	int increaseBy = 20;
	int step = 0;
	int reduce = 0;
	while (tempMoney <= moneyInHand) {
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

public int depositMenuHandler(Handle menu, MenuAction action, int client, int item) {
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
		if (StrEqual(cValue, "all")) {
			int handMoney = tConomy_getCurrency(client);
			tConomy_addBankCurrency(client, handMoney, "Deposit in Bank");
			tConomy_removeCurrency(client, handMoney, "Desposit in Bank");
		} else {
			int iValue = StringToInt(cValue);
			if (iValue <= tConomy_getCurrency(client)) {
				tConomy_addBankCurrency(client, iValue, "Desposit in Bank");
				tConomy_removeCurrency(client, iValue, "Desposit in Bank");
			} else {
				return;
			}
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public void openTransferMenu(int client) {
	Handle menu = CreateMenu(transferMenuHandler);
	SetMenuTitle(menu, "Choose amount to transfer");
	int moneyInBank = tConomy_getBankCurrency(client);
	
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


public int transferMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		Handle menu2 = CreateMenu(transferMenuHandler2);
		
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		SetMenuTitle(menu2, "Choose Target to transfer %s", cValue);
		
		for (int i = 1; i <= MAXPLAYERS; i++) {
			if (i == client)
				continue;
			
			if (!isValidClient(i))
				continue;
			
			if (IsFakeClient(i))
				continue;
			
			char Id[128];
			IntToString(i, Id, sizeof(Id));
			
			char targetName[MAX_NAME_LENGTH + 1];
			GetClientName(i, targetName, sizeof(targetName));
			
			char info[64];
			Format(info, sizeof(info), "%s %s", Id, cValue);
			
			AddMenuItem(menu2, info, targetName);
		}
		
		DisplayMenu(menu2, client, 60);
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public int transferMenuHandler2(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[64];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		char cValues[2][64];
		ExplodeString(cValue, " ", cValues, sizeof(cValues), 64);
		
		int target = StringToInt(cValues[0]);
		if (!isValidClient(target))
			return;
		
		int amount = StringToInt(cValues[1]);
		
		if (tConomy_getBankCurrency(client) < amount) {
			CPrintToChat(client, "{green}[{purple}tConomy{green}] {orange}You do not have enough money");
			return;
		}
		
		
		char playerid[20];
		GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
		
		char targetid[20];
		GetClientAuthId(target, AuthId_Steam2, targetid, sizeof(targetid));
		
		char transferReason[256];
		Format(transferReason, sizeof(transferReason), "Transfer From %N (%s) TO %N (%s)", client, playerid, target, targetid);
		
		tConomy_removeBankCurrency(client, amount, transferReason);
		tConomy_addBankCurrency(target, amount, transferReason);
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

stock bool isValidClient(int client) {
	return (1 <= client <= MaxClients && IsClientInGame(client));
} 