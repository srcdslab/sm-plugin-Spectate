# Copilot Instructions for sm-plugin-Spectate

## Repository Overview

This repository contains the **Spectate** plugin for SourceMod, a scripting platform for Source engine games. The plugin adds enhanced spectate functionality, allowing players to spectate specific players with configurable limits and admin controls.

### Key Features
- Spectate specific players with console commands
- Configurable spectate limits and timeouts
- Integration with ZombieReloaded and EntWatch plugins
- Admin-only spectator list functionality
- Native API for other plugins

## Development Environment

### Language & Platform
- **Language**: SourcePawn (.sp files)
- **Platform**: SourceMod 1.11+ (currently using 1.11.0-git6934)
- **Compiler**: SourcePawn compiler (spcomp) via native GitHub Actions CI
- **Build System**: GitHub Actions (`.github/workflows/ci.yml`)

### Dependencies
This plugin requires several include files that are automatically fetched during build:
- `sourcemod` - Core SourceMod includes
- `multicolors` - Color formatting for chat messages
- `loghelper` - Logging utilities
- `adminhelper` - Admin permission utilities
- `zombiereloaded` - Optional ZombieReloaded integration
- `EntWatch` - Optional EntWatch integration

## Project Structure

```
/
├── addons/sourcemod/
│   ├── scripting/
│   │   ├── Spectate.sp          # Main plugin source
│   │   └── include/
│   │       └── Spectate.inc     # Native API definitions
│   └── gamedata/
│       └── spectate.games.txt   # Game-specific offsets
├── .github/
│   └── workflows/
│       └── ci.yml               # Build and release pipeline
└── README.md
```

## Code Style & Standards

### Required Pragmas
All SourcePawn files must include these pragmas at the top:
```sourcepawn
#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 0  // This plugin uses tab size 0
```

### Naming Conventions
- **Global variables**: Prefix with `g_` (e.g., `g_cEnable`, `g_iSpecAmount`)
- **ConVars**: Prefix with `g_c` (e.g., `g_cSpecLimit`)
- **Functions**: Use PascalCase (e.g., `OnPluginStart`, `RemoveLastClientSpectate`)
- **Local variables**: Use camelCase
- **Constants**: Use ALL_CAPS with underscores

### Variable Declarations
- Use `ConVar` type for console variables
- Initialize arrays with explicit size: `int g_iSpecAmount[MAXPLAYERS + 1] = { 0, ... };`
- Use proper Handle management with `CloseHandle()` in cleanup

### Memory Management
- Always call `CloseHandle()` for handles in `OnPluginEnd()`
- Use `delete` for StringMaps/ArrayLists (not `.Clear()` which causes memory leaks)
- No need to check for null before calling `delete`

## Build Process

### Building Locally
The project builds via native GitHub Actions using `rumblefrog/setup-sp` and `spcomp`. The workflow:
1. Installs the SourcePawn compiler (SourceMod 1.12.x)
2. Clones dependency repos (multicolors, loghelper, adminhelper, zombiereloaded, EntWatch) and copies their includes
3. Compiles `Spectate.sp` to `Spectate.smx`
4. Outputs to `addons/sourcemod/plugins/`

### Build Configuration
- Target: `Spectate` (compiled in `.github/workflows/ci.yml`)
- Output: Plugin binary (`.smx` file)
- Dependencies are cloned and their includes copied at build time

### CI/CD Pipeline
- Builds on `ubuntu-latest` via `.github/workflows/ci.yml`
- Uses `rumblefrog/setup-sp@v1.3.1` to install the SourcePawn compiler
- Creates release packages with plugins
- Automatic tagging (`latest`) and releases on pushes to `master`/`main`

## Plugin Architecture

### Core Components

1. **Main Plugin** (`Spectate.sp`):
   - Console commands: `sm_spec`, `sm_spectate`, `sm_speclist`
   - ConVars for configuration
   - Event hooks for player spawn and round end
   - DHooks integration for spectate validation

2. **Native API** (`Spectate.inc`):
   - `Spectate_GetClientSpectators()` - Returns array of client's spectators
   - Proper shared plugin definition for optional loading

3. **Game Data** (`spectate.games.txt`):
   - Platform-specific offsets for `IsValidObserverTarget`
   - Supports CS:GO, TF2, DoD, HL2MP

### Integration Points

**Optional Plugin Integration:**
```sourcepawn
#undef REQUIRE_PLUGIN
#tryinclude <zombiereloaded>
#tryinclude <EntWatch>
#define REQUIRE_PLUGIN
```

**Library Detection:**
```sourcepawn
public void OnAllPluginsLoaded()
{
    g_bZombieReloaded = LibraryExists("zombiereloaded");
    g_bEntWatch = LibraryExists("EntWatch");
}
```

## Development Guidelines

### Adding Features
1. **New ConVars**: Follow the `sm_spec_*` naming pattern
2. **New Commands**: Use both long and short forms (e.g., `sm_spectate` and `sm_spec`)
3. **Event Hooks**: Use appropriate hook modes (`EventHookMode_Post` for most cases)
4. **Native Functions**: Document in the `.inc` file with parameters and return values

### Error Handling
- Use `SetFailState()` for critical initialization failures
- Check `LibraryExists()` before calling optional plugin natives
- Validate client indices before array access
- Handle DHooks failures gracefully

### Performance Considerations
- Cache expensive operations (team assignments, etc.)
- Use efficient data structures (prefer arrays over StringMaps for indexed data)
- Minimize operations in frequently called hooks
- Clean up timers and handles properly

### Plugin Compatibility
- Use `#tryinclude` for optional dependencies
- Check library existence before calling natives
- Implement proper fallback behavior when optional plugins aren't loaded
- Use `MarkNativeAsOptional()` for conditional natives

## Testing & Validation

### Local Testing
- Test on a local Source engine server
- Verify all ConVars work as expected
- Test with and without optional plugins (ZR, EntWatch)
- Check memory usage with SourceMod's profiler

### CI Validation
- Code compiles without warnings
- All dependencies resolve correctly
- Package creation succeeds
- No syntax or semantic errors

### Game Testing
- Test spectate functionality in-game
- Verify admin restrictions work
- Test spectate limits and timeouts
- Ensure compatibility with target Source engine games

## Common Patterns

### ConVar Creation
```sourcepawn
g_cEnable = CreateConVar("sm_spec_enable", "1", "Enable or disable the plugin [0 = No, 1 = Yes]");
```

### Client Validation
```sourcepawn
if (!IsClientValid(client))
    return;
```

### Admin Permission Checks
```sourcepawn
if (!AdminHelper_HasAccess(client, g_cAuthorizedFlags))
{
    // Handle unauthorized access
}
```

### Array Initialization
```sourcepawn
for (int i = 0; i < MAXPLAYERS+1; i++)
    for (int y = 0; y < MAXPLAYERS+1; y++)
        g_iClientSpectators[i][y] = -1;
```

## Troubleshooting

### Common Issues
- **Build failures**: Check dependency repo availability in the CI workflow
- **Runtime errors**: Verify game data offsets for target game
- **Memory leaks**: Ensure proper handle cleanup in `OnPluginEnd()`
- **Integration issues**: Check library existence before calling optional natives

### Debugging
- Use `LogMessage()` for debug output
- Check SourceMod error logs
- Verify ConVar values with `sm_cvar`
- Test with `sm_plugins list` to ensure proper loading

## Version Control

- Use semantic versioning in plugin info
- Update version in `myinfo` structure
- Tag releases consistently
- Keep changelog updated for significant changes

## Resources

- [SourceMod Scripting Documentation](https://sm.alliedmods.net/new-api/)
- [SourcePawn Language Reference](https://sp.alliedmods.net/)
- [DHooks Documentation](https://github.com/peace-maker/DHooks2)