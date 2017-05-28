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
#include <autoexecconfig>
#include <rpg_jobs_core>
#include <rpg_npc_core>
#include <rpg_inventory_core>
#include <rpg_interact>
#include <multicolors>
#include <tStocks>
#include <tConomy>
#include <tCrime>

#pragma newdecls required

int g_iBleedingLevel[MAXPLAYERS + 1];
int g_iBleedGraceTime[MAXPLAYERS + 1];
int g_iPlayerTarget[MAXPLAYERS + 1];
int g_iBloodGroup[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[T-RP] Job: Medic", 
	author = PLUGIN_AUTHOR, 
	description = "Adds the Medic for T-RP", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart() {
	HookEvent("player_hurt", onPlayerHurt);
	HookEvent("player_death", onPlayerDeath);
	
	for (int i = 1; i < MAXPLAYERS; i++)
	if (isValidClient(i))
		loadPlayerVariables(i);
}

public void OnMapStart() {
	jobs_registerJob("Medic", "Bandage all the bleeding people and infuse them with blood", 20, 600, 2.6);
	npc_registerNpcType("Medic Recruiter");
	interact_registerInteract("Bandage him");
	interact_registerInteract("Infuse Bloodbag");
	interact_registerInteract("Test Blood Group");
	CreateTimer(1.0, refreshTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientAuthorized(int client) {
	loadPlayerVariables(client);
}

public void loadPlayerVariables(int client) {
	g_iBleedingLevel[client] = 0;
	g_iBleedGraceTime[client] = 0;
	g_iBloodGroup[client] = -1;
	
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	char pId[12];
	strcopy(pId, sizeof(pId), playerid[8]);
	int bGroup = StringToInt(pId);
	if (bGroup % 2 == 0 && StrContains(pId, "2") != -1 && StrContains(pId, "7") != -1)
		g_iBloodGroup[client] = 0; // AB
	else if (bGroup % 2 == 0)
		g_iBloodGroup[client] = 1; // A
	else
		g_iBloodGroup[client] = 2; // B
}

public Action onPlayerDeath(Handle event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	g_iBleedingLevel[client] = 0;
	g_iBleedGraceTime[client] = 0;
}

public void OnPlayerInteract(int client, int target, char interaction[64]) {
	if (StrEqual(interaction, "Bandage him")) {
		if (jobs_isActiveJob(client, "Medic")) {
			if (g_iBleedingLevel[target] > 0) {
				if (inventory_hasPlayerItem(client, "Bandage")) {
					g_iPlayerTarget[client] = GetClientUserId(target);
					jobs_startProgressBar(client, g_iBleedingLevel[target], "Bandaging Player");
				} else {
					CPrintToChat(client, "{red}[-T-] You do not have a Bandage");
				}
			} else {
				CPrintToChat(client, "{red}[-T-] %N is not bleeding!", target);
			}
		} else {
			CPrintToChat(client, "{red}[-T-] You are not a Medic");
		}
	} else if (StrEqual(interaction, "Infuse Bloodbag")) {
		if (jobs_isActiveJob(client, "Medic")) {
			g_iPlayerTarget[client] = GetClientUserId(target);
			Menu m = new Menu(infuseBloodBagMenuHandler);
			SetMenuTitle(m, "Which Blood Bag?");
			AddMenuItem(m, "ab", "Blood Bag -AB-", inventory_hasPlayerItem(client, "Blood Bag -AB-") ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
			AddMenuItem(m, "a", "Blood Bag -A-", inventory_hasPlayerItem(client, "Blood Bag -A-") ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
			AddMenuItem(m, "b", "Blood Bag -B-", inventory_hasPlayerItem(client, "Blood Bag -B-") ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
			DisplayMenu(m, client, 20);
		} else {
			CPrintToChat(client, "{red}[-T-] You are not a Medic");
		}
	} else if (StrEqual(interaction, "Test Blood Group")) {
		if (jobs_isActiveJob(client, "Medic")) {
			if (inventory_hasPlayerItem(client, "Bloodtest")) {
				if (inventory_removePlayerItems(client, "Bloodtest", 1, "Made Blood Test")) {
					if (g_iBloodGroup[target] == 0) {
						CPrintToChat(client, "{green}[-T-] %N has the Blood Group AB", target);
					} else if (g_iBloodGroup[target] == 1) {
						CPrintToChat(client, "{green}[-T-] %N has the Blood Group A", target);
					} else if (g_iBloodGroup[target] == 2) {
						CPrintToChat(client, "{green}[-T-] %N has the Blood Group B", target);
					}
					jobs_addExperience(client, 5, "Tested Blood");
				}
			}
		} else {
			CPrintToChat(client, "{red}[-T-] You are not a Medic");
		}
	}
}

int g_iTypeOverTake[MAXPLAYERS + 1];
public int infuseBloodBagMenuHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		int target = GetClientOfUserId(g_iPlayerTarget[client]);
		float playerPos[3];
		float targetPos[3];
		if (!isValidClient(client))
			return;
		if (!isValidClient(target))
			return;
		GetClientAbsOrigin(client, playerPos);
		GetClientAbsOrigin(target, targetPos);
		if (GetVectorDistance(playerPos, targetPos) > 100.0) {
			CPrintToChat(client, "{green}[-T-] %N is too far away", target);
			return;
		}
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "ab")) {
			if (inventory_removePlayerItems(client, "Blood Bag -AB-", 1, "Made Infusuion")) {
				jobs_startProgressBar(client, 70, "Infuseing Blood Bag (AB)");
				g_iTypeOverTake[client] = 0;
			}
		} else if (StrEqual(cValue, "a")) {
			if (inventory_removePlayerItems(client, "Blood Bag -A-", 1, "Made Infusuion")) {
				jobs_startProgressBar(client, 70, "Infuseing Blood Bag (A)");
				g_iTypeOverTake[client] = 1;
			}
		} else if (StrEqual(cValue, "b")) {
			if (inventory_removePlayerItems(client, "Blood Bag -B-", 1, "Made Infusuion")) {
				jobs_startProgressBar(client, 70, "Infuseing Blood Bag (B)");
				g_iTypeOverTake[client] = 2;
			}
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}
public void jobs_OnProgressBarFinished(int client, char info[64]) {
	if (!isValidClient(client))
		return;
	if (StrEqual(info, "Bandaging Player")) {
		int target = GetClientOfUserId(g_iPlayerTarget[client]);
		if (isValidClient(target)) {
			CPrintToChat(client, "{green}[-T-] You bandaged %N", target);
			CPrintToChat(target, "{green}[-T-] You were bandaged by %N (Bleeding stopped)", client);
			jobs_addExperience(client, 2 * g_iBleedingLevel[target] + 20, "Medic");
			g_iBleedingLevel[target] = 0;
			g_iPlayerTarget[client] = -1;
		}
	} else if (StrContains(info, "Infuseing Blood Bag") != -1) {
		int target = GetClientOfUserId(g_iPlayerTarget[client]);
		if (isValidClient(target)) {
			if (g_iTypeOverTake[client] == g_iBloodGroup[target]) {
				SetEntityHealth(target, 100 + jobs_getLevel(client));
				CPrintToChat(client, "{green}[-T-] You infused %N", target);
				CPrintToChat(target, "{green}[-T-] You were infused by %N", client);
				jobs_addExperience(client, 250 + jobs_getLevel(client) * 10, "Medic");
			} else {
				CPrintToChat(client, "{green}[-T-] Blood infusion of %N failed (Wrong Blood Group)", target);
				CPrintToChat(target, "{green}[-T-] %N failed to infuse you (Wrong Blood Group)", client);
				jobs_removeExperience(client, 1500, "Medic");
				if (GetRandomInt(0, 1) == 1) {
					FakeClientCommand(target, "kill");
					CPrintToChat(target, "{green}[-T-] %N killed you with a false infusion", client);
					tCrime_addCrime(client, 3000);
				}
			}
		}
	}
}

public void onPlayerHurt(Handle event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int hurtdmg = GetEventInt(event, "dmg_health");
	
	if (!isValidClient(attacker))
		return;
	
	char weapon[64];
	GetClientWeapon(attacker, weapon, sizeof(weapon));
	
	
	if ((GetRandomInt(0, 12) * hurtdmg) > 80) {
		g_iBleedingLevel[victim] = hurtdmg;
		if (hurtdmg < 100)
			g_iBleedGraceTime[victim] = 100 - hurtdmg;
		else
			g_iBleedGraceTime[victim] = 1;
		CPrintToChat(victim, "{red}[-T-] You are bleeding! Find a Medic");
	}
}

public Action refreshTimer(Handle Timer) {
	for (int i = 1; i < MAXPLAYERS; i++) {
		if (!isValidClient(i))
			continue;
		if (g_iBleedingLevel[i] == 0)
			continue;
		if (g_iBleedGraceTime[i] <= 0)
			bleedTick(i);
		else
			g_iBleedGraceTime[i]--;
	}
}

public void bleedTick(int client) {
	if ((45 - g_iBleedingLevel[client]) < 0)
		g_iBleedGraceTime[client] = 10;
	else
		g_iBleedGraceTime[client] = 60 - g_iBleedingLevel[client];
	
	int hp = GetClientHealth(client);
	int group = 0;
	if (g_iBleedingLevel[client] > 60) {
		group = 6;
	} else if (g_iBleedingLevel[client] >= 30 && g_iBleedingLevel[client] <= 60) {
		group = 3;
	} else if (g_iBleedingLevel[client] < 30 && g_iBleedingLevel[client] >= 10) {
		group = 2;
	} else if (g_iBleedingLevel[client] < 10) {
		group = 1;
	}
	
	if (hp <= 10) {
		group = 1;
		g_iBleedGraceTime[client] = 30;
	}
	int setHp = hp - group;
	if (setHp <= 0) {
		FakeClientCommand(client, "kill");
		CPrintToChat(client, "{red}[-T-] You died from bleeding damage");
	} else {
		SetEntityHealth(client, setHp);
		CPrintToChat(client, "{red}[-T-] You took %i Bleeding Damage", group);
	}
}

public void OnNpcInteract(int client, char npcType[64], char UniqueId[128], int entIndex) {
	if (!StrEqual(npcType, "Medic Recruiter"))
		return;
	char activeJob[128];
	jobs_getActiveJob(client, activeJob);
	Menu panel = CreateMenu(JobPanelHandler);
	if (StrEqual(activeJob, "") || !jobs_isActiveJob(client, "Medic")) {
		SetMenuTitle(panel, "Do you want to be a Medic?");
		AddMenuItem(panel, "x", "No thanks");
		AddMenuItem(panel, "givejob", "Yes, teach me!");
		if (!isMedicOnline())
			AddMenuItem(panel, "bandageMe", "Get Bandaged (150$)", tConomy_getCurrency(client) >= 150 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}
	if (jobs_isActiveJob(client, "Medic")) {
		SetMenuTitle(panel, "Medic Shop");
		AddMenuItem(panel, "bandage", "Buy Bandage (40$)", tConomy_getCurrency(client) >= 40 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		AddMenuItem(panel, "bt", "Buy Bloodtest [2](20$)", tConomy_getCurrency(client) >= 20 && jobs_getLevel(client) >= 2 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		AddMenuItem(panel, "bba", "Buy Blood Bag -A- [2](120$)", tConomy_getCurrency(client) >= 120 && jobs_getLevel(client) >= 2 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		AddMenuItem(panel, "bbb", "Buy Blood Bag -B- [2](120$)", tConomy_getCurrency(client) >= 120 && jobs_getLevel(client) >= 2 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		AddMenuItem(panel, "bbab", "Buy Blood Bag -AB- [2](140$)", tConomy_getCurrency(client) >= 120 && jobs_getLevel(client) >= 2 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		AddMenuItem(panel, "heal", "Heal to full 100Hp [5](450$)", tConomy_getCurrency(client) >= 450 && jobs_getLevel(client) >= 5 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		
		AddMenuItem(panel, "skin1", "First Medic Skin [2](500$)", tConomy_getCurrency(client) >= 500 && jobs_getLevel(client) >= 2 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		AddMenuItem(panel, "skin2", "Second Medic Skin [3](1500$)", tConomy_getCurrency(client) >= 500 && jobs_getLevel(client) >= 3 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		AddMenuItem(panel, "skin3", "Third Medic Skin [5](2500$)", tConomy_getCurrency(client) >= 500 && jobs_getLevel(client) >= 5 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		AddMenuItem(panel, "skin4", "Fourth Medic Skin [8](5000$)", tConomy_getCurrency(client) >= 500 && jobs_getLevel(client) >= 8 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}
	DisplayMenu(panel, client, 60);
}

public int JobPanelHandler(Handle menu, MenuAction action, int client, int item) {
	if (action == MenuAction_Select) {
		char cValue[32];
		GetMenuItem(menu, item, cValue, sizeof(cValue));
		if (StrEqual(cValue, "givejob")) {
			jobs_giveJob(client, "Medic");
		} else if (StrEqual(cValue, "bandage")) {
			if (tConomy_getCurrency(client) >= 40) {
				tConomy_removeCurrency(client, 40, "Bough Bandage");
				inventory_givePlayerItem(client, "Bandage", 10, "", "Crafting Material", "Medic Stuff", 2, "Bought from Vendor");
			}
		} else if (StrEqual(cValue, "bba")) {
			if (tConomy_getCurrency(client) >= 120) {
				tConomy_removeCurrency(client, 120, "Bought Blood Bag -A-");
				inventory_givePlayerItem(client, "Blood Bag -A-", 15, "", "Crafting Material", "Medic Stuff", 2, "Bought from Vendor");
			}
		} else if (StrEqual(cValue, "bbb")) {
			if (tConomy_getCurrency(client) >= 120) {
				tConomy_removeCurrency(client, 120, "Bought Blood Bag -B-");
				inventory_givePlayerItem(client, "Blood Bag -B-", 15, "", "Crafting Material", "Medic Stuff", 2, "Bought from Vendor");
			}
		} else if (StrEqual(cValue, "bbab")) {
			if (tConomy_getCurrency(client) >= 140) {
				tConomy_removeCurrency(client, 140, "Bought Blood Bag -AB-");
				inventory_givePlayerItem(client, "Blood Bag -AB-", 15, "", "Crafting Material", "Medic Stuff", 2, "Bought from Vendor");
			}
		} else if (StrEqual(cValue, "bt")) {
			if (tConomy_getCurrency(client) >= 20) {
				tConomy_removeCurrency(client, 20, "Bought Bloodtest");
				inventory_givePlayerItem(client, "Bloodtest", 10, "", "Crafting Material", "Medic Stuff", 2, "Bought from Vendor");
			}
		} else if (StrEqual(cValue, "bandageMe")) {
			if (tConomy_getCurrency(client) >= 150) {
				tConomy_removeCurrency(client, 150, "Bandaged by Npc");
				g_iBleedingLevel[client] = 0;
				CPrintToChat(client, "{green}[-T-] You were bandaged by the Medic Recruiter (Bleeding stopped)");
			}
		} else if (StrEqual(cValue, "heal")) {
			if (tConomy_getCurrency(client) >= 450) {
				tConomy_removeCurrency(client, 450, "Healed by Npc");
				CPrintToChat(client, "{green}[-T-] You were healed by the Medic Recruiter");
				if (isValidClient(client) && IsPlayerAlive(client))
					SetEntityHealth(client, 100);
			}
		} else if (StrEqual(cValue, "skin1")) {
			if (tConomy_getCurrency(client) >= 500 && jobs_getLevel(client) >= 2) {
				tConomy_removeCurrency(client, 500, "Bought Medic Skin1");
				inventory_givePlayerItem(client, "Medic 1", 0, "", "Skin", "Skin", 1, "Bought from Medic Recruiter");
			}
		} else if (StrEqual(cValue, "skin2")) {
			if (tConomy_getCurrency(client) >= 1500 && jobs_getLevel(client) >= 3) {
				tConomy_removeCurrency(client, 1500, "Bought Medic Skin2");
				inventory_givePlayerItem(client, "Medic 2", 0, "", "Skin", "Skin", 1, "Bought from Medic Recruiter");
			}
		} else if (StrEqual(cValue, "skin3")) {
			if (tConomy_getCurrency(client) >= 2500 && jobs_getLevel(client) >= 5) {
				tConomy_removeCurrency(client, 2500, "Bought Medic Skin3");
				inventory_givePlayerItem(client, "Medic 3", 0, "", "Skin", "Skin", 1, "Bought from Medic Recruiter");
			}
		} else if (StrEqual(cValue, "skin4")) {
			if (tConomy_getCurrency(client) >= 5000 && jobs_getLevel(client) >= 8) {
				tConomy_removeCurrency(client, 5000, "Bought Medic Skin4");
				inventory_givePlayerItem(client, "Medic 4", 0, "", "Skin", "Skin", 1, "Bought from Medic Recruiter");
			}
		}
	}
	if (action == MenuAction_End) {
		delete menu;
	}
}

public bool isMedicOnline() {
	for (int i = 1; i < MAXPLAYERS; i++) {
		if (!isValidClient(i))
			continue;
		if (jobs_isActiveJob(i, "Medic"))
			return true;
	}
	return false;
} 