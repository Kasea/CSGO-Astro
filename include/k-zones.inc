#if defined _k_zones_included
 #endinput
#endif
#define _k_zones_included

/**
 * Called when your suppose 2 add plugin extensions too zones
 *
 * @noreturn
 */
forward void K_LoadPluginZones();

/**
 * Called when a client enters a zone
 *
 * @param client			client index
 * @param zone				zone identification
 * @noreturn
 */
forward void K_OnClientEnterZone(int client, int zone);

forward void KT_OnClientEnterStartZone(int client);

forward void KT_OnClientLeaveStartZone(int client);

forward void KT_OnClientEnterEndZone(int client);

forward void KT_OnClientLeaveEndZone(int client);

/**
 * Called when a client leaves a zone
 *
 * @param client			client index
 * @param zone				zone identification
 * @noreturn
 */
forward void K_OnClientLeaveZone(int client, int zone);

/**
 * Adds a zone type which can be used in game
 *
 * @param name					Name of the zone(Max 32)
 * @param identification		a unique int for identifying the plugin in db/ingame&such make sure it isn't same as any other zone
 * @param draw					Should the zone be drawn?
 * @param colors				Colors of the zone if draw = true
 * @noreturn
 */
 native void K_AddZone(char[] name, int identification, bool draw=false, int colors[4] = {255, 0, 0, 255});