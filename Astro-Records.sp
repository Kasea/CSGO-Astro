/*
TODO:
Make it work for multiple styles -- inlucdes natives

*/

#pragma semicolon 1
#include <sourcemod>
#include <k-zones>
#include <k-physics>
#include <stocks>
#include <ktimer>
#include <ktimer_records>

Database gH_DB = null;

//Current stats information
int gI_CurrentFinishCount[MAXPLAYERS+1];
float gF_CurrentBest[MAXPLAYERS+1];
float gF_CurrentWr;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("KT_UpdatePointsGame", Native_UpdatePointsGame);
	CreateNative("KT_GetClientPoints", Native_GetClientPoints);
	CreateNative("KT_GetNextPos", Native_GetNextPos);
	CreateNative("KT_GetClientPB", Native_GetClientPB);
	CreateNative("KT_GetWR", Native_GetWR);

	MarkNativeAsOptional("KT_UpdatePointsGame");
	MarkNativeAsOptional("KT_GetClientPoints");
	MarkNativeAsOptional("KT_GetNextPos");
	MarkNativeAsOptional("KT_GetClientPB");
	MarkNativeAsOptional("KT_GetWR");
}

public void OnPluginStart()
{	
	RegConsoleCmd("sm_wr", cmd_wr);
	RegConsoleCmd("sm_ptop", cmd_ptop);
	RegConsoleCmd("sm_prank", cmd_prank);
	RegConsoleCmd("sm_profile", cmd_profile);
	RegConsoleCmd("sm_recent", cmd_recent);
}

public void KT_DatabaseReady()
{
	KT_GetDatabase(gH_DB);
}


public void OnMapEnd()
{
	//save everything in db
}

/********************************************
**************** COMMANDS *******************
********************************************/
public Action cmd_wr(int client, int args)
{
	
}
public Action cmd_ptop(int client, int args)
{
	
}
public Action cmd_prank(int client, int args)
{
	
}
public Action cmd_profile(int client, int args)
{
	//disable chat rank, show ptop, playerinfo, 
}
public Action cmd_recent(int client, int args)
{
	//show recent records, wrs
}

/********************************************
**************** NATIVES ********************
********************************************/

public int Native_UpdatePointsGame(Handle plugin, int numParams)
{
	
}
public int Native_GetClientPoints(Handle plugin, int numParams)
{
	
}
public int Native_GetNextPos(Handle plugin, int numParams)
{
	
}
public int Native_GetClientPB(Handle plugin, int numParams)
{
	return view_as<int>(gF_CurrentBest[GetNativeCell(1)]);
}
public int Native_GetWR(Handle plugin, int numParams)
{
	return view_as<int>(gF_CurrentWr);
}

/********************************************
*************** DATABASE ********************
********************************************/

public void UpdatePlayerRecord(int client, int map, float time, int style, int rank, int finishcount, 
int jumps, float jumpacc, int strafes, float strafeacc, int avgspeed, int maxspeed, int finishspeed)
{
	char query[512];
	Format(STRING(query), "INSERT INTO records(maps, player_id, time, style, rank, finishcount, jumps, jumpacc, strafes, strafeacc, avgspeed, maxspeed, finishspeed, date)\
	VALUES(%i, %i, %f, %i, %i, %i, %i, %f, %i, %f, %i, %i, %i, CURDATE())\
	ON DUPLICATE KEY UPDATE\
	time=%f, rank=%i, finishcount=finishcount+1, jumps=%i, jumpacc=%f, strafes=%i, strafeacc=%f, avgspeed=%i, maxspeed=%i, finishspeed=%i, date=CURDATE()", \
	map, KT_GetClientId(client), time, style, rank, finishcount, jumps, jumpacc, strafes, strafeacc, avgspeed, maxspeed, finishspeed, \
	time, rank, jumps, jumpacc, strafes, strafeacc, avgspeed, maxspeed, finishspeed);
	SQL_TQuery(gH_DB, SQL_UpdatePlayerRecord, query);
}
public void SQL_UpdatePlayerRecord(Handle owner, Handle hndl, const char[] error, any client)
{
	if(hndl == null)
	{
		LogError("Timer error: Failed to insert record. | Message: %s", error);
		return;
	}
}

/********************************************
*************** FORWARDS *******************
********************************************/

public void KT_OnClientEnterStartZone(int client)
{
	if(KT_TimerStatus(client) != TIMER_STATE_STOPPED)
		KT_StopTimer(client);
	KT_StartTimer(client);
}
public void KT_OnClientEnterEndZone(int client)
{
	if(!IsValidClient(client, true) && KT_TimerStatus(client) == TIMER_STATE_STARTED)
		return;
	++gI_CurrentFinishCount[client];
	float endTime = KT_GetTime(client);
	float sync = K_GetSync(client);
	int style = K_GetStyle(client);
	int jumps = K_GetJumps(client);
	int strafes = K_GetStrafes(client);
	float currentSpeed = K_GetCurrentSpeed(client);
	float avgSpeed = K_GetAverageSpeed(client);
	float maxSpeed = K_GetMaxSpeed(client);
	
	if(endTime<gF_CurrentWr)
	{
		//it's a wr
		UpdatePlayerRecord(client, KT_CurrentMapInt(), endTime, style, KT_GetNextPos(endTime), gI_CurrentFinishCount[client], jumps, 100.0, strafes, sync, avgSpeed, maxSpeed, currentSpeed);
		PrintToChatAll("New world record | %.2f", endTime);
	}	
	else if(gF_CurrentBest[client]  == -1.0 || gF_CurrentBest[client] > endTime)
	{
		//first time clearing
		UpdatePlayerRecord(client, KT_CurrentMapInt(), endTime, style, KT_GetNextPos(endTime), gI_CurrentFinishCount[client], jumps, 100.0, strafes, sync, avgSpeed, maxSpeed, currentSpeed);
		PrintToChat(client, "You cleared for the first time or a new record | %.2f", endTime);
	}else if(gF_CurrentBest[client] <= endTime)
	{
		//cleared before but not new record
		PrintToChat(client, "You cleared no new record tho | %.2f", endTime);
	}
	KT_StopTimer(client);
}

public void OnPluginEnd()
{
	OnMapEnd();
}