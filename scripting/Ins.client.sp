#pragma semicolon 1
#pragma newdecls required


//////////////////////////////
//    PLUGIN DEFINITION     //
//////////////////////////////
#define PLUGIN_NAME         "Client - redux(Beta)"
#define PLUGIN_AUTHOR       "Ins"
#define PLUGIN_DESCRIPTION  "Client-related features(Only MySql is supported)"
#define PLUGIN_VERSION      "1.5.1"
#define PLUGIN_URL          "https://space.bilibili.com/442385547"

public Plugin myinfo =
{
	name 		= PLUGIN_NAME,
	author 		= PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version 	= PLUGIN_VERSION,
	url 		= PLUGIN_URL
};


//////////////////////////////
//          INCLUDES        //
//////////////////////////////
#include <sourcemod>
#include <geoip>
#include <smutils>

//////////////////////////////
//          DEFINE          //
//////////////////////////////
#define client_DB "Client"
#define LENGTH_64 64
#define ONE_MINUTE 60

#define Welcome_Text "\x04▲ 欢迎 ???%N<%d>\x01,\x04加入游戏 - \x03权限等级\x08[\x0B%s\x08] - \x03点数\x08[\x0B%d\x08] - \x03等级Lv.{gold}%d \x08-"

int g_iDBStatus = 0; // 0 - Def., 1 - Reconnect, 2 - Unknown Driver, 3 - Create Table, 4 - Ready to Query

int g_iPlayerId[MAXPLAYERS + 1];
int g_iPoint[MAXPLAYERS + 1];
int g_iLevel[MAXPLAYERS + 1];

int g_iCurrentPoint[MAXPLAYERS + 1];

char g_sClientName[MAXPLAYERS + 1][LENGTH_64];
char g_sSteamId[MAXPLAYERS + 1][LENGTH_64];
char g_sSteam64Id[MAXPLAYERS + 1][LENGTH_64];
char g_sClientIP[MAXPLAYERS + 1][LENGTH_64];
char g_sJoinTime[MAXPLAYERS + 1][LENGTH_64];
char g_sPermissions[MAXPLAYERS + 1][LENGTH_64];
char g_sAuthentication[MAXPLAYERS + 1][LENGTH_64];
char g_sCountry[MAXPLAYERS + 1][16];

char g_sCurrentTime[32];

bool g_bWelcome[MAXPLAYERS + 1] = {false, ...};
bool g_bClientAuth[MAXPLAYERS + 1] = {false, ...};
bool g_bDeveloper[MAXPLAYERS + 1] = {false, ...};

char Developer_AuthList[][] = {
	"超凡贡献", "技术大佬", "Mapper", "Programmer",
	"root"
};

Handle Point_Timer = null;

Database clientDB;

//////////////////////////////
//          API             //
//////////////////////////////

public void OnPluginStart()
{
	RegConsoleCmd("sm_client", command_client, "Query client information");

	SMUtils_SetChatPrefix("\x01[\x04Ins.client\x01]");
	SMUtils_SetChatSpaces("   ");
	SMUtils_SetChatConSnd(false);
	SMUtils_SetTextDest(HUD_PRINTCENTER);

	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEventEx("player_connect_full", Event_PlayerConnectFull, EventHookMode_Post);

	if(Point_Timer == null)
	{
		Point_Timer = CreateTimer(1.00, Point_TimerCallBack, _, TIMER_REPEAT);
	}

	Database.Connect(Client_ConnectCallBack, client_DB);
}

public void OnClientDisconnect(int client)
{
	ChatAll("\x04%N \x01已离开游戏", client);

	//Get client_LastAppeared
	if(g_iDBStatus == 4)
	{
		char Query[256];
		GetDate(0, "%Y-%m-%d %H:%M:%S", g_sCurrentTime, sizeof(g_sCurrentTime));
		FormatEx(Query, sizeof(Query), "UPDATE `Client_Information` SET `LastAppeared`='%s' WHERE `SteamId`='%s'", g_sCurrentTime, g_sSteamId[client]);
		SQL_FastQuery(clientDB, Query);

		UpdateClientLevel(client);
	}
	ClearDisconnectPlayerInfo(client);
}

public void Client_CreateTables()
{
	char sConnectDriverDB[16];
	clientDB.Driver.GetIdentifier(sConnectDriverDB, sizeof(sConnectDriverDB));
	if(strcmp(sConnectDriverDB, "mysql") == 0)
	{
		g_iDBStatus = 3;
		//Create MySQL Tables
		char sSQL_Query[1024];
		Transaction T_CreateTables = SQL_CreateTransaction();
		FormatEx(sSQL_Query, sizeof(sSQL_Query), "CREATE TABLE IF NOT EXISTS `Client_Information`(		`PlayerId` int(10) NOT NULL AUTO_INCREMENT COMMENT '玩家ID', \
																										`Name` varchar(32) NOT NULL COMMENT '玩家姓名', \
																										`SteamId` varchar(32) NOT NULL COMMENT 'AuthId_Steam2', \
																										`Steam64Id` varchar(32) NOT NULL COMMENT 'AuthId_SteamID64', \
																										`IP` varchar(32) NOT NULL COMMENT 'IP', \
																										`Permissions` varchar(16) NOT NULL COMMENT '权限等级', \
																										`Jointime` datetime NOT NULL COMMENT '注册时间', \
																										`LastAppeared` datetime NOT NULL COMMENT '最后出现时间', \
																										`Authentication` varchar(32) NOT NULL COMMENT '认证', \
																										`Point` int(10) NOT NULL COMMENT '点数', \
																										`Level` int(10) NOT NULL COMMENT '等级', \
																										PRIMARY KEY (PlayerId))");
		T_CreateTables.AddQuery(sSQL_Query);
		SQL_ExecuteTransaction(clientDB, T_CreateTables, Client_SQLCreateTables_Success, Client_SQLCreateTables_Error, _, DBPrio_High);
	}
	else
	{
		g_iDBStatus = 2;
		LogError("[Client DB] Unknown Driver: %s, cannot create tables.", sConnectDriverDB);
	}
}

//////////////////////////////
//         EVENT            //
//////////////////////////////

public Action Event_RoundStart(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	for(int i = 1; i < MaxClients; i++)
	{
		if(ClientIsValid(i) && g_iPlayerId[i] != 0)
		{
			SaveClientInfo(i);
		}
	}

	return Plugin_Continue;
}

public Action Event_PlayerConnectFull(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	//需要欢迎语句
	if(!g_bWelcome[client])
	{
		SaveClientInfo(client);
		if(g_iPlayerId[client] == 0)
		{
			Chat(client, "检测用户为首次加载,正在向云端上传数据");

			SaveClientInfoDB(client);
		}
		UpdateClientLevel(client);
		SaveClientInfo(client);

		ClientWelcome(client);
		g_bWelcome[client] = true;
	}

	return Plugin_Continue;
}

//////////////////////////////
//         TIMER            //
//////////////////////////////

public Action Point_TimerCallBack(Handle Timer)
{
	for(int i = 1; i < MaxClients; i++)
	{
		if(!ClientIsValid(i)) continue;

		if(g_iCurrentPoint[i] < ONE_MINUTE)
		{
			g_iCurrentPoint[i] += 1;
			continue;
		}
		UpdateClientPoint(i);
		g_iCurrentPoint[i] = 0;
	}
	return Plugin_Continue;
}

//////////////////////////////
//         COMMAND          //
//////////////////////////////

public Action ReConnectDB(Handle Timer)
{
	if(g_iDBStatus == 1)
	{
		Database.Connect(Client_ConnectCallBack, client_DB);
	}
	return Plugin_Stop;
}

public void SaveClientInfo(int client)
{
	GetClientName(client, g_sClientName[client], LENGTH_64);
	GetClientAuthId(client, AuthId_Steam2, g_sSteamId[client], LENGTH_64);
	GetClientAuthId(client, AuthId_SteamID64, g_sSteam64Id[client], LENGTH_64);
	GetClientIP(client, g_sClientIP[client], LENGTH_64);
	GeoipCountryEx(g_sClientIP[client], g_sCountry[client], 16, client);

	if(g_iDBStatus == 4 && IsPlayer(client))
	{
		char Query[512];
		FormatEx(Query, sizeof(Query),"SELECT `playerid`, `Jointime`, `Authentication` FROM `Client_Information` WHERE `SteamId`='%s'", g_sSteamId[client]);

		DBResultSet rs = null;
		rs = SQL_Query(clientDB, Query);

		while(SQL_FetchRow(rs))
		{
			g_iPlayerId[client] = SQL_FetchInt(rs, 0);
			SQL_FetchString(rs, 1, g_sJoinTime[client], LENGTH_64);
			if(StrEqual(g_sAuthentication[client], ""))
			{
				SQL_FetchString(rs, 2, g_sAuthentication[client], LENGTH_64);
			}
		}
	}

	if(!StrEqual(g_sAuthentication[client], "null"))
	{
		if(IsDeveloper(g_sAuthentication[client]))
		{
			g_bDeveloper[client] = true;
		}
		g_bClientAuth[client] = true;
	}
}

public void SaveClientInfoDB(int client)
{
	if(g_iDBStatus == 4)
	{
		char Query[512];
		GetDate(0, "%Y-%m-%d %H:%M:%S", g_sCurrentTime, sizeof(g_sCurrentTime));
		if(!IsPlayer(client))
		{
			FormatEx(Query, sizeof(Query), "INSERT INTO `Client_Information` (`Name`, `SteamId`, `Steam64Id`, `IP`, `Permissions`, `Jointime`, `LastAppeared`, `Authentication`, `Point`, `Level`) VALUES ('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s')", g_sClientName[client], g_sSteamId[client], g_sSteam64Id[client], g_sClientIP[client], "null", g_sCurrentTime, g_sCurrentTime, "null", "0", "0");
			SQL_FastQuery(clientDB, Query);
		}
		else
		{
			FormatEx(Query, sizeof(Query), "SELECT `Name`, `IP`, `Permissions` FROM `Client_Information` WHERE `SteamId`='%s'", g_sSteamId[client]);

			DBResultSet rs = SQL_Query(clientDB, Query);

			char SQLclient_name[64], SQLclient_ip[32], SQLclient_permissions[32];
			while(SQL_FetchRow(rs))
			{
				SQL_FetchString(rs, 0, SQLclient_name, sizeof(SQLclient_name));
				SQL_FetchString(rs, 1, SQLclient_ip, sizeof(SQLclient_ip));
				SQL_FetchString(rs, 2, SQLclient_permissions, sizeof(SQLclient_permissions));
			}

			/* PrintToServer("%s", SQLclient_name);
			PrintToServer("%s", SQLclient_ip);
			PrintToServer("%s", SQLclient_permissions);

			PrintToServer("%s", g_sClientName[client]);
			PrintToServer("%s", g_sClientIP[client]);
			PrintToServer("%s", g_sPermissions[client]); */

			if(!StrEqual(g_sClientName[client], SQLclient_name) || !StrEqual(g_sPermissions[client], SQLclient_permissions) || !StrEqual(g_sClientIP[client], SQLclient_ip))
			{
				FormatEx(Query, sizeof(Query), "UPDATE `Client_Information` SET `Name`='%s', `IP`='%s', `Permissions`='%s' WHERE `SteamId`='%s'", g_sClientName[client], g_sClientIP[client], g_sPermissions[client], g_sSteamId[client]);
				SQL_FastQuery(clientDB, Query);
			}
		}
	}
}

public void ClientWelcome(int client)
{
	char buffer[1024];
	buffer = Welcome_Text;

	if(g_bDeveloper[client])
	{
		g_sPermissions[client] = "Developer";
		ReplaceString(buffer, sizeof(buffer), "???", "\x08");
	}

	if(!StrEqual(g_sPermissions[client], "Developer"))
	{
		if(GetUserAdmin(client) != INVALID_ADMIN_ID)
		{
			g_sPermissions[client] = "Admin";
			ReplaceString(buffer, sizeof(buffer), "???", "\x05");
		}
		else
		{
			g_sPermissions[client] = "Member";
			ReplaceString(buffer, sizeof(buffer), "???", "\x01");
		}
	}

	if(g_bClientAuth[client])
	{
		StrCat(buffer, sizeof(buffer), " \x03认证\x08[\x0B%s\x08] -");
		StrCat(buffer, sizeof(buffer), " \x03来自 \x01%s");

		ChatAll(buffer, client, g_iPlayerId[client], g_sPermissions[client], g_iPoint[client], g_iLevel[client], g_sAuthentication[client], g_sCountry[client]);
	}
	else
	{
		StrCat(buffer, sizeof(buffer), " \x03来自 \x01%s");

		ChatAll(buffer, client, g_iPlayerId[client], g_sPermissions[client], g_iPoint[client], g_iLevel[client], g_sCountry[client]);
	}

	SaveClientInfoDB(client);
}

public Action command_client(int client, int args)
{
	if(ClientIsValid(client))
	{
		PrintToChat(client, "\x01===========\x08[\x06Ins.client\x08]\x01===========");
		PrintToChat(client, " \x04客户端ID\x01 : \x01%s", g_sSteam64Id[client]);
		PrintToChat(client, " \x04PlayerID\x01 : \x01%d", g_iPlayerId[client]);
		PrintToChat(client, " \x04AccountID\x01 : \x01%d", GetSteamAccountID(client));
		PrintToChat(client, " \x04版本ID\x01  : \x01%s", PLUGIN_VERSION);
		PrintToChat(client, " \x04权限ID\x01  : \x01%s", g_sPermissions[client]);
		PrintToChat(client, " \x04注册时间\x01 : \x01%s", g_sJoinTime[client]);
	}
	return Plugin_Handled;
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

stock bool IsPlayer(int client)
{
	char Query[512];
	FormatEx(Query, sizeof(Query), "SELECT COUNT(1) FROM `Client_Information` WHERE `SteamId`='%s'", g_sSteamId[client]);
	Handle hQuery = SQL_Query(clientDB, Query);

	if(SQL_FetchRow(hQuery) && hQuery != null)
	{
		if(SQL_FetchInt(hQuery, 0) != 0)
		{
			return true;
		}
	}
	return false;
}

public bool UpdateClientPoint(int client)
{
	char Query[512];
	FormatEx(Query, sizeof(Query), "UPDATE `Client_Information` SET `Point`=(`Point`+1) WHERE `SteamId`='%s'", g_sSteamId[client]);
	if(SQL_FastQuery(clientDB, Query))
	{
		return true;
	}
	return false;
}

public bool UpdateClientLevel(int client)
{
	char Query[512];
	FormatEx(Query, sizeof(Query), "SELECT `Point` FROM `Client_Information` WHERE `SteamId`='%s'", g_sSteamId[client]);
	DBResultSet rs = SQL_Query(clientDB, Query);

	if(SQL_FetchRow(rs))
	{
		g_iPoint[client] = SQL_FetchInt(rs, 0);
	}

	if(g_iPoint[client] < 60)
	{
		g_sAuthentication[client] = "萌新认证";
		FormatEx(Query, sizeof(Query), "UPDATE `Client_Information` SET `Authentication`='%s' WHERE `SteamId`='%s'", g_sAuthentication[client], g_sSteamId[client]);
		SQL_FastQuery(clientDB, Query);
	}

	if(g_iPoint[client] >= 60 && g_iPoint[client] < 120)
	{
		//一小时玩家
		g_iLevel[client] = 1;
	}
	else if(g_iPoint[client] >= 120 && g_iPoint[client] < 180)
	{
		g_iLevel[client] = 2;
	}
	else if(g_iPoint[client] >= 180 && g_iPoint[client] < 240)
	{
		g_iLevel[client] = 3;
	}
	else if(g_iPoint[client] >= 240 && g_iPoint[client] < 300)
	{
		g_iLevel[client] = 4;
	}
	else if(g_iPoint[client] >= 300 && g_iPoint[client] < 360)
	{
		g_iLevel[client] = 5;
	}
	else if(g_iPoint[client] >= 360 && g_iPoint[client] < 420)
	{
		g_iLevel[client] = 6;
	}
	else if(g_iPoint[client] >= 420 && g_iPoint[client] < 480)
	{
		g_iLevel[client] = 7;
	}
	else if(g_iPoint[client] >= 480 && g_iPoint[client] < 540)
	{
		g_iLevel[client] = 8;
	}
	else if(g_iPoint[client] >= 540 && g_iPoint[client] < 600)
	{
		g_iLevel[client] = 9;
	}
	else if(g_iPoint[client] >= 600)
	{
		g_iLevel[client] = 10;
		g_sAuthentication[client] = "资深高玩";
		FormatEx(Query, sizeof(Query), "UPDATE `Client_Information` SET `Authentication`='%s' WHERE `SteamId`='%s'", g_sAuthentication[client], g_sSteamId[client]);
		SQL_FastQuery(clientDB, Query);
	}

	FormatEx(Query, sizeof(Query), "UPDATE `Client_Information` SET `Level`='%d' WHERE `SteamId`='%s'", g_iLevel[client], g_sSteamId[client]);
	if(SQL_FastQuery(clientDB, Query))
	{
		return true;
	}
	return false;
}

public void ClearDisconnectPlayerInfo(int client)
{
	g_iPlayerId[client] = 0;
	g_iPoint[client] = 0;
	g_iLevel[client] = 0;
	g_iCurrentPoint[client] = 0;
	g_sClientName[client] = "null";
	g_sSteamId[client] = "null";
	g_sSteam64Id[client] = "null";
	g_sClientIP[client] = "null";
	g_sJoinTime[client] = "null";
	g_sPermissions[client] = "";
	g_sAuthentication[client] = "null";
	g_sCountry[client] = "null";
	g_bWelcome[client] = false;
	g_bClientAuth[client] = false;
	g_bDeveloper[client] = false;
}

//////////////////////////////
//         CALLBACK         //
//////////////////////////////

void Client_ConnectCallBack(Database hDatabase, const char[] sError, any data)
{
	if (hDatabase == null)	// Fail Connect
	{
		LogError("[Client DB] Database failure: %s, ReConnect after 60 sec", sError);
		g_iDBStatus = 1; //ReConnect
		CreateTimer(60.00, ReConnectDB);
		return;
	}
	clientDB = hDatabase;
	PrintToServer("[Client DB] Successful connection to DB");
	Client_CreateTables(); // Create Tables
	clientDB.SetCharset("utf8"); // Set Charset UTF8
}

void Client_SQLCreateTables_Success(Database hDatabase, any Data, int iNumQueries, Handle[] hResults, any[] QueryData)
{
	g_iDBStatus = 4;
	PrintToServer("[Client DB] DB Ready");
}

void Client_SQLCreateTables_Error(Database hDatabase, any Data, int iNumQueries, const  char[] sError, int iFailIndex, any[] QueryData)
{
	g_iDBStatus = 1;
	LogError("[Client DB] SQL CreateTables Error: %s", sError);
}
