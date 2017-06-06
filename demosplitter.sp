#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#pragma newdecls required

#define SPLITTIME 60

int g_iCurrentSplitTime = 0;

char oldTime[20];

public Plugin myinfo = 
{
	name = "[T-RP] Demo Splitter", 
	author = PLUGIN_AUTHOR, 
	description = "Splitts demos in 1h chunks", 
	version = PLUGIN_VERSION, 
	url = "https://totenfluch.de"
};

public void OnPluginStart() {
	g_iCurrentSplitTime = 0;
	RegAdminCmd("sm_splitnow", splitDemoNow, ADMFLAG_ROOT, "Splits the Demo instantly");
}

public void OnMapStart() {
	g_iCurrentSplitTime = 0;
	CreateTimer(60.0, splitTick, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	FormatTime(oldTime, sizeof(oldTime), "%d-%m-%Y-%H-%M-%S", GetTime());
	splitDemo();
}

public void OnMapEnd() {
	ServerCommand("tv_stoprecord");
}

public Action splitTick(Handle Timer) {
	g_iCurrentSplitTime++;
	if (g_iCurrentSplitTime == SPLITTIME) {
		splitDemo();
		g_iCurrentSplitTime = 0;
	}
}

public Action splitDemoNow(int client, int args) {
	splitDemo();
	g_iCurrentSplitTime = 0;
	return Plugin_Handled;
}

public void splitDemo() {
	char sTime[20];
	FormatTime(sTime, sizeof(sTime), "%d-%m-%Y-%H-%M-%S", GetTime());
	
	char demoTitle[64];
	Format(demoTitle, sizeof(demoTitle), "TRP_%s_%s", oldTime, sTime);
	
	ServerCommand("tv_stoprecord");
	ServerCommand("tv_record %s", demoTitle);
	
	strcopy(oldTime, sizeof(oldTime), sTime);
}
