/**
TODO:
add hsw - 0.1 sec to not hold w+a&d
add pause
use tag to make sm_<style>

avg speed
max speed
currentspeed
native for strafe count
BUG:

**/
#pragma semicolon 1
#include <sourcemod>
#include <smlib>
#include <k-physics>
#include <stocks>
#include <ktimer>

//forwards
Handle forward_LoadPluginPhysics = null;

int gI_ClientStyle[MAXPLAYERS + 1];

//Stats from current run
int gI_Strafes[MAXPLAYERS+1];
int gI_ButtonCache[MAXPLAYERS+1];
int gI_Jumps[MAXPLAYERS + 1];
//sync
int gI_GoodGains[MAXPLAYERS+1];
int gI_TotalMeasures[MAXPLAYERS+1];
float gF_AngleCache[MAXPLAYERS+1];
//speed
int gI_SpeedTick[MAXPLAYERS+1];
float gF_SpeedTotal[MAXPLAYERS+1];
float gF_MaxSpeed[MAXPLAYERS+1];
float gF_Currentspeed[MAXPLAYERS+1];

//Arraylist
ArrayList gAl_StyleNames;
ArrayList gAl_StyleTag;
ArrayList gAl_StyleId;
ArrayList gAl_StyleNum1;
ArrayList gAl_StyleNum2;
ArrayList gAl_StyleNum3;
ArrayList gAl_StyleNum4;
ArrayList gAl_StyleNum5;
ArrayList gAl_StyleWorldDmg;
ArrayList gAl_StyleAuto;
ArrayList gAl_StyleDefault;
ArrayList gAl_StyleDataIndex;

//Registered plugins
ArrayList gAl_StylePluginHandles;
ArrayList gAl_StyleOnPlayerMove;
ArrayList gAl_StyleIdentification;
ArrayList gAl_StyleConfig;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("K_AddStyle", Native_AddStyle);
	CreateNative("K_Physics_SetDataIndex", Native_Physics_SetDataIndex);
	CreateNative("K_GetSync", Native_GetSync);
	CreateNative("K_GetJumps", Native_GetJumps);
	CreateNative("K_GetStyle", Native_GetStyle);
	CreateNative("K_GetStrafes", Native_GetStrafes);
	CreateNative("K_GetMaxSpeed", Native_GetMaxSpeed);
	CreateNative("K_GetCurrentSpeed", Native_GetCurrentSpeed);
	CreateNative("K_GetAverageSpeed", Native_GetAverageSpeed);
	
	
	MarkNativeAsOptional("K_AddStyle");
	MarkNativeAsOptional("K_Physics_SetDataIndex");
	MarkNativeAsOptional("K_GetSync");
	MarkNativeAsOptional("K_GetJumps");
	MarkNativeAsOptional("K_GetStyle");
	MarkNativeAsOptional("K_GetStrafes");
	MarkNativeAsOptional("K_GetMaxSpeed");
	MarkNativeAsOptional("K_GetCurrentSpeed");
	MarkNativeAsOptional("K_GetAverageSpeed");
}

public void OnPluginStart()
{	
	RegAdminCmd("sm_reload_physics", cmd_reload_physics, ADMFLAG_CHEATS);
	RegConsoleCmd("sm_style", cmd_style);
	
	forward_LoadPluginPhysics = CreateGlobalForward("K_LoadPluginPhysics", ET_Event);
	
	HookEvent("player_jump", Event_PlayerJump);
	HookEvent("player_hurt", Event_PlayerHurt);
	
	gAl_StyleNames = new ArrayList(22);
	gAl_StyleTag = new ArrayList(5);
	gAl_StyleId = new ArrayList(2);
	gAl_StyleNum1 = new ArrayList(6);
	gAl_StyleNum2 = new ArrayList(6);
	gAl_StyleNum3 = new ArrayList(6);
	gAl_StyleNum4 = new ArrayList(6);
	gAl_StyleNum5 = new ArrayList(6);
	gAl_StyleWorldDmg = new ArrayList(1);
	gAl_StyleAuto = new ArrayList(1);
	gAl_StyleDefault = new ArrayList(1);
	gAl_StyleDataIndex = new ArrayList(6);
	
	gAl_StylePluginHandles = new ArrayList(6);
	gAl_StyleOnPlayerMove = new ArrayList(6);
	gAl_StyleIdentification = new ArrayList(64);
	gAl_StyleConfig = new ArrayList(6);
	LoadPhysics();
}

public Action Event_PlayerHurt(Handle event,const char[] name,bool dontBroadcast)
{
	if(!GetArrayCell(gAl_StyleWorldDmg, gI_ClientStyle[GetClientOfUserId(GetEventInt(event,"userid"))]))
		return Plugin_Handled;
	return Plugin_Continue;
}

public Action Event_PlayerJump(Handle event,const char[] name,bool dontBroadcast)
{
	++gI_Jumps[GetClientOfUserId(GetEventInt(event,"userid"))];
}

public void OnClientConnected(int client)
{
	//find & set client 2 default style
	gI_ClientStyle[client] = FindValueInArray(gAl_StyleDefault, true);
}

public void KT_TimerStarted(int client)
{
	gI_Jumps[client] = 0;
	gI_TotalMeasures[client] = 0;
	gI_GoodGains[client] = 0;
	gI_Strafes[client] = 0;
	gI_SpeedTick[client] = 0;
	gF_SpeedTotal[client] = 0.0;
	gF_MaxSpeed[client] = 0.0;
	gF_Currentspeed[client] = 0.0;
}

public void LoadPhysics()
{
	ClearArrays();
	Call_StartForward(forward_LoadPluginPhysics);
	Call_Finish();
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "configs/ktimer/physics.cfg");
	KeyValues kv = new KeyValues("Physics");
	kv.ImportFromFile(path);
	if(!kv.GotoFirstSubKey(false))
	{
		LogError("File %s not found or \"physics\" entry not made.");
		return;
	}
	
	char buffer[64];
	do{
		kv.GetSectionName(buffer, 64);
		gAl_StyleNames.PushString(buffer);
		
		kv.GetString("tag", buffer, 64, "");
		gAl_StyleTag.PushString(buffer);
		
		kv.GetString("id", buffer, 64);
		gAl_StyleId.PushString(buffer);
		
		kv.GetString("allow_world_damage", buffer, 64, "0");
		gAl_StyleWorldDmg.Push(StringToInt(buffer));
		
		kv.GetString("auto", buffer, 64, "1");
		gAl_StyleAuto.Push(StringToInt(buffer));
		
		kv.GetString("default", buffer, 64, "0");
		gAl_StyleDefault.Push(StringToInt(buffer));
		
		for (int i = 1; i < 6; ++i)
		{
			switch(i)
			{
				case 1:
				{
					kv.GetString("style1", buffer, 64, "NULL");
					gAl_StyleNum1.PushString(buffer);
				}
				case 2:
				{
					kv.GetString("style2", buffer, 64, "NULL");
					gAl_StyleNum2.PushString(buffer);
				}
				case 3:
				{
					kv.GetString("style3", buffer, 64, "NULL");
					gAl_StyleNum3.PushString(buffer);
				}
				case 4:
				{
					kv.GetString("style4", buffer, 64, "NULL");
					gAl_StyleNum4.PushString(buffer);
				}
				case 5:
				{
					kv.GetString("style5", buffer, 64, "NULL");
					gAl_StyleNum5.PushString(buffer);
				}
			}
			if(!StrEqual("NULL", buffer, false))
				PushKeyValues(buffer, kv);
		}
	} while (kv.GotoNextKey());
	delete kv;
}

public void PushKeyValues(char[] buffer, KeyValues &kv)
{
	int arrayIndex = FindStringInArray(gAl_StyleIdentification, buffer);
	if(arrayIndex != -1)
	{
		Call_StartFunction(GetArrayCell(gAl_StylePluginHandles, arrayIndex), GetArrayCell(gAl_StyleConfig, arrayIndex));
		Call_PushCell(kv);
		Call_PushCell(gAl_StyleNames.Length-1);
		Call_Finish();
	}else
	{
		LogError("Failed to locate plugin with the style name %s", buffer);
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	/**************************************************
			This is for calling other plugins
	***************************************************/
	bool changed = false;
	char buffer[64];
	any data[3];
	for (int i = 1; i < 6;++i)
	{
		switch(i)
		{
			case 1:
			{
				GetArrayString(gAl_StyleNum1, gI_ClientStyle[client], buffer, 64);
			}
			case 2:
			{
				GetArrayString(gAl_StyleNum2, gI_ClientStyle[client], buffer, 64);
			}
			case 3:
			{
				GetArrayString(gAl_StyleNum3, gI_ClientStyle[client], buffer, 64);
			}
			case 4:
			{
				GetArrayString(gAl_StyleNum4, gI_ClientStyle[client], buffer, 64);
			}
			case 5:
			{
				GetArrayString(gAl_StyleNum5, gI_ClientStyle[client], buffer, 64);
			}
		}
		
		if(!StrEqual("NULL", buffer, false))
		{
			int index = -1;
			index = FindStringInArray(gAl_StyleIdentification, buffer);
			if(index != -1)
			{
				
				for (int x = 0;x < gAl_StyleDataIndex.Length; ++x)
				{
					GetArrayArray(gAl_StyleDataIndex, x, data);
					Handle plugin = GetArrayCell(gAl_StylePluginHandles, index);
					if(data[0] == plugin && data[1] == gI_ClientStyle[client])
					{
						Action aResult;
						
						Call_StartFunction(plugin, GetArrayCell(gAl_StyleOnPlayerMove, index));
						Call_PushCell(client);
						Call_PushCellRef(buttons);
						Call_PushCell(data[2]);
						int iError = Call_Finish(aResult);
						
						if(iError != SP_ERROR_NONE)
						{
							ThrowNativeError(iError, "Function forward failed");
							break;
						}else if(aResult == Plugin_Changed)
						{
							changed = true;
						}						
						break;
					}
				}
			}else
			{
				LogError("unable to find %s in gAl_StyleIdentification", buffer);
				continue;
			}
		}
	}
	//auto bhop
	if(view_as<bool>(GetArrayCell(gAl_StyleAuto, gI_ClientStyle[client])) && buttons & IN_JUMP && !(GetEntityFlags(client) & FL_ONGROUND))
	{
		//Ladder check
		if (!Client_IsOnLadder(client))
		{
			//water check
			if (GetEntProp(client, Prop_Data, "m_nWaterLevel") <= 1)
			{
				buttons &= ~IN_JUMP;
			}
		}
	}
	
	//speed
	float fVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity); //velocity
	float currentspeed = SquareRoot(Pow(fVelocity[0],2.0)+Pow(fVelocity[1],2.0)); //player speed (units per secound) - zippy ty :D
	gF_Currentspeed[client] = currentspeed;
	
	if(KT_TimerStatus(client) == TIMER_STATE_STARTED)
	{
		++gI_SpeedTick[client];
		gF_SpeedTotal[client] += currentspeed;
		if(currentspeed>gF_MaxSpeed[client])
			gF_MaxSpeed[client] = currentspeed;
	}
	
	//strafes
	if(!(gI_ButtonCache[client] & IN_FORWARD) && buttons & IN_FORWARD)
	{
		++gI_Strafes[client];
	}else if(!(gI_ButtonCache[client] & IN_BACK) && buttons & IN_BACK)
	{
		++gI_Strafes[client];
	}else if(!(gI_ButtonCache[client] & IN_LEFT) && buttons & IN_LEFT)
	{
		++gI_Strafes[client];
	}else if(!(gI_ButtonCache[client] & IN_RIGHT) && buttons & IN_RIGHT)
	{
		++gI_Strafes[client];
	}
	
	//sync -- shavit
	float fAngle = (angles[1] - gF_AngleCache[client]);

	while(fAngle > 180.0)
	{
		fAngle -= 360.0;
	}

	while(fAngle < -180.0)
	{
		fAngle += 360.0;
	}
	
	if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") == -1 && !(GetEntityFlags(client) & FL_INWATER) && fAngle != 0.0)
	{
		float fAbsVelocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fAbsVelocity);

		if(SquareRoot(Pow(fAbsVelocity[0], 2.0) + Pow(fAbsVelocity[1], 2.0)) > 0.0)
		{
			float fTempAngle = angles[1];

			float fAngles[3];
			GetVectorAngles(fAbsVelocity, fAngles);

			if(fTempAngle < 0.0)
			{
				fTempAngle += 360.0;
			}

			float fDirectionAngle = (fTempAngle - fAngles[1]);

			if(fDirectionAngle < 0.0)
			{
				fDirectionAngle = -fDirectionAngle;
			}

			if(fDirectionAngle < 22.5 || fDirectionAngle > 337.5)
			{
				gI_TotalMeasures[client]++;

				if((fAngle > 0.0 && vel[1] < 0.0) || (fAngle < 0.0 && vel[1] > 0.0))
				{
					gI_GoodGains[client]++;
				}
			}
		}
	}
	gF_AngleCache[client] = angles[1];
	gI_ButtonCache[client] = buttons;
	return changed? Plugin_Changed:Plugin_Continue;
}

public int LocateDataIndex(Handle plugin, int styleid)
{
	any buffer[3];
	for (int i = 0; i < gAl_StyleDataIndex.Length;++i)
	{
		GetArrayArray(gAl_StyleDataIndex, i, buffer);
		if(buffer[0] == plugin && buffer[1] == styleid)
			return i;
	}
	return -1;
}

public void ClearArrays()
{
	gAl_StyleNames.Clear();
	gAl_StyleTag.Clear();
	gAl_StyleId.Clear();
	gAl_StyleNum1.Clear();
	gAl_StyleNum2.Clear();
	gAl_StyleNum3.Clear();
	gAl_StyleNum4.Clear();
	gAl_StyleNum5.Clear();
	gAl_StyleWorldDmg.Clear();
	gAl_StyleAuto.Clear();
	gAl_StyleDefault.Clear();
	gAl_StyleOnPlayerMove.Clear();
	gAl_StyleIdentification.Clear();
	gAl_StyleConfig.Clear();
}

public int Native_GetStrafes(Handle plugin, int numParams)
{
	return gI_Strafes[GetNativeCell(1)];
}

public int Native_GetMaxSpeed(Handle plugin, int numParams)
{
	return view_as<int>(gF_MaxSpeed[GetNativeCell(1)]);
}

public int Native_GetCurrentSpeed(Handle plugin, int numParams)
{
	return view_as<int>(gF_Currentspeed[GetNativeCell(1)]);
}

public int Native_GetAverageSpeed(Handle plugin, int numParams)
{
	return view_as<int>(gF_SpeedTotal[GetNativeCell(1)]/gI_SpeedTick[GetNativeCell(1)]);
}

public int Native_GetSync(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return view_as<int>(gI_GoodGains[client] == 0? 0.0:(gI_GoodGains[client] / float(gI_TotalMeasures[client]) * 100.0));
}

public int Native_GetJumps(Handle plugin, int numParams)
{
	return gI_Jumps[GetNativeCell(1)];
}

public int Native_GetStyle(Handle plugin, int numParams)
{
	int index = FindValueInArray(gAl_StyleIdentification, gI_ClientStyle[GetNativeCell(1)]);
	return GetArrayCell(gAl_StyleIdentification, index);
}

public int Native_AddStyle(Handle plugin, int numParams)
{
	PushArrayCell(gAl_StylePluginHandles, plugin);
	PushArrayCell(gAl_StyleOnPlayerMove, GetNativeCell(1));
	char buffer[64];
	GetNativeString(2, buffer, 64);
	PushArrayString(gAl_StyleIdentification, buffer);
	PushArrayCell(gAl_StyleConfig, GetNativeCell(3));
	return;
}
public int Native_Physics_SetDataIndex(Handle plugin, int numParams)
{
	any iBuff[3];
	iBuff[0] = plugin;
	iBuff[1] = GetNativeCell(1);
	iBuff[2] = GetNativeCell(2);
	PushArrayArray(gAl_StyleDataIndex, iBuff);
}

public void PhysicsMenu(int client)
{
	Menu menu = new Menu(Menu_Physics);
	menu.SetTitle("Please select your style");
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	char buffer[64];
	for (int i = 0; i < gAl_StyleNames.Length;++i)
	{
		GetArrayString(gAl_StyleNames, i, buffer, 64);
		menu.AddItem(IntToChar(i), buffer);
	}
	menu.Display(client, 0);
}

public int Menu_Physics(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		gI_ClientStyle[client] = item;
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public Action cmd_reload_physics(int client, int args)
{
	LoadPhysics();
	return Plugin_Handled;
}

public Action cmd_style(int client, int args)
{
	PhysicsMenu(client);
	return Plugin_Handled;
}