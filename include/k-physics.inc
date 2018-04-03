#if defined _k_physics_included
 #endinput
#endif
#define _k_physics_included

/**
 * Called when your suppose 2 add plugin extensions too physics
 *
 * @noreturn
 */
forward void K_LoadPluginPhysics();

/**
 * Adds a style to the timer for future use (see KTimer-physics)
 *
 * @param OnPlayerMove			The function that will be called when a player is moving with this style
 * @param Identification		The unique ID which will be used 2 call the plugin in the config
 * @param config				A function called when your style is being used.
 * @noreturn
 */
native void K_AddStyle(Function OnPlayerMove, char[] Identification, Function config);

native void K_Physics_SetDataIndex(int styleid, int index);

native float K_GetSync(int client);

native int K_GetJumps(int client);

native int K_GetStyle(int client);

native int K_GetStrafes(int client);

native float K_GetMaxSpeed(int client);

native float K_GetCurrentSpeed(int client);

native float K_GetAverageSpeed(int client);