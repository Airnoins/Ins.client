
#define LENGTH_64 64


//////////////////////////////
//          GLOBAL          //
//////////////////////////////

#define client_DB "Client"

#define Welcome_Text "\x04▲ 欢迎 ???%N<%d>\x01,\x04加入游戏 - \x03权限等级\x08[\x0B%s\x08] - \x03点数\x08[\x0B%d\x08] - \x03等级Lv.{gold}%d \x08-"

int g_iDBStatus = 0; // 0 - Def., 1 - Reconnect, 2 - Unknown Driver, 3 - Create Table, 4 - Ready to Query

char g_sCurrentMap[32];
char g_sServerName[32];

int g_iMaxPlayers = 0;
int g_iCurrentPlayers = 0;

Database clientDB;

//////////////////////////////
//          PLAYER          //
//////////////////////////////
int g_iPlayerId[MAXPLAYERS + 1];
int g_iPoint[MAXPLAYERS + 1];
int g_iLevel[MAXPLAYERS + 1];

int g_iCurrentPoint[MAXPLAYERS + 1];
int g_iPointTimerCount[MAXPLAYERS + 1];

char g_sClientName[MAXPLAYERS + 1][LENGTH_64];
char g_sSteamId[MAXPLAYERS + 1][LENGTH_64];
char g_sSteam64Id[MAXPLAYERS + 1][LENGTH_64];
char g_sClientIP[MAXPLAYERS + 1][LENGTH_64];
char g_sJoinTime[MAXPLAYERS + 1][LENGTH_64];
char g_sPermissions[MAXPLAYERS + 1][LENGTH_64];
char g_sAuthentication[MAXPLAYERS + 1][LENGTH_64];
char g_sCountry[MAXPLAYERS + 1][16];

bool g_bIsPlayer[MAXPLAYERS + 1] = {false, ...};
bool g_bClientAuth[MAXPLAYERS + 1] = {false, ...};
bool g_bDeveloper[MAXPLAYERS + 1] = {false, ...};

char Developer_AuthList[][] = {
	"超凡贡献", "技术大佬", "Mapper", "Programmer",
	"root"
};

///////////////////////////////////////////////

stock void CM_Global_OnPluginStart()
{
	g_iMaxPlayers = GetMaxHumanPlayers();

	CreateTimer(1.00, CM_Global_Timer, _, TIMER_REPEAT);
}

stock void CM_Global_OnMapStart()
{
	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
}

stock Action CM_Global_Timer(Handle Timer)
{
	g_iCurrentPlayers = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
			g_iCurrentPlayers += 1;
	}

	return Plugin_Continue;
}

stock bool IsDeveloper(const char[] Authentication)
{
	for(int i = 0; i < sizeof(Developer_AuthList); i++)
	{
		if(StrEqual(Authentication, Developer_AuthList[i], false))
		{
			return true;
		}
	}
	return false;
}