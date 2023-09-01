#define CM_MODULE_MOVE

float g_fCurrentSpeed[MAXPLAYERS + 1];
MoveType g_mtMoveType[MAXPLAYERS + 1];

bool g_bGlobalSpeedMod[MAXPLAYERS + 1] = {false, ...};

public void CM_Move_OnPluginStart()
{
	RegConsoleCmd("sm_speedmod", CM_Move_SpeedMod);
}

public Action CM_Move_SpeedMod(int client, int args)
{
	g_bGlobalSpeedMod[client] = !g_bGlobalSpeedMod[client];

	char sBuffer[32];

	sBuffer = g_bGlobalSpeedMod[client] ? "全局" : "最大速度";

	Chat(client, "速度显示模式切换为 %s", sBuffer);

	return Plugin_Handled;
}

public void CM_Move_PlayerMove(int client)
{
	int iClient = GetSpectedOrSelf(client);

	g_fCurrentSpeed[client] = GetSpeed(iClient);

	g_mtMoveType[client] = GetEntityMoveType(client);

	if(g_bGlobalSpeedMod[client])
	{
		PrintHintText(client, "Speed: <font color='#00ff24'>%.2f</font>", g_fCurrentSpeed[client]);
		return;
	}

	if(g_fCurrentSpeed[client] <= 280.00 || g_fCurrentSpeed[client] > 350.00)
	{
		return;
	}

	if(IsOnGround(iClient))
	{
		PrintHintText(client, "Perfect Speed: <font color='#00ff24'>%.2f</font>", g_fCurrentSpeed[client]);
	}
}

static bool IsOnGround(int client)
{
	return (GetEntityFlags(client) & FL_ONGROUND == FL_ONGROUND);
}

static float GetSpeed(int client)
{
	float vec[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vec);

	float x = Pow(vec[0], 2.0);
	float y = Pow(vec[1], 2.0);

	return SquareRoot(x + y);
}

int GetSpectedOrSelf(int client)
{
	int team = GetClientTeam(client);
	if(team != 1) // not spectating, replace with define/enum please
	{
		return client;
	}

	// TODO: Enum for this?
	int mode = GetEntProp(client, Prop_Send, "m_iObserverMode");

	if(mode != 4 && mode != 5) // Not first or third person
	{
		return client;
	}

	int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

	if(target == -1) // not spectating anyone
	{
		return client;
	}

	return target;
}