#include <sourcemod>
#include <smlib>
#include <k-physics>

int gI_StyleDefault = 0;
int gI_StyleParkour = 0;

ArrayList gAl_BlockKeys;
ArrayList gAl_Parkour;

//disable keys
float gB_PunishTimer[MAXPLAYERS+1] = {0.0,...};

//parkour
int ParkourCounter[MAXPLAYERS+1];
bool g_bCanUseParkour[MAXPLAYERS+1] = {true, ...};


public void OnPluginStart()
{
	gAl_BlockKeys = new ArrayList(4);
	gAl_Parkour = new ArrayList(3);
}

public void K_LoadPluginPhysics()
{
	K_AddStyle(Parkour_OnPlayerMove, "parkour", Parkour_config);
	K_AddStyle(Default_OnPlayerMove, "default", Default_config);
}

public Action Parkour_OnPlayerMove(int client, int &buttons, int Style)
{
	any buffer[3];
	GetArrayArray(gAl_Parkour, Style, buffer);
	bool onground = view_as<bool>(GetEntityFlags(client) & FL_ONGROUND);
	
	if(buttons & IN_ATTACK2 && !onground && ParkourCounter[client] < buffer[2] && g_bCanUseParkour[client] && (WallLeft(client) || WallRight(client)))
	{
		g_bCanUseParkour[client] = false;
		CreateTimer(0.1, EnableParkOur, client);
		++ParkourCounter[client];
		float vVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
		
		vVel[2] = view_as<float>(buffer[0]);
		vVel[0] *= view_as<float>(buffer[1]);
		vVel[1] *= view_as<float>(buffer[1]);
		
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
	}
	
	if(onground)
	{
		ParkourCounter[client] = 0;
	}
	return Plugin_Continue;
}

public void Parkour_config(KeyValues kv, int StyleId)
{
	K_Physics_SetDataIndex(StyleId, gI_StyleParkour);
	any buffer[3];
	
	buffer[0] = kv.GetFloat("parkour_jump_boost", 250.0);
	buffer[1] = kv.GetFloat("parkour_forward_boost", 1.15);
	buffer[2] = kv.GetNum("parkour_count", 3);
	PushArrayArray(gAl_Parkour, buffer);
	++gI_StyleParkour;
}

public Action Default_OnPlayerMove(int client, int &buttons, int Style)
{
	//check if client is in ladder/water
	if (Client_IsOnLadder(client) || GetEntProp(client, Prop_Data, "m_nWaterLevel") >= 1)
	{
		return Plugin_Continue;
	}
	any buffer[4];
	GetArrayArray(gAl_BlockKeys, Style, buffer);
	bool abuse = false;
	if(buttons & IN_LEFT && buffer[0])
	{
		abuse = true;
	}else if(buttons & IN_BACK && buffer[1])
	{
		abuse = true;
	}else if(buttons & IN_RIGHT && buffer[2])
	{
		abuse = true;
	}else if(buttons & IN_FORWARD && buffer[3])
	{
		abuse = true;
	}
	if (abuse)
	{
		gB_PunishTimer[client] = GetGameTime()+2.0;
		Block_MovementControl(client, false);
	}else if(gB_PunishTimer[client]-GetGameTime() < 0.0)
	{
		Block_MovementControl(client, true);
	}
	return Plugin_Continue;
}

void Block_MovementControl(client, bool unblock)
{
	if(!unblock)
	{
		SetEntityFlags(client, GetEntityFlags(client) | FL_ATCONTROLS);
	}
	else
	{
		SetEntityFlags(client, GetEntityFlags(client) & ~FL_ATCONTROLS);
	}
}

public void Default_config(KeyValues kv, int StyleId)
{
	K_Physics_SetDataIndex(StyleId, gI_StyleDefault);
	any buffer[4];
	buffer[0] = view_as<bool>(kv.GetNum("blockA", 0));
	buffer[1] = view_as<bool>(kv.GetNum("blockS", 0));
	buffer[2] = view_as<bool>(kv.GetNum("blockD", 0));
	buffer[3] = view_as<bool>(kv.GetNum("blockW", 0));
	PushArrayArray(gAl_BlockKeys, buffer);
	++gI_StyleDefault;
}

public Action EnableParkOur(Handle timer, any client)
{
	g_bCanUseParkour[client] = true;
	return Plugin_Stop;
}

public bool IsThereAWallHere(int client, float distance, float LeftOrRight)
{
	//Shove the client to the right || angle x -90 x
	float posEye[3];
	float posEyeAngles[3];
	bool isClientLookingAtWall = false;
	
	GetClientEyePosition(client,	posEye);
	GetClientEyeAngles(client, posEyeAngles);
	posEyeAngles[1] += LeftOrRight;
	
	posEyeAngles[1] = CalculateAngle(posEyeAngles[1]);
	posEyeAngles[0] = 0.0;

	Handle trace = TR_TraceRayFilterEx(posEye, posEyeAngles, CONTENTS_SOLID, RayType_Infinite, _smlib_TraceEntityFilter);
	
	if (TR_DidHit(trace)) {
		
		if (TR_GetEntityIndex(trace) > 0) {
			CloseHandle(trace);
			return false;
		}
		
		float posEnd[3];

		TR_GetEndPosition(posEnd, trace);
		
		if (GetVectorDistance(posEye, posEnd, true) <= (distance * distance)) {
			isClientLookingAtWall = true;
		}
	}
	
	CloseHandle(trace);
	
	return isClientLookingAtWall;
}

float CalculateAngle(float posEyeAngles)
{
	if(posEyeAngles > 180.0)
	{
		float temp_Float = posEyeAngles - 180.0;
		posEyeAngles = (temp_Float)+(180.0);
	}else if(posEyeAngles < -180.0)
	{
		float temp_Float = (-180.0)-(posEyeAngles);
		posEyeAngles = 180.0-temp_Float;
	}
	return posEyeAngles;
}

public bool WallLeft(int client)
{
	return IsThereAWallHere(client, 20.0, 90.0);
}

public bool WallRight(int client)
{
	return IsThereAWallHere(client, 20.0, -90.0);
}