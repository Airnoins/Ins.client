#define CM_MODULE_HUDS

public void CM_Huds_OnPluginStart()
{
	CreateTimer(1.0, AimHint_Timer, _, TIMER_REPEAT);
	CreateTimer(1.0, Hud_Timer, _, TIMER_REPEAT);
}

public Action AimHint_Timer(Handle Timer)
{
	for(int i = 1; i < MaxClients; i++)
	{
		if(ClientIsValid(i) && ClientIsAlive(i))
		{
			int target = GetClientAimTarget(i, true);
			if(ClientIsValid(target) && ClientIsAlive(target))
			{
				Hint(i, "Lv.<font color='#FF6347'>%d</font> <font color='#1E90FF'>%s</font><br>PID: <font color='#00FF00'>%d</font><br>点数: <font color='#00FF00'>%d</font><br>权限: <font color='#2064ff'>%s</font>", g_iLevel[target], g_sClientName[target], g_iPlayerId[target], g_iPoint[target], g_sPermissions[target]);
			}
		}
	}
	return Plugin_Continue;
}

public Action Hud_Timer(Handle Timer)
{
	for(int i = 1; i < MaxClients; i++)
	{
		if(ClientIsValid(i) && ClientIsAlive(i))
		{
			SetHudTextParams(0.01, 0.40, 1.5, 0, 200, 0, 255, 0, 0.0, 0.0, 0.0);
			#if defined _DynamicChannels_included_
			int iHUDChannel = GetDynamicChannel(g_iHUDChannel);
			#else
			int iHUDChannel = g_iHUDChannel;
			#endif

			ShowHudText(i, iHUDChannel, "%s\nPlayers: %d/%d\n名称: %s\nPID: %d\n点数: %d(Lv.%d)\n权限: %s\n地图: %s", g_sServerName, g_iCurrentPlayers, g_iMaxPlayers, g_sClientName[i], g_iPlayerId[i], g_iPoint[i], g_iLevel[i], g_sPermissions[i], g_sCurrentMap);
		}
	}
	return Plugin_Continue;
}