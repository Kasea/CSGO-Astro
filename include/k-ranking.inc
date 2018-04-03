#if defined _k_ranking_included
 #endinput
#endif
#define _k_ranking_included

/**
 * Updates the ranking points for the clients live on the server. (Call this to "reload" client without login message)
 *
 * @noreturn
 */
native void KT_UpdatePointsGame();

/**
 * Returns the points of a client
 * @param int			The client who's points you wish to return.
 *
 * @return				Clients points
 */
native int KT_GetClientPoints(int client);