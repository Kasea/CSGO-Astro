/*
TODO:
add/remove command for adding/removing ranking titles
optimize physics(check if a style isnt' set and cancel the for loop)
add playtime
add native for getting player id for db

-----------------------------------------------------------------------------------------------------
BUG:


-----------------------------------------------------------------------------------------------------
EFFICIENCY:


COMPLETED:
Zones - done for now
Hud - done for now
Physics - done for now ?

*/
#pragma semicolon 1
#include <sourcemod>
#include <KTimer>
#include <stocks>
#include <smlib>

//variables
int gI_CurrentMap = -1;

Database gH_DB = null;

int gI_MapListSerial = -1;

int gI_ClientId[MAXPLAYERS+1];

//Timer variables
int gI_TimerState[MAXPLAYERS + 1];
float gF_StartTime[MAXPLAYERS + 1];
float gF_TimeModifier[MAXPLAYERS + 1];
float gF_PauseTime[MAXPLAYERS + 1];
float gF_TotalPauseTime[MAXPLAYERS + 1];
float gF_PauseOrigin[MAXPLAYERS + 1][3];
float gF_PauseAngle[MAXPLAYERS + 1][3];
float gF_PauseVelocity[MAXPLAYERS + 1][3];

//Forwards
Handle forward_Started = null;
Handle forward_Stopped = null;
Handle forward_Paused = null;
Handle forward_Resumed = null;
Handle forward_Database = null;

public Plugin myinfo = 
{
	name = "Astro",
	author = "Kasea",
	description = "",
	version = "Development",
	url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{		
	//timer natives
	CreateNative("KT_StartTimer", Native_StartTimer);
	CreateNative("KT_StopTimer", Native_StopTimer);
	CreateNative("KT_PauseTimer", Native_PauseTimer);
	CreateNative("KT_ResumeTimer", Native_ResumeTimer);
	CreateNative("KT_GetTime", Native_GetTimer);
	CreateNative("KT_TimerStatus", Native_TimerStatus);
	CreateNative("KT_AddTime", Native_AddTime);
	CreateNative("KT_GetDatabase", Native_GetDatabase);
	CreateNative("KT_CurrentMapInt", Native_CurrentMapInt);
	CreateNative("KT_GetClientId", Native_GetClientId);
	
	MarkNativeAsOptional("KT_StartTimer");
	MarkNativeAsOptional("KT_StopTimer");
	MarkNativeAsOptional("KT_PauseTimer");
	MarkNativeAsOptional("KT_ResumeTimer");
	MarkNativeAsOptional("KT_GetTime");
	MarkNativeAsOptional("KT_TimerStatus");
	MarkNativeAsOptional("KT_AddTime");
	MarkNativeAsOptional("KT_GetDatabase");
	MarkNativeAsOptional("KT_CurrentMapInt");
	MarkNativeAsOptional("KT_GetClientId");
}

public void OnPluginStart()
{
	SecurityCheck(1594082453); //http://www.epochconverter.com/
	
	//Forwards
	forward_Started = CreateGlobalForward("KT_TimerStarted", ET_Event, Param_Cell);
	forward_Stopped = CreateGlobalForward("KT_TimerStopped", ET_Event, Param_Cell);
	forward_Paused = CreateGlobalForward("KT_TimerPaused", ET_Event, Param_Cell);
	forward_Resumed = CreateGlobalForward("KT_TimerResumed", ET_Event, Param_Cell);
	forward_Database = CreateGlobalForward("KT_DatabaseReady", ET_Event);
	
	//database
	CreateDatabaseConnection();

	//translation
	LoadTranslations("KTimer");
	
	//events
	HookEvent("player_death", Event_Death);
}


/**************************
		   EVENTS
***************************/
public void OnClientPostAdminCheck(int client)
{
	if(gH_DB != null)
	{
		char SteamID[32];
		GetClientAuthId(client, AuthId_Steam2, STRING(SteamID));
		char q[64];
		Format(STRING(q), "SELECT id FROM players WHERE authid = '%s'", SteamID);
		SQL_TQuery(gH_DB, SQL_GetPlayerId, q, client);
	}
}

public void SQL_GetPlayerId(Handle owner, Handle hndl, const char[] error, any client)
{
	if(hndl != null)
	{
		while(SQL_FetchRow(hndl))
		{
			gI_ClientId[client] = SQL_FetchInt(hndl, 0);
		}
	}
}

public void OnMapStart()
{
	char map[PLATFORM_MAX_PATH];
	GetCurrentMap(STRING(map));
	if(gH_DB != null)
	{
		char query[40+PLATFORM_MAX_PATH];
		Format(STRING(query), "SELECT id FROM maps WHERE name = \"%s\"", map);
		SQL_TQuery(gH_DB, SQL_GetMapId, query, _, DBPrio_High);
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
	}
}

public void OnMapEnd()
{
	gI_CurrentMap = -1;
}

public Action Event_Death(Handle event,const char[] name,bool dontBroadcast)
{
	KT_StopTimer(GetClientOfUserId(GetEventInt(event,"userid")));
}

public void OnClientDisconnect(int client)
{
	KT_StopTimer(client);
}

/********
DATABASE
********/
void CreateDatabaseConnection()
{
	if(gH_DB != null)
		CloseHandle(gH_DB);
	
	if(SQL_CheckConfig("KTimer")) //Lets make sure we're not dealing with a retard
	{
		char sError[256];
		
		if(!(gH_DB = SQL_Connect("KTimer", true, sError, 255)))
			SetFailState("Timer startup failed. Reason: %s", sError);
			
		SQL_LockDatabase(gH_DB);
		SQL_FastQuery(gH_DB, "SET NAMES 'utf8';"); //shavit thinkin ahead Keepo
		SQL_UnlockDatabase(gH_DB);
		CreateDatabase();
	}else
	{
		SetFailState("Timer startup failed. Reason: \"KTimer\" is not an entry in databases.cfg");
	}
}

void CreateDatabase()
{
	Transaction sql_trans = SQL_CreateTransaction();
	char query[360];
		
	FormatEx(STRING(query), "CREATE TABLE IF NOT EXISTS Rankings( \
	id int NOT NULL AUTO_INCREMENT, \
	title VARCHAR(64) NOT NULL, \
	rank int NOT NULL, PRIMARY KEY(id))");
	SQL_AddQuery(sql_trans, query);
	
	FormatEx(STRING(query), "CREATE TABLE IF NOT EXISTS Records( \
	id int NOT NULL AUTO_INCREMENT, \
	maps int, \
	player_id int, \
	time float(10, 3), \
	style int, \
	finishcount int, \
	jumps int, \
	strafes int, \
	strafeacc float(3, 2), \
	avgspeed float(8, 2), \
	maxspeed float(10, 2), \
	finishspeed int, \
	date DATE, \
	PRIMARY KEY(id), unique key(maps, player_id, style))");
	SQL_AddQuery(sql_trans, query);
	
	FormatEx(STRING(query), "CREATE TABLE IF NOT EXISTS Zones( \
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
	SQL_AddQuery(sql_trans, query);
	
	FormatEx(STRING(query), "CREATE TABLE IF NOT EXISTS Players( \
	id int NOT NULL AUTO_INCREMENT, \
	authid VARCHAR(32), \
	points int, \
	playtime int, \
	lastname VARCHAR(32), \
	PRIMARY KEY(id), \
	UNIQUE KEY(authid))");
	SQL_AddQuery(sql_trans, query);
	
	FormatEx(STRING(query), "CREATE TABLE IF NOT EXISTS Maps( \
	id int NOT NULL AUTO_INCREMENT, \
	name VARCHAR(128), \
	PRIMARY KEY(id), unique key(name))");
	SQL_AddQuery(sql_trans, query);
	
	SQL_ExecuteTransaction(gH_DB, sql_trans, _, TableCreateFail_Callback);
	Call_StartForward(forward_Database);
	Call_Finish();
	LoopValidClients(x)
		OnClientPostAdminCheck(x);
	AddAllMapsIntoDatabase();
}

public void TableCreateFail_Callback(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("Timer error! Failed to create database. Message: %s", error);
}

void AddAllMapsIntoDatabase()
{
	ArrayList MapList = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	if(ReadMapList(MapList, gI_MapListSerial, "ktimer", MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_MAPSFOLDER) != null)
	{
		Transaction sql_trans = SQL_CreateTransaction();
		char query[37 + PLATFORM_MAX_PATH];
		char map[PLATFORM_MAX_PATH];
		for (int i = 0; i < MapList.Length; ++i)
		{
			MapList.GetString(i, map, PLATFORM_MAX_PATH);
			if(FindMap(map, map, PLATFORM_MAX_PATH) != FindMap_NotFound)
			{
				Format(query, (37+PLATFORM_MAX_PATH), "INSERT IGNORE INTO Maps(name) VALUES(\"%s\")", map);
				SQL_AddQuery(sql_trans, query);
			}
		}
		SQL_ExecuteTransaction(gH_DB, sql_trans);
	}
}

public void SQL_Trash_Callback(Handle owner, Handle hndl, const char[] error, any data)
{
	if(hndl == null)
	{
		LogError("Timer error! Trash callback - %i. Message: %s", data, error);
		return;
	}
}

/********
 NATIVES
********/
public int Native_CurrentMapInt(Handle plugin, int numParams)
{
	return gI_CurrentMap;
}

public int Native_GetClientId(Handle plugin, int numParams)
{
	return gI_ClientId[GetNativeCell(1)];
}

public int Native_StartTimer(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	gF_StartTime[client] = GetEngineTime();
	gI_TimerState[client] = TIMER_STATE_STARTED;
	Call_StartForward(forward_Started);
	Call_PushCell(client);
	Call_Finish();
}
public int Native_StopTimer(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	//reset every variable
	gF_TimeModifier[client] = 0.0;
	gF_TotalPauseTime[client] = 0.0;
	gI_TimerState[client] = TIMER_STATE_STOPPED;
	Call_StartForward(forward_Stopped);
	Call_PushCell(client);
	Call_Finish();
}
public int Native_PauseTimer(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	GetClientAbsOrigin(client, gF_PauseOrigin[client]);
	GetClientEyeAngles(client, gF_PauseAngle[client]);
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", gF_PauseVelocity[client]);
	gF_PauseTime[client] = GetEngineTime();
	gI_TimerState[client] = TIMER_STATE_PAUSED;
	Call_StartForward(forward_Paused);
	Call_PushCell(client);
	Call_Finish();
}
public int Native_ResumeTimer(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	gF_TotalPauseTime[client] = GetEngineTime() - gF_PauseTime[client];
	TeleportEntity(client, gF_PauseOrigin[client], gF_PauseAngle[client], gF_PauseVelocity[client]);
	gI_TimerState[client] = TIMER_STATE_STARTED;
	Call_StartForward(forward_Resumed);
	Call_PushCell(client);
	Call_Finish();
}
public int Native_GetTimer(Handle plugin, int numParams)
{
	return view_as<int>(GetEngineTime() - gF_TotalPauseTime[GetNativeCell(1)] - gF_StartTime[GetNativeCell(1)]);
}
public int Native_TimerStatus(Handle plugin, int numParams)
{
	return gI_TimerState[GetNativeCell(1)];
}
public int Native_AddTime(Handle plugin, int numParams)
{
	gF_TimeModifier[GetNativeCell(1)] += GetNativeCell(2);
}
public int Native_GetDatabase(Handle plugin, int numParams)
{
	SetNativeCellRef(1, gH_DB);
}

/**********
  SECURITY
**********/
void SecurityCheck(int EpochTime)
{
	if(GetTime()>EpochTime)
	{
		char cPluginName[244];
		GetPluginFilename(GetMyHandle(), cPluginName, sizeof(cPluginName));
		ServerCommand("sm plugins unload %s", cPluginName);
	}
}