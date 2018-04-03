/*
TODO:

*/

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

public Plugin myinfo = 
{
	name = "[KT] Advanced Hud",
	author = "Kasea",
	description = "",
	version = "Development",
	url = ""
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_hud_create", cmd_hud_create);
}

public Action cmd_hud_create(int args, int client)
{
	return Plugin_Handled;
}