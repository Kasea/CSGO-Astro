#if defined _KTimer_included
 #endinput
#endif
#define _KTimer_included

#define TIMER_STATE_STARTED 0
#define TIMER_STATE_STOPPED 1
#define TIMER_STATE_PAUSED 2

/**
 * Called when a client's timer is started
 *
 * @param client					Client index.
 * @noreturn
 */
forward void KT_TimerStarted(int client);

/**
 * Called when a client's timer is stopped
 *
 * @param client					Client index.
 * @noreturn
 */
forward void KT_TimerStopped(int client);

/**
 * Called when a client's timer is paused
 *
 * @param client					Client index.
 * @noreturn
 */
forward void KT_TimerPaused(int client);

/**
 * Called when a client's timer is resumed
 *
 * @param client					Client index.
 * @noreturn
 */
forward void KT_TimerResumed(int client);

/**
 * Called when the database is ready
 *
 * @noreturn
 */
forward void KT_DatabaseReady();

/**
 * Starts a players timer
 *
 * @param client					Client index.
 * @noreturn
 */
native void KT_StartTimer(int client);

/**
 * Stops a players timer
 *
 * @param client					Client index.
 * @noreturn
 */
native void KT_StopTimer(int client);

/**
 * Pauses a players timer
 *
 * @param client					Client index.
 * @noreturn
 */
native void KT_PauseTimer(int client);

/**
 * Resumes a players timer
 *
 * @param client					Client index.
 * @noreturn
 */
native void KT_ResumeTimer(int client);


/**
 * Get's a clients current time
 *
 * @param client					Client index.
 * @return							The clients time in a float value.
 */
native float KT_GetTime(int client);

/**
 * Returns the timers current status
 *
 * @param client					Client index.
 * @return							Returns the current state of the timer for a client. TIMER_STATE_
 */
native int KT_TimerStatus(int client);

/**
 * Adds x time onto the current timer of the client
 *
 * @param client					Client index.
 * @param time						The amount of time you wish to add/substract from the current time.
 * @noreturn
 */
native void KT_AddTime(int client, float time);


/**
 * Changes the handle you give to the database handle the timer is using
 *
 * @param Handle						Handle you wish to use.
 * @noreturn						
 */
native void KT_GetDatabase(Handle &hndl);

native int KT_CurrentMapInt();