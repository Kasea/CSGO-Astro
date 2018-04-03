#if defined _stocks_included
 #endinput
#endif
#define _stocks_included

#define LoopValidClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(IsValidClient(%1))
#define STRING(%1) %1, sizeof(%1)


stock bool IsValidClient(int client, bool bAlive = false) // when bAlive is false = technical checks, when it's true = gameplay checks
{
	return (client >= 1 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsClientSourceTV(client) && (!bAlive || IsPlayerAlive(client)));
}

stock void ParseColor(const char[] color, int[] result)
{
	char buffers[4][4];
	ExplodeString(color, " ", buffers, sizeof(buffers), sizeof(buffers[]));
	
	for (new i = 0; i < sizeof(buffers); i++)
		result[i] = StringToInt(buffers[i]);
}

stock char[] IntToChar(int x)
{
	char buff[8];
	IntToString(x, buff, 8);
	return buff;
}

stock char[] FormatSeconds(float value, int commas)
{
	
}

stock int GetSpecCount(int client)
{
	int count = 0;

	for(new j = 1; j <= MaxClients; j++)
	{
		if (!IsClientInGame(j) || !IsClientObserver(j) || IsClientSourceTV(j))
			continue;

		int iSpecMode = GetEntProp(j, Prop_Send, "m_iObserverMode");

		// The client isn't spectating any one person, so ignore them.
		if (iSpecMode != 4 && iSpecMode != 5)
			continue;

		// Find out who the client is spectating.
		int iTarget = GetEntPropEnt(j, Prop_Send, "m_hObserverTarget");

		// Are they spectating the same player as User?
		if (iTarget == client && j != client)
		{
			count++;
		}
	}

	return count;
}

stock char[] FormatW(int client, int buttons)
{
	if(buttons & IN_FORWARD)
		return "W";
	else
		return "_";
}

stock char[] FormatASD(int client, int buttons)
{
	char buffer[6];
	if(buttons & IN_LEFT)
		Format(STRING(buffer),"A");
	else
		Format(STRING(buffer),"_");
	if(buttons & IN_BACK)
		Format(STRING(buffer),"S");
	else
		Format(STRING(buffer),"_");
	if(buttons & IN_RIGHT)
		Format(STRING(buffer),"D");
	else
		Format(STRING(buffer),"_");
	return buffer;
}

stock char[] FormatCtrl(int client, int buttons)
{
	if(buttons & IN_DUCK)
		return "DUCK";
	else
		return "";
}

stock char[] FormatSpace(int client, int buttons)
{
	if(buttons & IN_JUMP)
		return "SPACE";
	else
		return "";
}