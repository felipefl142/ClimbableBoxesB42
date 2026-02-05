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

## Critical Bug Fixes & Lessons Learned

### Direction Detection Fix (2026-02-05)

**Problem:** Player direction detection was completely broken, causing the mod to check the player's own square instead of adjacent squares.

**Root Cause:**
- Used `isoPlayer:getDir()` which returns diagonal directions (NE, NW, SE, SW)
- Code only handled cardinal directions (N, S, E, W)
- Diagonal directions fell through with deltaX=0, deltaY=0
- Logs showed: `Player direction: NE -> deltaX=0, deltaY=0`

**Solution:** Use `getAnimSetName()` API instead (returns angle values):

```lua
-- WRONG - getDir() returns IsoDirections enum including diagonals
local dir = isoPlayer:getDir()
if dir == IsoDirections.N then ... end  -- Fails for NE, NW, SE, SW

-- CORRECT - getAnimSetName() returns precise angle values
local angle = isoPlayer:getAnimSetName()
if angle == 0 then       -- East
    deltaX = 1
    deltaY = 0
elseif angle == 90 then  -- South
    deltaX = 0
    deltaY = 1
elseif angle == -90 then -- North
    deltaX = 0
    deltaY = -1
elseif angle == 180 then -- West
    deltaX = -1
    deltaY = 0
end
```

**Critical Angle Mappings** (from Climb mod documentation):
- `0°` = **East** (NOT North!)
- `90°` = **South** (NOT East!)
- `-90°` = **North** (NOT West!)
- `180°` = **West** (NOT South!)

### Animation Event System Debugging

**Added comprehensive logging to ISClimbBox.lua:**
- Logs every `animEvent(event, parameter)` call
- Logs state transitions (success/struggle/fail outcomes)
- Logs teleport and completion events
- Added handler for 30% event in ClimbBoxStart animation

**Animation Event Flow:**
1. ClimbBoxStart plays → fires events at 30% and 90%
2. At 90%: compute outcome, consume endurance, transition to next anim
3. Success/Struggle/Fail animations play → fire completion events
4. Transition to ClimbBoxEnd → fires completion event
5. End animation completes → `forceComplete()` action

**Debugging Pattern:**
```lua
function ISClimbBox:animEvent(event, parameter)
    print("[ISClimbBox] animEvent called: event=" .. tostring(event) .. ", parameter=" .. tostring(parameter))
    -- Check event/parameter combinations
    if event == self.startAnim and parameter == "90" then
        -- State machine logic here
    end
end
```

### Box Detection via Context Menu vs Keybind

**Observation:** Context menu successfully detected boxes using sprite name fallback (`carpentry_01_16`), but keybind detection failed due to direction bug.

**Box Detection Priority:**
1. **Primary:** Check `ContainerType` property (crate, smallbox, cardboardbox)
2. **Fallback:** Check sprite name patterns (carpentry_01_16-19)
3. **Fallback:** Check object name for "box"/"crate" keywords

**Key Properties:**
- `props:has("IsMoveAble")` — Must be true for all climbable boxes
- `props:get("ContainerType")` — Returns string like "crate" (may be nil)
- Sprite name pattern matching catches carpentry crates without ContainerType

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
