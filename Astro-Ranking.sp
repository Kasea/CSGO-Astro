/*
doesn't bring anything "new" to the table, it just does chat stuff basically -- unimportant atm

change the way rankings are stored in the future
*/

#include <sourcemod>
#include <ktimer>
#include <scp>
#include <stocks>
#include <k-ranking>
#include <colors_kasea>

#define MAX_RANKINGS 15
char ranking_title[MAX_RANKINGS + 1][64];
int ranking_rank[MAX_RANKINGS+1] = {100000, ...};

int gI_ClientPoints[MAXPLAYERS + 1];
int gI_ClientRank[MAXPLAYERS + 1];
bool gB_ClientDisplayConnect[MAXPLAYERS + 1] =  { true, ... };

Database gH_DB = null;

public void OnPluginStart()
{
	RegAdminCmd("sm_reload_ranking", cmd_reload_ranking, ADMFLAG_CHEATS);
}

public void KT_DatabaseReady()
{
	KT_GetDatabase(gH_DB);
	LoadRankings();
}

public void LoadRankings()
{
	SQL_TQuery(gH_DB, SQL_LoadRankings_Callback, "SELECT title, rank FROM Rankings;");
}

public void SQL_LoadRankings_Callback(Handle owner, Handle hndl, const char[] error, any data)
{
	if(hndl == null)
	{
		LogError("Timer error! Failed to load rankings. Message: %s", error);
		return;
	}else
	{
		int x = 0;
		while(SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl, 0, ranking_title[x], 64);
			ranking_rank[x] = SQL_FetchInt(hndl, 1);
			++x;
		}
		return;
	}
}

/**************************
	SCP - OnChatMessage
***************************/
public Action OnChatMessage(int &client, Handle recipients, char[] name, char[] message)
{
	char m_szMessage[MAXLENGTH_INPUT];
	strcopy(m_szMessage, sizeof(m_szMessage), name);
	Format(name, MAXLENGTH_INPUT, "%s%s", ranking_title[GetRank(gI_ClientRank[client])], m_szMessage);
	return Plugin_Changed;
}

public void OnClientConnected(int client)
{
	char SteamID[32];
	GetClientAuthId(client, AuthId_Steam2, STRING(SteamID));
	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, MAX_NAME_LENGTH);

	int iLength = ((strlen(sName) * 2) + 1);
	char[] sEscapedName = new char[iLength];
	
	SQL_EscapeString(gH_DB, sName, sEscapedName, iLength);
	char[] sQuery = new char[128+32+(iLength*2)];
	FormatEx(sQuery, 92+32+iLength, "INSERT IGNORE INTO Players(authid, points, playtime, lastname) \
VALUES('%s', 0, 0, '%s');", SteamID, sEscapedName);

	SQL_TQuery(gH_DB, SQL_InsertUser_Callback, sQuery, client);
}

public void SQL_InsertUser_Callback(Handle owner, Handle hndl, const char[] error, any client)
{
	if(hndl == null)
	{
		if(!IsClientConnected(client))
		{
			LogError("Timer error! Failed to insert a disconnected player into the Players table. Message: %s", error);
		}else
		{
			LogError("Timer error! Failed to insert \"%N\"'s name into the Players table. Message: %s", client, error);
		}
		return;
	}else
	{
		char sQuery[200];
		char SteamID[32];
		GetClientAuthId(client, AuthId_Steam2, STRING(SteamID));
		FormatEx(sQuery, 200, "SELECT points, \
(SELECT COUNT(*) FROM Players WHERE points>=(SELECT points FROM Players WHERE authid = '%s')) \
FROM Players WHERE authid = '%s';", SteamID[client], SteamID);
		SQL_TQuery(gH_DB, SQL_LoadClient_Callback, sQuery, client);
	}
}

public void SQL_LoadClient_Callback(Handle owner, Handle hndl, const char[] error, any client)
{
	if(hndl == null)
	{
		LogError("Timer error! Failed while loading client. Message: %s", error);
		return;
	}else
	{
		while(SQL_FetchRow(hndl))
		{
			gI_ClientPoints[client] = SQL_FetchInt(hndl, 0);
			gI_ClientRank[client] = SQL_FetchInt(hndl, 1);
		}
		if(gB_ClientDisplayConnect[client])
		{
			CPrintToChatAll("%t", "Client Connected", ranking_title[GetRank(gI_ClientRank[client])], client, gI_ClientPoints[client]);
			gB_ClientDisplayConnect[client] = false;
		}
		return;
	}
}

public void OnClientDisconnect(int client)
{
	UpdateLastName(client);
}

void UpdateLastName(int client)
{
	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, MAX_NAME_LENGTH);

	int iLength = ((strlen(sName) * 2) + 1);
	char[] sEscapedName = new char[iLength];
	
	SQL_EscapeString(gH_DB, sName, sEscapedName, iLength);
	
	char[] sQuery = new char[88+iLength];
	char SteamID[32];
	GetClientAuthId(client, AuthId_Steam2, STRING(SteamID));
	FormatEx(sQuery, 72+iLength, "UPDATE Players SET lastname = '%s' WHERE authid = '%s'", sEscapedName, SteamID);
	SQL_TQuery(gH_DB, SQL_Trash_Callback, sQuery, 127);
}

public int GetRank(int rank)
{
	for (int i = 0; i < MAX_RANKINGS+1;i++)
	{
		if(ranking_rank[i]>=rank)
			return i;
	}
	return MAX_RANKINGS;
}

public int Native_UpdatePointsGame(Handle plugin, int numParams)
{
	LoopValidClients(client)
		OnClientConnected(client);
}

public int Native_GetClientPoints(Handle plugin, int numParams)
{
	return gI_ClientPoints[GetNativeCell(1)];
}

public Action cmd_reload_ranking(int client, int args)
{
	LoadRankings();
	return Plugin_Handled;
}

public void SQL_Trash_Callback(Handle owner, Handle hndl, const char[] error, any data)
{
	if(hndl == null)
	{
		LogError("Timer error! Trash callback - %i. Message: %s", data, error);
		return;
	}
}