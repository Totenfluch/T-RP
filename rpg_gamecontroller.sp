#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "Server Control for RP", 
	author = PLUGIN_AUTHOR, 
	description = "Handles Round start/End Maptime", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart() {
	SetServerConvars();
	HookEvent("round_start", onRoundStart);
}

public void OnMapStart() {
	ServerCommand("mp_restartgame 1");
	CreateTimer(10.0, restart);
}

public Action restart(Handle Timer) {
	ServerCommand("mp_restartgame 1");
}

public void onRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	SetServerConvars();
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
