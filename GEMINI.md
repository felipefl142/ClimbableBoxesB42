# GEMINI.md - Climbable Boxes Mod (Gemini Agent Guide)

This guide provides project-specific context, technical patterns, and commands for developing the Climbable Boxes mod for Project Zomboid Build 42.13.

## Project Overview

- **Mod Name:** Climbable Boxes
- **Version:** B42.13 Compatible
- **Core Mechanic:** Players can climb on top of crates/boxes (Z+1) via keybind (default: G) or context menu.
- **Dependencies:** TchernoLib (essential for `MovePlayer.Teleport` and other utilities).
- **Multiplayer:** Fully supported via `sendClientCommand` / `OnClientCommand`.

## Build & Test Commands

### Running Tests
The project uses `busted` (Lua 5.1) for testing.

```bash
# Run all tests
./tests/run_tests.sh all

# Run specific categories
./tests/run_tests.sh unit
./tests/run_tests.sh integration
./tests/run_tests.sh structural
```

### Key Paths
- **Source Code:** `Climbable Boxes B42/Contents/mods/ClimbableBoxes/42.13/media/lua/`
- **Animations:** `Climbable Boxes B42/Contents/mods/ClimbableBoxes/42.13/media/AnimSets/player/actions/`
- **Tests:** `tests/` (unit, integration, structural)

## Core Architecture

### Box Detection Logic
- **Primary:** `props:has("IsMoveAble")` AND `props:get("ContainerType")` (matches "crate", "smallbox", "cardboardbox").
- **Fallback:** Sprite name patterns (e.g., `carpentry_01_16`).
- **Target Calculation:** Adjacent square in player facing direction, teleport to Z+1.

### Movement & Surface Handling
- **Solid Floor:** Before teleporting to Z+1, the target square must be made walkable using `squareAbove:setSolidFloor(true)`.
- **Teleportation:** Uses `MovePlayer.Teleport(character, x, y, z)` from TchernoLib.

### Animation State Machine
- **Duration:** Action uses `maxTime = -1` (controlled by animation events).
- **Flow:** `Start` -> (90% event) -> `Success/Struggle/Fail` -> `End`.
- **Events:** XML events MUST match the animation name (e.g., `<name>ClimbBoxStart</name>`).

## B42.13 API Patterns (CRITICAL)

| Feature | B42.13 Implementation |
|---------|-----------------------|
| **Action Constructor** | `ISBaseTimedAction.new(self, character)` |
| **Traits** | `character:hasTrait(CharacterTrait.EMACIATED)` |
| **Moodles** | `MoodleType.ENDURANCE` (Enum) |
| **Stats** | `stats:remove(CharacterStat.ENDURANCE, amount)` |
| **Square Flags** | `square:has(IsoFlagType.X)` |
| **Player Direction** | Use `isoPlayer:getDir()` (Handles N, NE, E, SE, S, SW, W, NW) |

## Direction Handling (8-Way to 4-Way)
PZ B42.13 `getDir()` returns 8 directions. We convert diagonals to cardinals for consistent climbing:
- **NE / SE** -> **East** (deltaX=1, deltaY=0)
- **NW / SW** -> **West** (deltaX=-1, deltaY=0)
- **North** (deltaX=0, deltaY=-1)
- **South** (deltaX=0, deltaY=1)

## Lessons Learned & Fixes

### 1. The `getAnimSetName()` Myth
- **Lesson:** `character:getAnimSetName()` does NOT exist in B42.13 API despite some documentation suggesting it.
- **Fix:** Always use `getDir()` and handle the `IsoDirections` enum.

### 2. Animation Event Names
- **Lesson:** Animation XML events must exactly match the name used in `animEvent(event, parameter)`.
- **Fix:** Use the action name (e.g., "ClimbBoxStart") as the event name in XML.

### 3. Z-Level "Ghosting"
- **Lesson:** Players fall through Z+1 if there's no floor object.
- **Fix:** Use `square:setSolidFloor(true)` on the target square *before* teleporting.

### 4. Key Input Edge Detection
- **Lesson:** `isKeyDown()` triggers every frame.
- **Fix:** Use a `wasKeyDown` flag to detect the "rising edge" (first press only) to prevent action spam.

## Testing Guidelines

- **Mocks:** Use `tests/mocks/pz_globals.lua` to simulate the PZ environment.
- **New Features:** Every new logic change should have a corresponding unit test in `tests/unit/`.
- **Multiplayer:** Test sync logic in `tests/integration/test_mp_sync.lua`.
