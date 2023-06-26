

void APIClientInit()
{
	CreateNative("Client_GetClientPlayerId", Native_GetClientPlayerId);
	CreateNative("Client_GetClientPoint", Native_GetClientPoint);
	CreateNative("Client_GetClientLevel", Native_GetClientLevel);
}

public int Native_GetClientPlayerId(Handle plugin, int numParams)
{
	return g_iPlayerId[GetNativeCell(1)];
}

public int Native_GetClientPoint(Handle plugin, int numParams)
{
	return g_iPoint[GetNativeCell(1)];
}

public int Native_GetClientLevel(Handle plugin, int numParams)
{
	return g_iLevel[GetNativeCell(1)];
}