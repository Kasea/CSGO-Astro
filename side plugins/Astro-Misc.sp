#include <sourcemod>

public void OnPluginStart()
{
	RegConsoleCmd("sm_settings", cmd_settings);
	RegConsoleCmd("sm_hide", cmd_hide);
	RegConsoleCmd("sm_spec", cmd_spec);
}

public Action cmd_settings(int client, int args)
{
	
}

public Action cmd_hide(int client, int args)
{
	
}

public Action cmd_spec(int client, int args)
{
	
}