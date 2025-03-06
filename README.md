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

- `sm_spec_enable`: Enable or disable the plugin.
- `sm_speclimit`: Limit the number of times players are allowed to use spec.
- `sm_speclimitmode`: When does the limit is going to be reset.
- `sm_specsuicideplayer`: Suicide player when using spec command.
- `sm_speclist_adminonly`: Should regular players be able to list their spectators.
- `sm_spec_entwatch_block`: Block player to go in spec if he has an item.
- `sm_spec_authorizedflags`: Authorize users based on flags.
- `sm_spec_maxtime`: Limit the maximum time a player can spend in spectate.

## Optional Dependencies

- ZombieReloaded
- EntWatch
