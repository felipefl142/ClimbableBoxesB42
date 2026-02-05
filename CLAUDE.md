# CLAUDE.md - Climbable Boxes Mod

## Project Overview

A Project Zomboid Build 42.13 mod that lets players climb onto boxes and crates. Players can climb via keybind (default: G) or right-click context menu. The player is teleported to the box's grid square at the same Z-level. Full multiplayer support. Depends on TchernoLib.

## Directory Structure

```
Climbable Boxes B42/Contents/mods/ClimbableBoxes/
├── 42.13/                          # Primary build (all code lives here)
│   ├── mod.info
│   ├── media/
│   │   ├── sandbox-options.txt
│   │   ├── AnimSets/player/actions/   # 5 animation XMLs
│   │   └── lua/
│   │       ├── client/
│   │       │   ├── ClimbBoxConfig.lua       # Keybind (PZAPI ModOptions)
│   │       │   ├── ClimbBoxHealth.lua       # Injury checks
│   │       │   ├── ClimbBox.lua             # Main logic, box detection, input loop
│   │       │   └── ClimbBoxContextMenu.lua  # Right-click menu
│   │       └── shared/
│   │           ├── Actions/ISClimbBox.lua   # Timed action + MP sync
│   │           └── Translate/EN/UI_EN.txt   # Localization
├── 42/                             # Build 42 compat (mod.info + sandbox only)
```

## Key Architecture

- **Box detection**: Property-based using `IsMoveAble` flag + `ContainerType` property (not sprite name lists)
- **Target**: Adjacent square at same Z-level (unlike Climb mod which targets Z+1)
- **Animation state machine**: ClimbBoxStart (with events at 30%/90%) -> Success/Struggle/Fail -> End
- **Animations**: Reuses `Bob_ClimbFence_*` base game animations
- **MP sync**: `sendClientCommand`/`OnClientCommand` pattern for endurance

## Build 42.13 API Patterns

These are critical — B42.13 changed many APIs from B42:

| Feature | B42.13 Pattern |
|---------|---------------|
| Action constructor | `ISBaseTimedAction.new(self, character)` |
| Traits | `character:hasTrait(CharacterTrait.EMACIATED)` |
| Moodles | `MoodleType.ENDURANCE` (uppercase enum) |
| Stats | `stats:remove(CharacterStat.ENDURANCE, amount)` |
| Square flags | `square:has(IsoFlagType.X)` |
| Player angle | `character:getAnimSetName()` returns 0, 90, -90, 180 |

## Sandbox Options

- **DifficultyMode**: 1=Full (success/struggle/fail), 2=Simplified (always succeed)
- **BaseSuccessRate**: Starting success % before modifiers (default 90)
- **EnduranceCostMultiplier**: Scales endurance cost (0=free, 1=normal, 5=brutal)
- **EnableHealthCheck**: Toggle injury-based blocking

## Dependencies

- **TchernoLib** (Steam Workshop 3389605231) — provides `MovePlayer.Teleport()` and other utilities

## Reference Documentation

- `CLIMB_MOD.md` — Full technical documentation of the Climb wall mod (the model for this mod)
- `TCHERNOLIB_MOD.md` — TchernoLib API reference (12 systems)

## Common Tasks

- **Adding new container types**: Edit `ClimbBox.isClimbableBox()` in `ClimbBox.lua`, add to `validTypes` table
- **Adjusting success modifiers**: Edit `ISClimbBox:computeSuccessRate()` in `ISClimbBox.lua`
- **Adding body part checks**: Edit `upperBodyParts` or `legParts` tables in `ClimbBoxHealth.lua`
- **Changing default keybind**: Edit `Keyboard.KEY_G` in `ClimbBoxConfig.lua`
- **Adding localization**: Add entries to `UI_EN.txt`, create new `UI_XX.txt` for other languages
