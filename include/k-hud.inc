#if defined _k_hud_included
 #endinput
#endif
#define _k_hud_included

/**
 * Called when your suppose 2 add plugin extensions too hud
 *
 * @noreturn
 */
forward void K_LoadPluginHud();

/**
 * Adds a hud to the timer for future use
 *
 * @param Function					The function that should be called when your going to draw a new hud
 * @param char[]					Name of your hud
 * @param int						A unique identificator for your hud
 * @param bool						Should this be the main hud? Note: One hud needs too be the main, but not more then one
 * @call						public void HudFunc(int client, int DisplayClient)
 * @noreturn
 */
native void K_AddHud(Function HudFunc, char[] name, int id, bool main=false);