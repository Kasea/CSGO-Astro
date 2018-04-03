// Standalone -- more or less
/***
TODO:
Let users choose which zones they wanna see.
Give use godmode if he's making zone
sm_zonedeleteall

***/

#include <sourcemod>
#include <SDKHooks>
#include <smlib>
#include <k-zones>
#include <stocks>

//#define MAPZONE_STYLE 1
//#define MAPZONE_TRIGGER_RESIZE 16.0
#define MAXTICKER 12
#define INCREASE_DECREASE 2.0

Database gH_DB = null;

char gC_CurrentMap[PLATFORM_MAX_PATH];
int gI_CurrentMap;

//Forwards
Handle forward_LoadPluginZones = null;
Handle forward_OnClientEnterZone = null;
Handle forward_OnClientLeaveZone = null;

//Zones
ArrayList gAl_MapZones1x;
ArrayList gAl_MapZones1y;
ArrayList gAl_MapZones1z;
ArrayList gAl_MapZones2x;
ArrayList gAl_MapZones2y;
ArrayList gAl_MapZones2z;
ArrayList gAl_MapZonesIdentification;
ArrayList gAl_MapZonesSQLId;

//extensions
ArrayList gAl_ZonesName;
ArrayList gAl_ZonesIdentification;
ArrayList gAl_ZonesDraw;
ArrayList gAl_ZonesColors;

//Admin create zone
float gF_AdminCreateZone[MAXPLAYERS+1][6];
int gI_AdminCreateZoneMode[MAXPLAYERS+1] = {0, ...};
int gI_AdminCreateZoneId[MAXPLAYERS + 1];

//ConVars
ConVar gCv_MapzoneDraw = null;
ConVar gCv_DefaultSprite = null;
ConVar gCv_ZoneThickness = null;

//Mapzone draw
int g_iMapzone;
bool g_bBackwards;
int precache_laser_default;

//client
int gI_CurrentClientZone[MAXPLAYERS+1] = {-1, ...}; 


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("K_AddZone", Native_AddZone);
	
	MarkNativeAsOptional("K_AddZone");
}

public void OnPluginStart()
{
	ConnectSQL();
	
	forward_LoadPluginZones = CreateGlobalForward("K_LoadPluginZones", ET_Event);
	forward_OnClientEnterZone = CreateGlobalForward("K_OnClientEnterZone", ET_Event, Param_Cell, Param_Cell);
	forward_OnClientLeaveZone = CreateGlobalForward("K_OnClientLeaveZone", ET_Event, Param_Cell, Param_Cell);
	
	gAl_MapZones1x = new ArrayList(1);
	gAl_MapZones1y = new ArrayList(1);
	gAl_MapZones1z = new ArrayList(1);
	gAl_MapZones2x = new ArrayList(1);
	gAl_MapZones2y = new ArrayList(1);
	gAl_MapZones2z = new ArrayList(1);
	gAl_MapZonesIdentification = new ArrayList(3);
	gAl_MapZonesSQLId = new ArrayList(3);
	
	gAl_ZonesName = new ArrayList(32);
	gAl_ZonesIdentification = new ArrayList(4);
	gAl_ZonesDraw = new ArrayList(1);
	gAl_ZonesColors = new ArrayList(4);
	
	HookEvent("bullet_impact", BulletImpact);
	
	Call_StartForward(forward_LoadPluginZones);
	Call_Finish();
	
	gCv_MapzoneDraw = CreateConVar("timer_mapzoneDraw", "0", "0 for default, 1 for square, 2 for Kasea *_* and 3 for Kasea both ways", _, true, 0.0, true, 3.0);
	gCv_DefaultSprite = CreateConVar("timer_beam_sprite_default", "materials/sprites/laserbeam", "The laser sprite for zones (default sprite).");
	gCv_ZoneThickness = CreateConVar("timer_mapzoneThickness", "10.0");
	
	AutoExecConfig();
	
	HookConVarChange(gCv_DefaultSprite, Action_OnSettingsChange);
	
	CreateTimer(1.0, ChangeTheValue, _, TIMER_REPEAT);
	CreateTimer(1.0, Timer_DrawZones, _, TIMER_REPEAT);
	
	RegAdminCmd("sm_zone", cmd_zone, ADMFLAG_CHEATS);
	RegAdminCmd("sm_zonedelete", cmd_zonedelete, ADMFLAG_CHEATS);
	RegAdminCmd("sm_zonetp", cmd_zonetp, ADMFLAG_CHEATS);
	RegAdminCmd("sm_zonefaketp", cmd_zonefaketp, ADMFLAG_CHEATS);
}

public bool IsBetween(float a, float b, float c)
{
	return (a<=(b>c)? b:c && a>= (b<c)? b:c)? true:false;
}

public void OnGameFrame()
{
	bool inside;
	float loc[3];
	int max = GetArraySize(gAl_MapZones1x);
	LoopValidClients(x)
	{
		inside = false;
		GetClientAbsOrigin(x, loc);
		for(int i = 0;i<max; i++)
		{
			if(IsBetween(loc[2], GetArrayCell(gAl_MapZones1z, i), GetArrayCell(gAl_MapZones2z, i)) && 
			IsBetween(loc[1], GetArrayCell(gAl_MapZones1y, i), GetArrayCell(gAl_MapZones2y, i)) && 
			IsBetween(loc[0], GetArrayCell(gAl_MapZones1x, i), GetArrayCell(gAl_MapZones2x, i)))
			{
				inside = true;
				if(gI_CurrentClientZone[x] == -1)
				{
					gI_CurrentClientZone[x] = i;
					Call_StartForward(forward_OnClientEnterZone);
					Call_PushCell(x);
					Call_PushCell(i);
					Call_Finish();
				}
			}
		}
		if(!inside && gI_CurrentClientZone[x] != -1)
		{
			//he just left a zone
			Call_StartForward(forward_OnClientLeaveZone);
			Call_PushCell(x);
			Call_PushCell(gI_CurrentClientZone[x]);
			Call_Finish();
			gI_CurrentClientZone[x] = -1;
		}
	}
}

public Action_OnSettingsChange(Handle cvar, char[] oldvalue, char[] newvalue)
{
	if(cvar == gCv_DefaultSprite)
	{
		InitZoneSprite();
	}
}

public Action cmd_zonetp(int client, int args)
{
	Menu menu = new Menu(Menu_ZoneTp);
	menu.SetTitle("Teleport to a zone");
	char buffer[64];
	for(int i = 0;i<gAl_MapZonesIdentification.Length;++i)
	{
		int value = FindValueInArray(gAl_ZonesIdentification, GetArrayCell(gAl_MapZonesIdentification, i));
		if(value != -1)
		{
			GetArrayString(gAl_ZonesName, value, STRING(buffer));
			Format(STRING(buffer), "%s (%i)", buffer, GetArrayCell(gAl_ZonesIdentification, value));
			menu.AddItem(IntToChar(i), buffer);
		}
	}
	menu.Display(client, 0);
}

public int Menu_ZoneTp(Menu menu, MenuAction action, int client, int item)
{
	if(action == MenuAction_Select)
	{
		char info[8];
		menu.GetItem(item, STRING(info));
		TeleportClientToZone(client, StringToInt(info), false);
	}
}

public Action cmd_zonefaketp(int client, int args)
{
	Menu menu = new Menu(Menu_ZoneFakeTp);
	menu.SetTitle("Fake Teleport to a zone");
	char buffer[64];
	for(int i = 0;i<gAl_MapZonesIdentification.Length;++i)
	{
		int value = FindValueInArray(gAl_ZonesIdentification, GetArrayCell(gAl_MapZonesIdentification, i));
		if(value != -1)
		{
			GetArrayString(gAl_ZonesName, value, STRING(buffer));
			Format(STRING(buffer), "%s (%i)", buffer, GetArrayCell(gAl_ZonesIdentification, value));
			menu.AddItem(IntToChar(i), buffer);
		}
	}
	menu.Display(client, 0);
}

public int Menu_ZoneFakeTp(Menu menu, MenuAction action, int client, int item)
{
	if(action == MenuAction_Select)
	{
		char info[8];
		menu.GetItem(item, STRING(info));
		TeleportClientToZone(client, StringToInt(info), true);
	}
}

void TeleportClientToZone(int client, int zone, bool fake)
{
	if(fake)
	{
		gI_CurrentClientZone[client] = zone;
		PrintToChat(client, "%t You just fake \"teleported\" to the zone", "Prefix");
	}else
	{
		float origin[3];
		float a;
		float b;
		float c;
		a = GetArrayCell(gAl_MapZones1x, zone);
		b = GetArrayCell(gAl_MapZones2x, zone);
		c = a+b;
		
		origin[0] = c/2.0;
		
		a = GetArrayCell(gAl_MapZones1y, zone);
		b = GetArrayCell(gAl_MapZones2y, zone);
		c = a+b;
		
		origin[1] = c/2.0;
		origin[2] = GetArrayCell(gAl_MapZones1z, zone);
		TeleportEntity(client, origin, NULL_VECTOR, NULL_VECTOR);
	}
}

public Action cmd_zone(int c, int a)
{
	AdminCreateZone(c);
	return Plugin_Handled;
}

public Action cmd_zonedelete(int client, int args)
{
	if(gI_CurrentClientZone[client] != -1)
	{
		char query[64];
		FormatEx(STRING(query), "DELETE FROM Zones WHERE map = %i AND id = %i", gI_CurrentMap, GetArrayCell(gAl_MapZonesSQLId, gI_CurrentClientZone[client]));
		SQL_TQuery(gH_DB, SQL_Trash_Callback, query, 48);
		UnloadZone(gI_CurrentClientZone[client]);
		gI_CurrentClientZone[client] = -1;
	}else
	{
		ReplyToCommand(client, "[KTimer] You need to be in a zone to delete it");
	}
	return Plugin_Handled;
}

void AdminCreateZone(int client)
{
	//works perfectly
	Menu menu = new Menu(Menu_AdminCreateZone);
	menu.SetTitle("Choose which zone type you want to add");
	char buffer[32];
	for(int i = 0;i<gAl_ZonesIdentification.Length;++i)
	{
		GetArrayString(gAl_ZonesName, i, STRING(buffer));
		Format(STRING(buffer), "%s (%i)", buffer, GetArrayCell(gAl_ZonesIdentification, i));
		menu.AddItem(IntToChar(GetArrayCell(gAl_ZonesIdentification, i)), buffer);
	}
	menu.Display(client, 0);
}

public Action Timer_DisplayAdminZone(Handle timer, any client)
{
	if(gI_AdminCreateZoneMode[client] == 0)
		return Plugin_Stop;
	//draw it
	float tFloat[3];
	tFloat[0] = gF_AdminCreateZone[client][0];
	tFloat[1] = gF_AdminCreateZone[client][1];
	tFloat[2] = gF_AdminCreateZone[client][2];
	float ClientVec[3];
	if(gI_AdminCreateZoneMode[client] != 4)
		GetClientAbsOrigin(client, ClientVec);
	else
	{
		ClientVec[0] = gF_AdminCreateZone[client][3];
		ClientVec[1] = gF_AdminCreateZone[client][4];
		ClientVec[2] = gF_AdminCreateZone[client][5];
	}
	
	ClientVec[2] += 160.0;
	int color[4];
	int index = FindValueInArray(gAl_ZonesIdentification, gI_AdminCreateZoneId[client]);
	if(index != -1)
	{
		GetArrayArray(gAl_ZonesColors, index, color);
	}
	DrawBox(tFloat, ClientVec, 1.0, color, false);
	return Plugin_Continue;
}

public int Menu_AdminCreateZone(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char info[7];
		menu.GetItem(item, info, 7);
		if(StringToInt(info) != 0 || StrEqual(info, "0"))
		{
			gI_AdminCreateZoneId[client] = StringToInt(info);
			gI_AdminCreateZoneMode[client] = 2;
			Menu mMenu = new Menu(Menu_Zones_Trash);
			mMenu.SetTitle("Shoot where you want to place the zone");
			mMenu.AddItem("-", "DON'T CLICK ME!");
			mMenu.Display(client, 5);
		}else if(!StrEqual(info, "finish"))
		{
			if(StrEqual(info, "x1+"))
			{
				gF_AdminCreateZone[client][0] += INCREASE_DECREASE;
			}else if(StrEqual(info, "y1+"))
			{
				gF_AdminCreateZone[client][1] += INCREASE_DECREASE;
			}else if(StrEqual(info, "z1+"))
			{
				gF_AdminCreateZone[client][2] += INCREASE_DECREASE;
			}else if(StrEqual(info, "x1-"))
			{
				gF_AdminCreateZone[client][0] -= INCREASE_DECREASE;
			}else if(StrEqual(info, "y1-"))
			{
				gF_AdminCreateZone[client][1] -= INCREASE_DECREASE;
			}else if(StrEqual(info, "z1-"))
			{
				gF_AdminCreateZone[client][2] -= INCREASE_DECREASE;
			}else if(StrEqual(info, "x2+"))
			{
				gF_AdminCreateZone[client][3] += INCREASE_DECREASE;
			}else if(StrEqual(info, "y2+"))
			{
				gF_AdminCreateZone[client][4] += INCREASE_DECREASE;
			}else if(StrEqual(info, "z2+"))
			{
				gF_AdminCreateZone[client][5] += INCREASE_DECREASE;
			}else if(StrEqual(info, "x2-"))
			{
				gF_AdminCreateZone[client][3] -= INCREASE_DECREASE;
			}else if(StrEqual(info, "y2-"))
			{
				gF_AdminCreateZone[client][4] -= INCREASE_DECREASE;
			}else if(StrEqual(info, "z2-"))
			{
				gF_AdminCreateZone[client][5] -= INCREASE_DECREASE;
			}
			AdminCreateZoneDone(client, GetMenuSelectionPosition());
		}else
		{
			gF_AdminCreateZone[client][5] += 160.0;
			PushZone(gF_AdminCreateZone[client], gI_AdminCreateZoneId[client]);
			gI_AdminCreateZoneMode[client] = 0;
			gI_AdminCreateZoneId[client] = 0;
		}
	}else if(item == MenuCancel_Exit || item == MenuCancel_Disconnected || item == MenuCancel_ExitBack)
	{
		if(IsValidClient(client))
			gI_AdminCreateZoneMode[client] = 0;
		PrintToChatAll("We're cancelling it");
	}
}

public int Menu_Zones_Trash(Menu menu, MenuAction action, int client, int item)
{
	
}

public Action BulletImpact(Handle event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	switch(gI_AdminCreateZoneMode[client])
	{
		case 2:
		{
			gF_AdminCreateZone[client][0] = GetEventFloat(event, "x");
			gF_AdminCreateZone[client][1] = GetEventFloat(event, "y");
			gF_AdminCreateZone[client][2] = GetEventFloat(event, "z");
			gI_AdminCreateZoneMode[client] = 3;
			CreateTimer(1.0, Timer_DisplayAdminZone, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}
		case 3:
		{
			gF_AdminCreateZone[client][3] = GetEventFloat(event, "x");
			gF_AdminCreateZone[client][4] = GetEventFloat(event, "y");
			gF_AdminCreateZone[client][5] = GetEventFloat(event, "z");
			AdminCreateZoneDone(client, 0);
		}
	}
	
	return Plugin_Continue;
}

void AdminCreateZoneDone(int client, int spot)
{
	gI_AdminCreateZoneMode[client] = 4;
	Menu menu = new Menu(Menu_AdminCreateZone);
	menu.SetTitle("Select:");
	menu.AddItem("finish", "Done");
	menu.AddItem("x1+", "x++");
	menu.AddItem("y1+", "y++");
	menu.AddItem("z1+", "z++");
	menu.AddItem("x1-", "x--");
	menu.AddItem("y1-", "y--");
	menu.AddItem("z1-", "z--");
	menu.AddItem("x2+", "x++");
	menu.AddItem("y2+", "y++");
	menu.AddItem("z2+", "z++");
	menu.AddItem("x2-", "x--");
	menu.AddItem("y2-", "y--");
	menu.AddItem("z2-", "z--");
	menu.DisplayAt(client, spot, 0);
}

void PushZone(float p1[6], int Id)
{
	//add into database and insert into arraylist
	char query[256];
	FormatEx(STRING(query), "INSERT INTO Zones(map, zone, point1_x, point1_y, point1_z, point2_x, point2_y, point2_z) \
	VALUES(%i, %i, %f, %f, %f, %f, %f, %f);", gI_CurrentMap, Id, p1[0], p1[1], p1[2], p1[3], p1[4], p1[5]);
	SQL_TQuery(gH_DB, SQL_Trash_Callback, query, 82);
	
	FormatEx(STRING(query), "SELECT id, zone, \
	point1_x, point1_y, point1_z, \
	point2_x, point2_y, point2_z FROM Zones WHERE map = %i ORDER BY id DESC LIMIT 1;", gI_CurrentMap);
	SQL_TQuery(gH_DB, SQL_LoadMapZones, query);
}

public void OnMapStart()
{
	PrecacheModel("models/props_junk/wood_crate001a.mdl", true);
	GetCurrentMap(gC_CurrentMap, PLATFORM_MAX_PATH);
	if(gH_DB != null)
	{
		char query[40+PLATFORM_MAX_PATH];
		Format(STRING(query), "SELECT id FROM maps WHERE name = \"%s\"", gC_CurrentMap);
		SQL_TQuery(gH_DB, SQL_GetMapId, query);
	}
}

public void SQL_GetMapId(Handle owner, Handle hndl, const char[] error, any client)
{
	if(hndl == null)
	{
		LogError("Timer error! Failed to get current map id. Message %s", error);
		return;
	}else
	{
		while(SQL_FetchRow(hndl))
		{
			gI_CurrentMap = SQL_FetchInt(hndl, 0);
		}
		ClearZoneArrays();
		InitZoneSprite();
		LoadZones();
	}
}

void ClearZoneArrays()
{
	gAl_MapZones1x.Clear();
	gAl_MapZones1y.Clear();
	gAl_MapZones1z.Clear();
	gAl_MapZones2x.Clear();
	gAl_MapZones2y.Clear();
	gAl_MapZones2z.Clear();
	gAl_MapZonesIdentification.Clear();
	gAl_MapZonesSQLId.Clear();
}

void InitZoneSprite()
{
	char spritebuffer[256];
	char cvarbuffer[256];
	
	//default sprite
	GetConVarString(gCv_DefaultSprite, STRING(cvarbuffer));
	FormatEx(spritebuffer, sizeof(spritebuffer), "%s.vmt", cvarbuffer);
	if(!IsModelPrecached(spritebuffer))
	{
		precache_laser_default = PrecacheModel(spritebuffer);
		AddFileToDownloadsTable(spritebuffer);
		FormatEx(spritebuffer, sizeof(spritebuffer), "%s.vtf", cvarbuffer);
		AddFileToDownloadsTable(spritebuffer);
	}
}

//Loads all zones
public void LoadZones()
{
	char query[128]; //slightly over chars used cus i cba dealing with out of range errors
	FormatEx(STRING(query), "SELECT id, zone, \
	point1_x, point1_y, point1_z, \
	point2_x, point2_y, point2_z FROM Zones WHERE map = %i", gI_CurrentMap);
	SQL_TQuery(gH_DB, SQL_LoadMapZones, query);
}

public void SQL_LoadMapZones(Handle owner, Handle hndl, const char[] error, any client)
{
	if(hndl == null)
	{
		LogError("Timer error. Failed to load map zones. Message: %s", error);
		return;
	}
	while(SQL_FetchRow(hndl))
	{
		PushArrayCell(gAl_MapZonesSQLId, SQL_FetchInt(hndl, 0));
		PushArrayCell(gAl_MapZonesIdentification, SQL_FetchInt(hndl, 1));
		
		PushArrayCell(gAl_MapZones1x, SQL_FetchFloat(hndl, 2));
		PushArrayCell(gAl_MapZones1y, SQL_FetchFloat(hndl, 3));
		PushArrayCell(gAl_MapZones1z, SQL_FetchFloat(hndl, 4));
		
		PushArrayCell(gAl_MapZones2x, SQL_FetchFloat(hndl, 5));
		PushArrayCell(gAl_MapZones2y, SQL_FetchFloat(hndl, 6));
		PushArrayCell(gAl_MapZones2z, SQL_FetchFloat(hndl, 7));
	}
}

public void UnloadZone(int zone)
{
	RemoveFromArray(gAl_MapZones1x, zone);
	RemoveFromArray(gAl_MapZones1y, zone);
	RemoveFromArray(gAl_MapZones1z, zone);
	RemoveFromArray(gAl_MapZones2x, zone);
	RemoveFromArray(gAl_MapZones2y, zone);
	RemoveFromArray(gAl_MapZones2z, zone);
	RemoveFromArray(gAl_MapZonesIdentification, zone);
	RemoveFromArray(gAl_MapZonesSQLId, zone);
}

public Action ChangeTheValue(Handle timer)
{
	if(GetConVarInt(gCv_MapzoneDraw) == 2)
	{
		if(g_iMapzone == MAXTICKER)
		{
			g_iMapzone = -1;
		}
		++g_iMapzone;
	}else if(GetConVarInt(gCv_MapzoneDraw) == 3)
	{
		if(!g_bBackwards)
			++g_iMapzone;
		else
			--g_iMapzone;
		if(g_iMapzone >= MAXTICKER)
		{
			g_bBackwards = true;
		}else if(g_iMapzone <= 0)
		{
			g_bBackwards = false;
		}
	}
}

//draws the zones
public Action Timer_DrawZones(Handle timer)
{
	for (int zone = 0; zone < gAl_MapZonesIdentification.Length;++zone)
	{
		if(!ShouldDisplayZone(zone))
			continue;
		DrawZone(zone);
	}
}

void DrawZone(int zone)
{
	float point1[3];
	ArrayCopyZones1(point1, zone);
	
	float point2[3];
	ArrayCopyZones2(point2, zone);
	
	if (point1[2] < point2[2])
		point2[2] = point1[2];
	else
		point1[2] = point2[2];
	
	int index = FindValueInArray(gAl_ZonesIdentification, GetArrayCell(gAl_MapZonesIdentification, zone));
	
	if(index == -1)
		return;
	int color[4];
	GetArrayArray(gAl_ZonesColors, index, color);
	
	float t_p1[3];
	float t_p2[3];
	ArrayCopyZones1(t_p1, zone);
	ArrayCopyZones2(t_p2, zone);
	int plusser = (g_iMapzone*10);
	switch(gCv_MapzoneDraw.IntValue)
	{
		case 0:
		{
			DrawBox(point1, point2, 1.0, color, true);
		}
		case 1:
		{
			t_p1[2] += 5;
			t_p2[2] += 10;
			
			DrawBox(t_p1, t_p2, 1.0, color, false);
		}
		case 2:
		{			
			t_p1[2] += plusser;
			t_p2[2] += plusser;
			if(g_iMapzone != 0)
				DrawBox(t_p1, t_p2, 1.0, color, true);
			DrawBox(point1, point2, 1.0, color, true);
		}
		case 3:
		{			
			t_p1[2] += plusser;
			t_p2[2] += plusser;
			if(g_iMapzone > 0)
				DrawBox(t_p1, t_p2, 1.0, color, true);
			DrawBox(point1, point2, 1.0, color, true);
		}
	}
}

public void ArrayCopyZones1(float temp[3], int index)
{
	temp[0] = GetArrayCell(gAl_MapZones1x, index);
	temp[1] = GetArrayCell(gAl_MapZones1y, index);
	temp[2] = GetArrayCell(gAl_MapZones1z, index);
}

public void ArrayCopyZones2(float temp[3], int index)
{
	temp[0] = GetArrayCell(gAl_MapZones2x, index);
	temp[1] = GetArrayCell(gAl_MapZones2y, index);
	temp[2] = GetArrayCell(gAl_MapZones2z, index);
}

//remake - Zipcore copy paste
public void DrawBox(float fFrom[3], float fTo[3], float fLife, int color[4], bool flat)
{
	int iSpriteIndex = precache_laser_default;
	float ZoneBeamHeight = 2.0;
	
	//initialize tempoary variables bottom front
	float fLeftBottomFront[3];
	fLeftBottomFront[0] = fFrom[0];
	fLeftBottomFront[1] = fFrom[1];
	if(flat)
		fLeftBottomFront[2] = fTo[2]-ZoneBeamHeight;
	else
		fLeftBottomFront[2] = fTo[2];
	
	float fRightBottomFront[3];
	fRightBottomFront[0] = fTo[0];
	fRightBottomFront[1] = fFrom[1];
	if(flat)
		fRightBottomFront[2] = fTo[2]-ZoneBeamHeight;
	else
		fRightBottomFront[2] = fTo[2];
	
	//initialize tempoary variables bottom back
	float fLeftBottomBack[3];
	fLeftBottomBack[0] = fFrom[0];
	fLeftBottomBack[1] = fTo[1];
	if(flat)
		fLeftBottomBack[2] = fTo[2]-ZoneBeamHeight;
	else
		fLeftBottomBack[2] = fTo[2];
	
	float fRightBottomBack[3];
	fRightBottomBack[0] = fTo[0];
	fRightBottomBack[1] = fTo[1];
	if(flat)
		fRightBottomBack[2] = fTo[2]-ZoneBeamHeight;
	else
		fRightBottomBack[2] = fTo[2];
	
	//initialize tempoary variables top front
	float fLeftTopFront[3];
	fLeftTopFront[0] = fFrom[0];
	fLeftTopFront[1] = fFrom[1];
	if(flat)
		fLeftTopFront[2] = fFrom[2]+ZoneBeamHeight;
	else
		fLeftTopFront[2] = fFrom[2];
	float fRightTopFront[3];
	fRightTopFront[0] = fTo[0];
	fRightTopFront[1] = fFrom[1];
	if(flat)
		fRightTopFront[2] = fFrom[2]+ZoneBeamHeight;
	else
		fRightTopFront[2] = fFrom[2];
	
	//initialize tempoary variables top back
	float fLeftTopBack[3];
	fLeftTopBack[0] = fFrom[0];
	fLeftTopBack[1] = fTo[1];
	if(flat)
		fLeftTopBack[2] = fFrom[2]+ZoneBeamHeight;
	else
		fLeftTopBack[2] = fFrom[2];
	float fRightTopBack[3];
	fRightTopBack[0] = fTo[0];
	fRightTopBack[1] = fTo[1];
	if(flat)
		fRightTopBack[2] = fFrom[2]+ZoneBeamHeight;
	else
	fRightTopBack[2] = fFrom[2];
	
	/*if(flat == false)
		gCv_ZoneThickness.FloatValue = 0.5;*/
	
	//create the box
	TE_SetupBeamPoints(fLeftTopFront,fRightTopFront,iSpriteIndex,0,0,0,0.99,gCv_ZoneThickness.FloatValue,gCv_ZoneThickness.FloatValue,10,0.0,color,10);TE_SendToAll(0.0);
	TE_SetupBeamPoints(fLeftTopBack,fLeftTopFront,iSpriteIndex,0,0,0,0.99,gCv_ZoneThickness.FloatValue,gCv_ZoneThickness.FloatValue,10,0.0,color,10);TE_SendToAll(0.0);
	TE_SetupBeamPoints(fRightTopBack,fLeftTopBack,iSpriteIndex,0,0,0,0.99,gCv_ZoneThickness.FloatValue,gCv_ZoneThickness.FloatValue,10,0.0,color,10);TE_SendToAll(0.0);
	TE_SetupBeamPoints(fRightTopFront,fRightTopBack,iSpriteIndex,0,0,0,0.99,gCv_ZoneThickness.FloatValue,gCv_ZoneThickness.FloatValue,10,0.0,color,10);TE_SendToAll(0.0);
	
	if(!flat)
	{
		TE_SetupBeamPoints(fRightBottomFront,fLeftBottomFront,iSpriteIndex,0,0,0,fLife,gCv_ZoneThickness.FloatValue,gCv_ZoneThickness.FloatValue,10,0.0,color,10);TE_SendToAll(0.0);
		TE_SetupBeamPoints(fLeftBottomBack,fLeftBottomFront,iSpriteIndex,0,0,0,fLife,gCv_ZoneThickness.FloatValue,gCv_ZoneThickness.FloatValue,10,0.0,color,10);TE_SendToAll(0.0);
		TE_SetupBeamPoints(fLeftTopFront,fLeftBottomFront,iSpriteIndex,0,0,0,fLife,gCv_ZoneThickness.FloatValue,gCv_ZoneThickness.FloatValue,10,0.0,color,10);TE_SendToAll(0.0);
		
		
		TE_SetupBeamPoints(fLeftBottomBack,fRightBottomBack,iSpriteIndex,0,0,0,fLife,gCv_ZoneThickness.FloatValue,gCv_ZoneThickness.FloatValue,10,0.0,color,10);TE_SendToAll(0.0);
		TE_SetupBeamPoints(fRightBottomFront,fRightBottomBack,iSpriteIndex,0,0,0,fLife,gCv_ZoneThickness.FloatValue,gCv_ZoneThickness.FloatValue,10,0.0,color,10);TE_SendToAll(0.0);
		TE_SetupBeamPoints(fRightTopBack,fRightBottomBack,iSpriteIndex,0,0,0,fLife,gCv_ZoneThickness.FloatValue,gCv_ZoneThickness.FloatValue,10,0.0,color,10);TE_SendToAll(0.0);
		
		TE_SetupBeamPoints(fRightTopFront,fRightBottomFront,iSpriteIndex,0,0,0,fLife,gCv_ZoneThickness.FloatValue,gCv_ZoneThickness.FloatValue,10,0.0,color,10);TE_SendToAll(0.0);
		TE_SetupBeamPoints(fLeftTopBack,fLeftBottomBack,iSpriteIndex,0,0,0,fLife,gCv_ZoneThickness.FloatValue,gCv_ZoneThickness.FloatValue,10,0.0,color,10);TE_SendToAll(0.0);
	}
}

public bool ShouldDisplayZone(int zone)
{
	int index = FindValueInArray(gAl_ZonesIdentification, GetArrayCell(gAl_MapZonesIdentification, zone));
	
	return GetArrayCell(gAl_ZonesDraw, index) ? true:false;
}

public void SQL_Trash_Callback(Handle owner, Handle hndl, const char[] error, any data)
{
	if(hndl == null)
	{
		LogError("Timer error! Trash callback - %i. Message: %s", data, error);
		return;
	}
}

public void ConnectSQL()
{
	if(gH_DB != null)
		CloseHandle(gH_DB);
	
	if(SQL_CheckConfig("k-zones")) //Lets make sure we're not dealing with a retard
	{
		char sError[256];
		
		if(!(gH_DB = SQL_Connect("k-zones", true, sError, 255)))
			SetFailState("Timer startup failed. Reason: %s", sError);
			
		SQL_LockDatabase(gH_DB);
		SQL_FastQuery(gH_DB, "SET NAMES 'utf8';"); //shavit thinkin ahead Keepo
		SQL_UnlockDatabase(gH_DB);
		
		char query[512];
		FormatEx(query, 512, "CREATE TABLE IF NOT EXISTS Zones( \
		id int NOT NULL AUTO_INCREMENT, \
		map int, \
		zone int, \
		point1_x float, \
		point1_y float, \
		point1_z float, \
		point2_x float, \
		point2_y float, \
		point2_z float, \
		PRIMARY KEY(id));");
		SQL_TQuery(gH_DB, SQL_Trash_Callback, query);
	}else
	{
		SetFailState("k-zones startup failed. Reason: \"k-zones\" is not an entry in databases.cfg");
	}
}

public int Native_AddZone(Handle plugin, int numParams)
{
	PushArrayCell(gAl_ZonesIdentification, GetNativeCell(2));
	PushArrayCell(gAl_ZonesDraw, GetNativeCell(3));
	int colors[4];
	GetNativeArray(4, colors, 4);
	PushArrayArray(gAl_ZonesColors, colors);
	
	char buffer[32];
	GetNativeString(1, buffer, 32);
	PushArrayString(gAl_ZonesName, buffer);
}