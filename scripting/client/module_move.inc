#define CM_MODULE_MOVE

float g_fCurrentSpeed[MAXPLAYERS + 1];
MoveType g_mtMoveType[MAXPLAYERS + 1];

public void CM_Move_PlayerMove(int client)
{
	g_fCurrentSpeed[client] = GetSpeed(GetSpectedOrSelf(client));

	g_mtMoveType[client] = GetEntityMoveType(client);

	if(g_fCurrentSpeed[client] <= 280.00 || g_fCurrentSpeed[client] > 350.00)
	{
		return;
	}

	if(IsOnGround(client))
	{
		PrintHintText(client, "Max Speed: <font color='#00ff24'>%.2f</font>", g_fCurrentSpeed[client]);
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