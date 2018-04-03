#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <ktimer>
#include <smlib/clients>
#include <k-hud>
#include <clientprefs>
#include <stocks>

#define SPECMODE_FREELOOK 6

//forwards
Handle forward_LoadPluginHud = null;

ArrayList gAl_HudPluginHandler;
ArrayList gAl_HudFunction;
ArrayList gAl_HudName;
ArrayList gAl_HudId;
ArrayList gAl_HudMain;

bool gB_EnableHud[MAXPLAYERS + 1] =  { true, ...};
int gI_HudNumber[MAXPLAYERS + 1];

//cookies
Handle hud_on_off_cookie = null;
Handle hud_number_cookie = null;


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("K_AddHud", Native_AddHud);
	
	MarkNativeAsOptional("K_AddHud");
}

public void OnPluginStart()
{	
	forward_LoadPluginHud = CreateGlobalForward("K_LoadPluginHud", ET_Event);
	
	
	gAl_HudPluginHandler = new ArrayList(1);
	gAl_HudFunction = new ArrayList(1);
	gAl_HudName = new ArrayList(64);
	gAl_HudId = new ArrayList(4); //does this need 2 be 4?
	gAl_HudMain = new ArrayList(1);
	
	//cookies
	hud_on_off_cookie = RegClientCookie("timer_hud_on_off", "Does the client want the hud enabled or disabled", CookieAccess_Private);
	hud_number_cookie = RegClientCookie("timer_hud_number", "Which hud does the client use?", CookieAccess_Private);
	
	RegConsoleCmd("sm_hud", cmd_hud);	
	
	Call_StartForward(forward_LoadPluginHud);
	Call_Finish();
	
	CreateTimer(0.1, Timer_CreateHud, _, TIMER_REPEAT);
}

int GetClientHudArray(int client)
{
	return FindValueInArray(gAl_HudId, gI_HudNumber[client]);
}

/**************************
		  COOKIES
***************************/

public OnClientCookiesCached(int client)
{
	LoadCookiesForClient(client);
}

void LoadCookiesForClient(int client)
{
	if((!IsClientInGame(client) && IsFakeClient(client)) || (hud_on_off_cookie == null || hud_number_cookie == null))
		return;
	char buffer[8];
	GetClientCookie(client, hud_on_off_cookie, buffer, 8);
	if(!StrEqual(buffer, ""))
		gB_EnableHud[client] = view_as<bool>(StringToInt(buffer));
	else
		gB_EnableHud[client] = true;
	
	GetClientCookie(client, hud_number_cookie, buffer, 8);
	if(!StrEqual(buffer, "") && DoesThisHudExist(StringToInt(buffer)))
		gI_HudNumber[client] = StringToInt(buffer);
	else
		GiveClientDefaultHud(client);
}

public Action Timer_CreateHud(Handle timer, any data)
{
	if(IsVoteInProgress())
		return Plugin_Continue;
	char buffer[512];
	for (int client = 1; client < MaxClients;client++)
	{
		if(!IsClientInGame(client) || IsFakeClient(client) || !gB_EnableHud[client])
			continue;
		if((!IsPlayerAlive(client) || IsClientObserver(client)) && GetEntProp(client, Prop_Send, "m_iObserverMode") == SPECMODE_FREELOOK)
				continue;
		int index = GetClientHudArray(client);
		if(index == -1)
		{
			LogError("Failed to find %N\'s name", client);
			continue;
		}
		Call_StartFunction(GetArrayCell(gAl_HudPluginHandler, index), GetArrayCell(gAl_HudFunction, index));
		Call_PushCell(UpdateClientInfo(client));
		Call_PushStringEx(STRING(buffer), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
		Call_PushCell(512);
		Call_Finish();
		
		PrintHintText(client, buffer);
	}
	return Plugin_Continue;
}

public void GiveClientDefaultHud(int client)
{
	int index = FindValueInArray(gAl_HudMain, true);
	if(index == -1)
	{
		LogError("Timer error! No default hud found");
		return;
	}
	int new_hud = GetArrayCell(gAl_HudId, index);
	gI_HudNumber[client] = new_hud;
	SetClientCookie(client, hud_number_cookie, IntToChar(new_hud)); //will this work?
}

public bool DoesThisHudExist(int hud)
{
	int index = FindValueInArray(gAl_HudId, hud);
	if(index == -1)
		return false;
	else
		return true;
}

int UpdateClientInfo(int client)
{
	int target = client;
	
	if(IsClientObserver(client))
	{
		if(GetEntProp(client, Prop_Send, "m_iObserverMode") >= 3)
		{
			int iTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

			if(IsValidClient(iTarget, true))
			{
				target = iTarget;
			}
		}
	}
	return target;
}

public int Native_AddHud(Handle plugin, int numParams)
{
	PushArrayCell(gAl_HudPluginHandler, plugin);
	PushArrayCell(gAl_HudFunction, GetNativeCell(1));
	char buffer[64];
	GetNativeString(2, buffer, 64);
	PushArrayString(gAl_HudName, buffer);
	PushArrayCell(gAl_HudId, GetNativeCell(3));
	PushArrayCell(gAl_HudMain, GetNativeCell(4));
}

public void HudMenu(int client)
{
	Menu menu = new Menu(Menu_Hud);
	menu.SetTitle("Please select your hud");
	menu.ExitBackButton = false;
	menu.ExitButton = true;
	menu.AddItem("on", "Enable/Disable hud");
	char buffer[64];
	for (int i = 0; i < gAl_HudPluginHandler.Length; ++i)
	{
		GetArrayString(gAl_HudName, i, buffer, 64);
		menu.AddItem(IntToChar(i), buffer);
	}
	menu.Display(client, 0);
}

public int Menu_Hud(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char info[4];
		menu.GetItem(item, info, 4);
		if(StrEqual(info, "on", false))
		{
			if(gB_EnableHud[client])
			{
				//turn it off
				gB_EnableHud[client] = false;
				SetClientCookie(client, hud_on_off_cookie, "0");
			}else
			{
				//turn it on
				gB_EnableHud[client] = true;
				SetClientCookie(client, hud_on_off_cookie, "1");
			}
		}else
		{
			gI_HudNumber[client] = GetArrayCell(gAl_HudId, StringToInt(info));
			SetClientCookie(client, hud_number_cookie, IntToChar(GetArrayCell(gAl_HudId, StringToInt(info))));
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public Action cmd_hud(int client, int args)
{
	HudMenu(client);
	return Plugin_Handled;
}