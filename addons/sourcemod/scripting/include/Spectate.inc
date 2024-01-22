/**
 * This is the include file for Spectate
 * To check that Spectate is installed and running, verify that the "Spectate" library exists
 */

#if defined _Spectate_included
	#endinput
#endif
#define _Spectate_included

/**
 * Called right before a client was force suicide before moving to spec
 */
forward void Spectate_OnCommitSuicide(int client);

/**
 * Return a list of client's spectator
 *
 * @param client     Any valid client index.
 * @return           Array of spectators.
 */
native bool Spectate_GetClientSpectators(int client, int spectators[MAXPLAYERS+1], int &size);

public SharedPlugin __pl_Spectate = 
{
	name = "Spectate",
	file = "Spectate.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_Spectate_SetNTVOptional()
{
	MarkNativeAsOptional("Spectate_GetClientSpectators");
}
#endif
