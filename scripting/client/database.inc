

stock void CM_Database_OnPluginStart()
{
	CreateTimer(1.00, Point_TimerCallBack, _, TIMER_REPEAT);

	Database.Connect(Client_ConnectCallBack, client_DB);
}

stock void Client_CreateTables()
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

public Action ReConnectDB(Handle Timer)
{
	if(g_iDBStatus == 1)
	{
		Database.Connect(Client_ConnectCallBack, client_DB);
	}
	return Plugin_Stop;
}

public Action Point_TimerCallBack(Handle Timer)
{
	if(g_iDBStatus != 4) return Plugin_Continue;

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

stock bool IsPlayer(int client)
{
	if(g_iDBStatus != 4) return false;

	char Query[256];
	FormatEx(Query, sizeof(Query), "SELECT COUNT(1) FROM `Client_Information` WHERE `SteamId`='%s'", g_sSteamId[client]);
	DBResultSet rs = SQL_Query(clientDB, Query);

	if(SQL_FetchRow(rs))
	{
		if(SQL_FetchInt(rs, 0) != 0)
		{
			return true;
		}
	}
	return false;
}

stock bool UpdateClientPoint(int client)
{
	if(g_iDBStatus != 4) return false;

	char Query[512];
	FormatEx(Query, sizeof(Query), "UPDATE `Client_Information` SET `Point`=(`Point`+1) WHERE `SteamId`='%s'", g_sSteamId[client]);
	if(SQL_FastQuery(clientDB, Query))
	{
		return true;
	}
	return false;
}

stock bool UpdateClientLevel(int client)
{
	if(g_iDBStatus != 4) return false;

	char Query[512];
	FormatEx(Query, sizeof(Query), "SELECT `Point`, FLOOR((`Point`/60)) FROM `Client_Information` WHERE `SteamId`='%s'", g_sSteamId[client]);
	DBResultSet rs = SQL_Query(clientDB, Query);

	while(SQL_FetchRow(rs))
	{
		g_iPoint[client] = SQL_FetchInt(rs, 0);
		g_iLevel[client] = SQL_FetchInt(rs, 1);
	}

	FormatEx(Query, sizeof(Query), "UPDATE `Client_Information` SET `Level`='%d' WHERE `SteamId`='%s'", g_iLevel[client], g_sSteamId[client]);
	if(SQL_FastQuery(clientDB, Query))
	{
		return true;
	}
	return false;
}

stock bool UpdateClientLastAppeared(int client)
{
	if(g_iDBStatus != 4) return false;

	char Query[256];
	FormatEx(Query, sizeof(Query), "UPDATE `Client_Information` SET `LastAppeared`=NOW() WHERE `SteamId`='%s'", g_sSteamId[client]);
	if(SQL_FastQuery(clientDB, Query))
	{
		return true;
	}
	return false;
}

stock void Client_ConnectCallBack(Database hDatabase, const char[] sError, any data)
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

stock void Client_SQLCreateTables_Success(Database hDatabase, any Data, int iNumQueries, Handle[] hResults, any[] QueryData)
{
	g_iDBStatus = 4;
	PrintToServer("[Client DB] DB Ready");
}

stock void Client_SQLCreateTables_Error(Database hDatabase, any Data, int iNumQueries, const  char[] sError, int iFailIndex, any[] QueryData)
{
	g_iDBStatus = 1;
	LogError("[Client DB] SQL CreateTables Error: %s", sError);
}
