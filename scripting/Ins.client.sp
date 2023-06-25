#pragma semicolon 1
#pragma newdecls required


//////////////////////////////
//    PLUGIN DEFINITION     //
//////////////////////////////
#define PLUGIN_NAME         "Client - redux(Beta)"
#define PLUGIN_AUTHOR       "Ins"
#define PLUGIN_DESCRIPTION  "Client-related features(Only MySql is supported)"
#define PLUGIN_VERSION      "1.5.3"
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
#include <sdkhooks>
#include <geoip>
#include <smutils>

//Using DynamicChannels: https://github.com/Vauff/DynamicChannels
#tryinclude <DynamicChannels>

#include "client/function"
#include "client/database"
#include "client/module_huds"
//#include "client/module_cp"

//////////////////////////////
//          Forward         //
//////////////////////////////

public void OnPluginStart()
{
	RegConsoleCmd("sm_client", command_client, "Query client information");

	SMUtils_SetChatPrefix("\x01[\x04Ins.client\x01]");
	SMUtils_SetChatSpaces("   ");
	SMUtils_SetChatConSnd(false);
	SMUtils_SetTextDest(HUD_PRINTCENTER);

	HookEventEx("player_connect_full", Event_PlayerConnectFull, EventHookMode_Post);

	CM_Global_OnPluginStart();
	CM_Database_OnPluginStart();

	#if defined CM_MODULE_HUDS
	CM_Huds_OnPluginStart();
	#endif
}

public void OnMapStart()
{
	CM_Global_OnMapStart();
}

public void OnClientDisconnect(int client)
{
	ChatAll("\x04%N \x01已离开游戏", client);
	g_bIsPlayer[client] = false;

	UpdateClientLastAppeared(client);
	UpdateClientLevel(client);
}

//////////////////////////////
//         EVENT            //
//////////////////////////////

public Action Event_PlayerConnectFull(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	GetClientAuthId(client, AuthId_Steam2, g_sSteamId[client], LENGTH_64);

	if(IsPlayer(client))
	{
		g_bIsPlayer[client] = true;
	}

	if(!g_bIsPlayer[client])
	{
		Chat(client, "检测用户为首次加载,正在向云端上传数据");

		SaveClientInfo(client);
		SaveClientInfoDB(client, true);
	}
	UpdateClientLevel(client);
	SaveClientInfo(client);

	SDKHook(client, SDKHook_SpawnPost, OnEntitySpawnPost);

	return Plugin_Continue;
}

public Action OnEntitySpawnPost(int client)
{
	ClientWelcome(client);
	SDKUnhook(client, SDKHook_SpawnPost, OnEntitySpawnPost);

	return Plugin_Continue;
}

//////////////////////////////
//         COMMAND          //
//////////////////////////////

public void SaveClientInfo(int client)
{
	GetClientName(client, g_sClientName[client], LENGTH_64);
	GetClientAuthId(client, AuthId_Steam2, g_sSteamId[client], LENGTH_64);
	GetClientAuthId(client, AuthId_SteamID64, g_sSteam64Id[client], LENGTH_64);
	GetClientIP(client, g_sClientIP[client], LENGTH_64);
	GeoipCountryEx(g_sClientIP[client], g_sCountry[client], 16, client);

	if(GetUserAdmin(client) != INVALID_ADMIN_ID)
	{
		g_sPermissions[client] = "Admin";
	}
	else
	{
		g_sPermissions[client] = "Member";
	}

	if(g_iDBStatus == 4 && g_bIsPlayer[client])
	{
		char Query[512];
		FormatEx(Query, sizeof(Query),"SELECT `Playerid`, `Jointime`, `Authentication` FROM `Client_Information` WHERE `SteamId`='%s'", g_sSteamId[client]);

		DBResultSet rs = null;
		rs = SQL_Query(clientDB, Query);

		while(SQL_FetchRow(rs))
		{
			g_iPlayerId[client] = SQL_FetchInt(rs, 0);
			SQL_FetchString(rs, 1, g_sJoinTime[client], LENGTH_64);
			SQL_FetchString(rs, 2, g_sAuthentication[client], LENGTH_64);
		}

		if(!StrEqual(g_sAuthentication[client], "null"))
		{
			if(IsDeveloper(g_sAuthentication[client]))
			{
				g_sPermissions[client] = "Developer";
				g_bDeveloper[client] = true;
			}
			g_bClientAuth[client] = true;
		}
	}
}

public void SaveClientInfoDB(int client, bool insert)
{
	if(g_iDBStatus == 4)
	{
		char Query[512];
		if(insert)
		{
			FormatEx(Query, sizeof(Query), "INSERT INTO `Client_Information` (`Name`, `SteamId`, `Steam64Id`, `IP`, `Permissions`, `Jointime`, `LastAppeared`, `Authentication`, `Point`, `Level`) VALUES ('%s', '%s', '%s', '%s', '%s', NOW(), NOW(), '%s', '%s', '%s')", g_sClientName[client], g_sSteamId[client], g_sSteam64Id[client], g_sClientIP[client], "null", "null", "0", "0");
			SQL_FastQuery(clientDB, Query);
			g_bIsPlayer[client] = true;
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
	
	if(StrEqual(g_sPermissions[client], "Developer"))
	{
		ReplaceString(buffer, sizeof(buffer), "???", "\x08");
	}
	else if(StrEqual(g_sPermissions[client], "Admin"))
	{
		ReplaceString(buffer, sizeof(buffer), "???", "\x05");
	}
	else if(StrEqual(g_sPermissions[client], "Member"))
	{
		ReplaceString(buffer, sizeof(buffer), "???", "\x01");
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

	SaveClientInfoDB(client, false);
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
