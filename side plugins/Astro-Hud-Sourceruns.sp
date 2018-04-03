/**
int spec = GetSpecCount(client);
float pb = KT_GetClientPB(client);
float wr = KT_GetWr();
int nextPos = KT_GetNextPos(int client);
float time = KT_GetTime(client);
Format(x, y, "%s", FormatSeconds(time, 1) == 01.32.9 | 1 = how numbers on last
float speed = K_GetCurrentSpeed(client);
float sync = K_GetSync(client);
FormatW(client, GetClientButtons(client)); there's also FormatASD and FormatCtrl and FormatSpace
int style = K_GetStyle(client);

**/
#include <k-zones>
#include <k-hud>

bool gB_ShowStart[MAXPLAYERS+1] = {true, ...};

public void OnPluginStart()
{
	
}

public void K_LoadPluginHud()
{
	K_AddHud(sourcerunHud, "SourceRuns", 1, true);
}

public void K_OnClientEnterZone(int client, int zone)
{
	if(zone == 0 || zone == 1)
	{
		gB_ShowStart[client] = true;
	}
}

public void K_OnClientLeaveZone(int client, int zone)
{
	if(zone == 0 || zone == 1)
	{
		gB_ShowStart[client] = false;
	}
}

public void sourcerunHud(int client, char[] PrintText, int maxSize)
{
	if(gB_ShowStart[client])
	{
		StartEndZoneHud(client, PrintText, maxSize);
	}else
	{
		RunHud(client, PrintText, maxSize);
	}
}

public void StartEndZoneHud(int client, char[] buffer, int maxSize)
{
	//https://gyazo.com/26e14f3506e5698ec7097bd2e2d3bcce
}

public void RunHud(int client, char[] buffer, int maxSize)
{
	//https://gyazo.com/13e74f4ab8d6a895d466a62419b2288a
}