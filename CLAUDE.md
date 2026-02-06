# CLAUDE.md - Climbable Boxes Mod

## Project Overview

A Project Zomboid Build 42.13 mod that lets players climb onto boxes and crates. Players can climb via keybind (default: G) or right-click context menu. The player is teleported to Z+1 above the box, with a solid floor flag set on the target square so they can stand on top. Full multiplayer support. Depends on TchernoLib.

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
- **Target**: Adjacent square at Z+1 (on top of the box). Uses `setSolidFloor(true)` on the Z+1 square before teleporting so the player has a walkable surface
- **Key input**: Edge detection (rising-edge only) prevents key-held spam — `wasKeyDown` flag tracks state
- **Animation state machine**: Timer-based (tick counter with `maxTime=-1`), `animEvent()` as backup. States: start(45t) -> outcome(+40t) -> ending(+30t) -> complete
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
| Player direction | `character:getDir()` returns IsoDirections (N/NE/E/SE/S/SW/W/NW) |
| Animation events | XML `<name>` must match Lua event handler checks |
| Grid square floors | `square:addFloor(spriteName)`, `square:setSolidFloor(bool)`, `square:TreatAsSolidFloor()` |
| Key input | `isKeyDown(key)` returns true every frame while held — use edge detection |

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

### Direction Detection Fix V2 - API Method Discovery (2026-02-05)

**Problem:** "Object tried to call nil in findClimbTarget" - `getAnimSetName()` **doesn't exist in the B42.13 API**, causing crashes.

**Root Cause:**
- Climb mod documentation references `character:getAnimSetName()` but this method doesn't exist!
- The documentation was incorrect or refers to a different PZ version
- We need a different approach to get player facing direction

**Solution:** Use `getDir()` and handle ALL 8 directions including diagonals:

```lua
-- CORRECT - getDir() returns IsoDirections enum (works in B42.13)
local dir = isoPlayer:getDir()
if not dir then return nil, nil end

local deltaX = 0
local deltaY = 0

-- Handle all 8 directions: N, NE, E, SE, S, SW, W, NW
if dir == IsoDirections.N then
    deltaX = 0
    deltaY = -1
elseif dir == IsoDirections.NE then
    -- Convert diagonal to cardinal (favor horizontal)
    deltaX = 1
    deltaY = 0
elseif dir == IsoDirections.E then
    deltaX = 1
    deltaY = 0
-- ... (continue for all 8 directions)
```

**Diagonal Conversion Strategy:**
- NE → E (favor horizontal movement)
- SE → E
- SW → W
- NW → W

**Why This Works:**
- `getDir()` is a real API method that exists and works
- Handles all possible direction values (no unhandled cases)
- Simple, deterministic conversion from diagonals to cardinals
- No trigonometry needed - direct enum mapping

**Critical Lesson:** Always verify API methods exist in the actual game version - documentation can be wrong or outdated!

### Animation Event System Fix (2026-02-05)

**Problem:** Animation stuck looping indefinitely, receiving `ActiveAnimLooped` events instead of progressing through the state machine.

**Root Cause:** Animation XML files used incorrect event names:
- XML had: `<name>LuaNet.Event</name>`
- Lua checked for: `event == "ClimbBoxStart"`
- Events never matched, so state machine never progressed

**Solution:** Changed all animation XML `<m_CustomEvents><name>` tags to match the animation names themselves:
```xml
<m_CustomEvents>
    <name>ClimbBoxStart</name>  <!-- Was: LuaNet.Event -->
    <time>0.30</time>
    <parameterValue>30</parameterValue>
</m_CustomEvents>
```

**Critical Pattern:** The event name in XML must exactly match what the Lua `animEvent()` handler checks for. For PZ B42.13, use the animation name itself as the event name.

**Animation Event Flow:**
1. ClimbBoxStart plays → fires events "ClimbBoxStart" at 30% and 90%
2. At 90%: compute outcome, consume endurance, transition to next anim
3. Success/Struggle/Fail animations play → fire completion events with their own names
4. Transition to ClimbBoxEnd → fires completion event "ClimbBoxEnd"
5. End animation completes → `forceComplete()` action

**All Fixed XMLs:**
- ClimbBoxStart.xml: events "ClimbBoxStart" at 30% and 90%
- ClimbBoxSuccess.xml: event "ClimbBoxSuccess" at 95%
- ClimbBoxStruggle.xml: event "ClimbBoxStruggle" at 95%
- ClimbBoxFail.xml: event "ClimbBoxFail" at 95%
- ClimbBoxEnd.xml: event "ClimbBoxEnd" at 95%

### Teleport Z-Level Fix (2026-02-06)

**Problem:** Player teleported "inside" the box (same Z-level), then with Z+1 fix the player briefly appeared above but fell back down through the empty square.

**Root Cause:** PZ Z-levels are full floors. Z+1 above an outdoor box has no floor surface, so the player falls back to Z=0. The Climb mod's Z+1 works because walls connect actual building floors.

**Solution:** Before teleporting, set `setSolidFloor(true)` on the Z+1 grid square:

```lua
local squareAbove = cell:getGridSquare(x, y, z + 1)
if squareAbove and not squareAbove:TreatAsSolidFloor() then
    squareAbove:setSolidFloor(true)
end
```

**Key IsoGridSquare Floor APIs:**
- `addFloor(spriteName)` — Creates a visible floor object (returns IsoObject)
- `setSolidFloor(bool)` — Sets walkable flag without adding visible geometry
- `TreatAsSolidFloor()` — Checks if square is considered walkable
- `isSolidFloor()` / `setSolidFloorCached(bool)` — Cached solid floor state

**Known limitation:** The solid floor flag persists after player leaves. Cleanup logic needed.

### Key Spam Fix (2026-02-06)

**Problem:** `isKeyDown()` returns true every frame while the key is held, causing the climb action to trigger repeatedly every tick (~13ms).

**Solution:** Added rising-edge detection in `ClimbBoxConfig.lua`:
- `wasKeyDown` boolean tracks previous frame's key state
- `getKey()` only returns true on the transition from not-pressed to pressed
- While key is held, subsequent frames return false

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
