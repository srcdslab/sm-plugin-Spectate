# Spectate Plugin for SourceMod

Add a commands to spectate specific players and removes broken spectate mode.

## Features

- Enable or disable the plugin with a ConVar.
- Limit the number of times players are allowed to use spec.
- Control the spectate limit mode with a ConVar.
- Force players to suicide before switching to spec.
- Restrict the spectate list to admins only.
- Integration with ZombieReloaded and EntWatch plugin.
- Authorize users based on flags.
- Limit the maximum time a player can spend in spectate mode.

## ConVars

- `g_cEnable`: Enable or disable the plugin.
- `g_cSpecLimit`: Limit the number of times players are allowed to use spec.
- `g_cSpecLimitMode`: When does the limit is going to be reset.
- `g_cSuicidePlayer`: Suicide player when using spec command.
- `g_cSpecListAdminOnly`: Should regular players be able to list their spectators.
- `g_cEntWatch`: Block player to go in spec if he has an item.
- `g_cAuthorizedFlags`: Authorize users based on flags.
- `g_cMaxTimeInSpec`: Limit the maximum time a player can spend in spectate.

## Optional Dependencies

- ZombieReloaded
- EntWatch
