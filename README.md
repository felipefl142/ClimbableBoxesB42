# Climbable Boxes (B42)

A Project Zomboid mod for Build 42.13+ that lets players climb onto boxes and crates. Face a box, press **G** (or right-click it), and your character will climb up onto it.

## Features

- **Keybind and context menu** — Press G while facing a box, or right-click it and select "Climb onto box"
- **Difficulty modes** — Choose between Full mode (success/struggle/fail based on character stats) or Simplified mode (always succeed)
- **Stat-based outcomes** — In Full mode, fitness, strength, endurance, carry weight, traits, and nearby threats all affect whether you succeed, struggle, or fail
- **Injury system** — Broken arms, deep wounds, or busted legs prevent climbing (toggleable in sandbox settings)
- **Endurance cost** — Climbing consumes endurance, with a configurable cost multiplier
- **Multiplayer support** — Full MP sync via `sendClientCommand`/`OnClientCommand`
- **Smart box detection** — Recognizes boxes and crates by game properties (`IsMoveAble` + `ContainerType`), not hardcoded sprite lists. Works with modded containers that follow standard PZ conventions
- **Climbing animations** — Reuses base game fence-climbing animations with a multi-stage state machine (start, success/struggle/fail, end)

## Requirements

- Project Zomboid **Build 42.13+**
- [TchernoLib](https://steamcommunity.com/sharedfiles/filedetails/?id=3389605231) — provides `MovePlayer.Teleport()` and other utilities

## Installation

Subscribe on the [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3660180662), or manually copy the `Climbable Boxes B42/` folder into your Project Zomboid mods directory.

Make sure TchernoLib is installed and loaded before this mod.

## Sandbox Options

Configurable under the **ClimbableBoxes** page in sandbox settings:

| Option | Default | Description |
|--------|---------|-------------|
| Difficulty Mode | Full | Full = success/struggle/fail based on stats. Simplified = always succeed. |
| Base Success Rate | 90% | Starting success chance before stat modifiers (Full mode only). Range: 10-100. |
| Endurance Cost Multiplier | 1.0 | Scales endurance consumption. 0 = free, 1 = normal, up to 5. |
| Enable Health Check | On | Whether injuries to arms, torso, and legs block climbing. |

## How It Works

1. Player faces a box/crate and presses G (or right-clicks and selects "Climb onto box")
2. The mod detects the adjacent box using property-based checks
3. A timed action starts with a climbing animation
4. In **Full mode**, the mod rolls against the player's success rate:
   - **Success** — Clean climb, normal endurance cost
   - **Struggle** — Makes it up but costs extra endurance
   - **Fail** — Doesn't make it, endurance still consumed
5. On success/struggle, the player is teleported onto the box's tile via `MovePlayer.Teleport()`

### Success Rate Modifiers (Full Mode)

| Factor | Effect |
|--------|--------|
| Fitness | +2% per level |
| Strength | +2% per level |
| Endurance moodle | -10% per level |
| Heavy load moodle | -16% per level |
| Emaciated / Obese / Very Underweight | -25% |
| Underweight / Overweight | -15% |
| Being attacked | -25% |
| Nearby zombies | -7% per zombie |
| Critical success | 1% chance (always succeeds) |

## Project Structure

```
Climbable Boxes B42/
├── mod.info                        # Root mod descriptor
├── poster.png                      # Workshop poster
├── preview.png                     # Workshop preview image
├── workshop.txt                    # Workshop metadata
└── Contents/mods/ClimbableBoxes/
    ├── common/
    │   ├── mod.info                # Shared mod descriptor
    │   ├── icon.png
    │   └── poster.png
    ├── 42.13/                      # Primary build — all code lives here
    │   └── media/
    │       ├── sandbox-options.txt
    │       ├── AnimSets/player/actions/
    │       │   ├── ClimbBoxStart.xml
    │       │   ├── ClimbBoxSuccess.xml
    │       │   ├── ClimbBoxStruggle.xml
    │       │   ├── ClimbBoxFail.xml
    │       │   └── ClimbBoxEnd.xml
    │       └── lua/
    │           ├── client/
    │           │   ├── ClimbBox.lua             # Main logic: box detection, target finding, input loop
    │           │   ├── ClimbBoxConfig.lua        # Keybind registration (default G)
    │           │   ├── ClimbBoxContextMenu.lua   # Right-click context menu
    │           │   └── ClimbBoxHealth.lua        # Injury checks (upper body + legs)
    │           └── shared/
    │               ├── Actions/
    │               │   └── ISClimbBox.lua        # Timed action, animation state machine, MP sync
    │               └── Translate/EN/
    │                   └── UI_EN.txt             # English localization
    └── 42/                         # Build 42 compatibility stub
        └── media/
            └── sandbox-options.txt
```

### Key Files

| File | Purpose |
|------|---------|
| `ClimbBox.lua` | Core module. Handles box detection (`isClimbableBox`), target square finding (`findClimbTarget`), direction handling, and the `OnPlayerUpdate` input loop. |
| `ISClimbBox.lua` | ISBaseTimedAction subclass. Manages the animation state machine (start → outcome → ending → complete), success rate computation, teleportation, and endurance consumption. Uses a tick-based timer with `animEvent()` as backup. |
| `ClimbBoxConfig.lua` | Registers the keybind via PZAPI ModOptions (with fallback to raw `isKeyDown` if PZAPI is unavailable). |
| `ClimbBoxContextMenu.lua` | Adds "Climb onto box" to the right-click context menu when a climbable box is detected. |
| `ClimbBoxHealth.lua` | Checks upper body parts (hands, forearms, upper arms, torso) and leg parts for fractures, deep wounds, low health, and stiffness. |

### Animation State Machine

```
[IDLE] → (G key / context menu)
    → ClimbBoxStart (0.80x speed)
        tick 45: compute outcome + switch animation
        ┌────────┬────────────┐
        ↓        ↓            ↓
    SUCCESS   STRUGGLE      FAIL
    (0.80x)   (1.00x)     (0.80x)
        ↓        ↓            ↓
        └────┬───┴────────────┘
             ↓
       tick +40: teleport (if not fail)
             ↓
       ClimbBoxEnd (0.80x)
             ↓
       tick +30: forceComplete()
```

## Box Detection

The mod identifies climbable objects using a priority-based check:

1. **Property check**: Object must have `IsMoveAble` flag
2. **Container type**: Check `ContainerType` property for `crate`, `smallbox`, `cardboardbox`
3. **Sprite fallback**: Match `carpentry_01_16` through `carpentry_01_19` sprite names
4. **Name fallback**: Check object name for "box" or "crate" keywords

This approach works with modded boxes that follow standard PZ property conventions.

## Development

### Running Tests

The project includes a comprehensive test suite using [Busted](https://lunarmodules.github.io/busted/) (Lua 5.1). Tests mock all PZ API classes and globals.

```bash
# Run all tests
./tests/run_tests.sh all

# Run only unit tests
./tests/run_tests.sh unit

# Run only integration tests
./tests/run_tests.sh integration

# Run only structural tests
./tests/run_tests.sh structural
```

**Test categories:**

- **Unit tests** (`tests/unit/`) — Test individual functions in isolation: box detection, direction handling, success rate computation, endurance, teleportation, keybind, health checks, context menu, action constructor, state machine update
- **Integration tests** (`tests/integration/`) — Test multi-component flows: keybind-to-action pipeline, context menu flow, health blocking, state machine progression, MP sync
- **Structural tests** (`tests/structural/`) — Validate project integrity: file structure, XML animation format, sandbox option definitions, localization completeness, config consistency

### Dependencies

- [Lua 5.1](https://www.lua.org/versions.html#5.1) — Required for PZ mod compatibility
- [Busted 2.3.0](https://lunarmodules.github.io/busted/) — Test framework (install via LuaRocks for Lua 5.1)

### B42.13 API Notes

Build 42.13 changed several APIs from earlier versions. Key patterns used in this mod:

| Feature | B42.13 API |
|---------|------------|
| Action constructor | `ISBaseTimedAction.new(self, character)` |
| Traits | `character:hasTrait(CharacterTrait.EMACIATED)` |
| Moodles | `MoodleType.ENDURANCE` (uppercase enum) |
| Stats | `stats:remove(CharacterStat.ENDURANCE, amount)` |
| Square flags | `square:has(IsoFlagType.X)` |
| Sprite properties | `props:has("IsMoveAble")`, `props:get("ContainerType")` |
| Player direction | `character:getDir()` returns `IsoDirections` enum (N/NE/E/SE/S/SW/W/NW) |

### Adding New Container Types

Edit `ClimbBox.isClimbableBox()` in `ClimbBox.lua` and add to the `validTypes` table.

### Adding Localization

Create a new `UI_XX.txt` file in `lua/shared/Translate/XX/` following the same format as `UI_EN.txt`.

## Compatibility

- Works with modded boxes/crates that use standard PZ `IsMoveAble` and `ContainerType` properties
- Requires TchernoLib for player teleportation
- Compatible with multiplayer (server-authoritative endurance sync)

## License

Feel free to use this as a reference or base for your own PZ mods.
