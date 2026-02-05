# Project Zomboid "Climb" Mod - Technical Documentation

**Version:** Build 42.13 Compatible
**Purpose:** Parkour-style wall climbing mechanic for Project Zomboid
**Dependencies:** TchernoLib (Project Zomboid API Library)
**Date Analyzed:** 2026-02-04

---

## Table of Contents

1. [Overview](#overview)
2. [Project Structure](#project-structure)
3. [Core Systems](#core-systems)
4. [Implementation Details](#implementation-details)
5. [Multiplayer Architecture](#multiplayer-architecture)
6. [Code Patterns & Best Practices](#code-patterns--best-practices)
7. [API Integration Points](#api-integration-points)
8. [Quick Reference](#quick-reference)

---

## Overview

### What This Mod Does

The Climb mod adds parkour-style wall climbing to Project Zomboid, allowing players to scale walls from ground level to elevated surfaces (one floor up) using a keybind (default: F key).

**Key Features:**
- Dynamic success/failure system based on character stats
- Health validation (injured limbs prevent climbing)
- Endurance consumption mechanics
- Struggle/retry system
- Full multiplayer support with server/client synchronization
- Configurable keybinding via PZAPI ModOptions

### Mod Metadata

```
ID: ClimbWall
Name: ClimbWall
Description: Climb walls like parkour
Required Dependency: TchernoLib
```

---

## Project Structure

### Directory Layout

```
Climb/
├── common/                          # Cross-version shared files
│   ├── ClimbIcon.png               # UI icon (64x64)
│   ├── preview.png                 # Steam Workshop preview
│   ├── mod.info                    # Mod metadata
│   ├── media/
│   │   ├── AnimSets/player/actions/  # Animation XML definitions (5 files)
│   │   └── lua/
│   │       ├── client/
│   │       │   ├── ClimbConfig.lua      # Keybind configuration
│   │       │   ├── ClimbHealth.lua      # Health validation system
│   │       │   ├── ClimbWall.lua        # Main game logic & input loop
│   │       │   └── Actions/
│   │       │       └── ISClimbWall.lua  # Single-player action class
│   │       └── shared/Translate/EN/
│   │           └── UI_EN.txt           # Localization strings
│
├── 42/                             # Build 42 specific assets
│   ├── ClimbIcon.png
│   └── preview.png
│
└── 42.13/                          # Build 42.13+ version files
    └── media/lua/
        ├── client/Actions/
        │   └── ISClimbWall.lua         # [OBSOLETE - see shared version]
        └── shared/Actions/
            └── ISClimbWallMP.lua       # Multiplayer-enhanced action class
```

### Version Management Strategy

- **Common folder:** Base implementation for all versions
- **Version-specific folders:** Override common files for specific PZ builds
- **Active files in B42.13:**
  - `common/media/lua/client/ClimbWall.lua` (main logic)
  - `common/media/lua/client/ClimbConfig.lua` (config)
  - `common/media/lua/client/ClimbHealth.lua` (health checks)
  - `42.13/media/lua/shared/Actions/ISClimbWallMP.lua` (multiplayer action)

---

## Core Systems

### 1. Input Detection System

**File:** `ClimbWall.lua`
**Event Hook:** `Events.OnPlayerUpdate`

The main game loop that detects climb attempts:

```lua
function Climb.OnPlayerUpdate(isoPlayer)
    -- Preconditions check
    if not isKeyPressed(Climb.getKey()) then return end
    if isoPlayer:hasTimedActions() then return end
    if square:HasStairs() then return end
    if Climb.isHealthInhibitingClimb(isoPlayer) then return end

    -- Target calculation
    local targetSquare = Climb.getPlayerTarget(isoPlayer)

    -- Wall validation
    if Climb.isClimbableWallInBounds(square, targetSquare) then
        ISTimedActionQueue.add(ISClimbWall:new(isoPlayer))
    end
end
```

**Key Design Pattern:** Event-driven update loop with early-exit validation chains

---

### 2. Target Detection System

**Function:** `Climb.getPlayerTarget(isoPlayer)`

Calculates the position ahead of the player based on facing direction:

```lua
-- Convert character angle to direction delta
local angle = character:getAnimSetName()  -- 0, 90, -90, 180 (degrees)
local deltaX = math.cos(math.rad(angle))  -- Convert to radians, get X component
local deltaY = math.sin(math.rad(angle))  -- Convert to radians, get Y component

-- Normalize to cardinal directions only (no diagonals)
deltaX = Climb.normalizeByDirection(deltaX)
deltaY = Climb.normalizeByDirection(deltaY)

-- Target is 0.5 units ahead at Z+1 (next floor)
return getGridSquare(playerX + deltaX * 0.5, playerY + deltaY * 0.5, playerZ + 1)
```

**Cardinal Directions Mapping:**
- 0° (East): deltaX = +1, deltaY = 0
- 90° (South): deltaX = 0, deltaY = +1
- -90° (North): deltaX = 0, deltaY = -1
- 180° (West): deltaX = -1, deltaY = 0

**Important Note:** Diagonal climbing not supported to reduce validation complexity

---

### 3. Wall Validation System

**Function:** `Climb.isClimbableWallInBounds(playerSquare, targetSquare)`

Multi-stage validation process:

#### Stage 1: Basic Square Checks
```lua
-- Target must be solid floor
if not targetSquare:TreatAsSolidFloor() then return false end

-- Target must be empty (no objects blocking)
if targetSquare:isSolidTrans() or targetSquare:isVehicleIntersecting() then
    return false
end

-- Must be different squares
if playerSquare:getX() == targetSquare:getX() and
   playerSquare:getY() == targetSquare:getY() then
    return false
end

-- Must be adjacent (not same X or same Y, but not both different)
local diffX = playerSquare:getX() ~= targetSquare:getX()
local diffY = playerSquare:getY() ~= targetSquare:getY()
if (diffX and diffY) or (not diffX and not diffY) then
    return false  -- Diagonal or same position
end
```

#### Stage 2: Vertical Space Check
```lua
-- Square above player must be walkable
local upSquare = getGridSquare(playerSquare:getX(), playerSquare:getY(), playerSquare:getZ() + 1)
if not upSquare or upSquare:isSolidTrans() then return false end
```

#### Stage 3: Direction-Specific Wall Checks

**East/West Movement:**
```lua
if diffX then  -- Moving in X direction
    if targetSquare:getX() > playerSquare:getX() then
        -- Moving East: check target isn't blocked on west side
        if Climb.isBlockedOnWestSide(targetSquare) then return false end
    else
        -- Moving West: check square ABOVE player isn't blocked on west side
        if Climb.isBlockedOnWestSide(upSquare) then return false end
    end
end
```

**North/South Movement:**
```lua
if diffY then  -- Moving in Y direction
    if targetSquare:getY() > playerSquare:getY() then
        -- Moving South: check target isn't blocked on north side
        if Climb.isBlockedOnNorthSide(targetSquare) then return false end
    else
        -- Moving North: check square ABOVE player isn't blocked on north side
        if Climb.isBlockedOnNorthSide(upSquare) then return false end
    end
end
```

#### Block Detection Logic

**Version-specific implementations:**

```lua
-- Common version (Build 42 base)
function Climb.isBlockedOnWestSide(square)
    return square:Is(IsoFlagType.collideW) or
           square:Is(IsoFlagType.WindowW) or
           square:Is(IsoFlagType.doorW) or
           square:Is(IsoFlagType.HoppableW)
end

-- Build 42.13+ version
function Climb.isBlockedOnWestSide(square)
    return square:has(IsoFlagType.collideW) or
           square:has(IsoFlagType.WindowW) or
           square:has(IsoFlagType.doorW) or
           square:has(IsoFlagType.HoppableW)
end
```

**API Change Note:** `Is()` replaced with `has()` in Build 42.13

---

### 4. Health Validation System

**File:** `ClimbHealth.lua`
**Function:** `Climb.isHealthInhibitingClimb(isoPlayer)`

Prevents climbing if upper body parts are injured:

```lua
-- Body parts checked
local bodyParts = {
    BodyPartType.Hand_L,
    BodyPartType.Hand_R,
    BodyPartType.ForeArm_L,
    BodyPartType.ForeArm_R,
    BodyPartType.UpperArm_L,
    BodyPartType.UpperArm_R,
    BodyPartType.Torso_Upper,
    BodyPartType.Torso_Lower
}

-- Blocking conditions (ANY triggers rejection)
for each bodyPart:
    if bodyPart:getFractureTime() > 0.0 then return true end      -- Fracture
    if bodyPart:isDeepWounded() then return true end               -- Deep wound
    if bodyPart:getHealth() < 50.0 then return true end            -- Health < 50%
    if bodyPart:getStiffness() >= 50.0 then return true end        -- Stiffness >= 50%
```

**Design Philosophy:** Realistic injury simulation - can't climb with broken/wounded arms

---

### 5. Success Rate Calculation

**Function:** `ISClimbWall:computeSuccessRate()`

Dynamic probability system based on character state:

```lua
local successProba = 80  -- Base 80% success rate

-- Positive modifiers
successProba = successProba + (character:getPerkLevel(Perks.Fitness) * 2)   -- +0 to +20
successProba = successProba + (character:getPerkLevel(Perks.Strength) * 2)  -- +0 to +20

-- Negative modifiers - Moodles (Build 42.13 uses enums)
local enduranceMoodle = character:getMoodles():getMoodleLevel(MoodleType.ENDURANCE)
local heavyLoadMoodle = character:getMoodles():getMoodleLevel(MoodleType.HEAVY_LOAD)
successProba = successProba - (enduranceMoodle * 10)   -- -0 to -40 (fatigue)
successProba = successProba - (heavyLoadMoodle * 16)   -- -0 to -64 (encumbrance)

-- Negative modifiers - Traits
if character:hasTrait(CharacterTrait.EMACIATED) or
   character:hasTrait(CharacterTrait.OBESE) or
   character:hasTrait(CharacterTrait.VERY_UNDERWEIGHT) then
    successProba = successProba - 25
end

if character:hasTrait(CharacterTrait.UNDERWEIGHT) or
   character:hasTrait(CharacterTrait.OVERWEIGHT) then
    successProba = successProba - 15
end

-- Combat modifiers
if character:getAttackedBy() then
    successProba = successProba - 25  -- Being attacked
end
local nearbyZombies = character:getTargetSeenCount()
successProba = successProba - (nearbyZombies * 7)  -- -7 per zombie
```

**Outcome Determination:**
```lua
local rand = ZombRand(0, 101)  -- Random 0-100

-- Special case: rand == 1 is critical success (always succeeds)
if rand == 1 then
    self.isFail = false
    self.isStruggle = false
    return
end

-- Struggle: rand between (successProba - 25) and successProba
self.isStruggle = (rand > (successProba - 25))

-- Fail: rand > successProba
self.isFail = (rand > successProba)
```

**Possible Outcomes:**
- **Critical Success (1% chance):** Always succeeds, no struggle
- **Success:** Instant teleport to target
- **Struggle:** Player struggles, consumes extra endurance, retries
- **Fail:** Player falls

---

### 6. Endurance System

**Function:** `ISClimbWall:consumeEndurance()`

Endurance cost based on action outcome:

```lua
local tractionDone = ZomboidGlobals.RunningEnduranceReduce * 1200.0
-- Base cost equivalent to running 1200 distance units

if self.isStruggle then
    tractionDone = tractionDone + (ZomboidGlobals.RunningEnduranceReduce * 500.0)
    -- Additional cost for struggling (500 units equivalent)
end

-- Apply endurance reduction (Build 42.13 API)
character:getStats():remove(CharacterStat.ENDURANCE, tractionDone)
```

**Build Version Differences:**

```lua
-- Common version (Build 42 base)
stats:setEndurance(stats:getEndurance() - tractionDone)

-- Build 42.13+ version
stats:remove(CharacterStat.ENDURANCE, tractionDone)
```

**Timing:** Endurance consumed at 90% of start animation (when success is determined)

---

### 7. Animation System

**Animation State Machine:**

```
[IDLE]
  → (F key pressed)
    → ClimbWallStart (0.80x speed)
        @ 30%: animEvent("ClimbWallStart", "30")
        @ 90%: animEvent("ClimbWallStart", "90") → [COMPUTE SUCCESS]
            ↓
        ┌───┴───┬───────────┐
        ↓       ↓           ↓
    SUCCESS  STRUGGLE     FAIL
        ↓       ↓           ↓
ClimbWallSuccess  ClimbWallStruggle  ClimbWallFail
 (0.80x, no loop)  (1.00x, LOOP)    (0.80x, no loop)
        ↓       ↓           ↓
        └───┬───┴───────────┘
            ↓
      ClimbWallEnd
        (0.80x)
            ↓
        [COMPLETE]
```

**Animation Files (in `media/AnimSets/player/actions/`):**
1. `ClimbWallStart.xml` - Preparation phase with event triggers
2. `ClimbWallSuccess.xml` - Successful climb completion
3. `ClimbWallStruggle.xml` - Looping struggle animation
4. `ClimbWallFail.xml` - Fall/failure animation
5. `ClimbWallEnd.xml` - Return to idle stance

**Base Animation References:**
- Uses Bob's fence climbing animations: `Bob_ClimbFence_Start`, `Bob_ClimbFence_Success`, etc.
- Custom XML files configure speed, looping, and event triggers

**Event Handling Pattern:**
```lua
function ISClimbWall:animEvent(event, parameter)
    if event == self.startAnim and parameter == "90" then
        -- Compute success at 90% of start animation
        self:computeSuccessRate()
        self:consumeEndurance()

        -- Choose next animation based on outcome
        if self.isFail then
            self:setActionAnim(self.failAnim)
        elseif self.isStruggle then
            self:setActionAnim(self.struggleAnim)
        else
            self:setActionAnim(self.successAnim)
        end
    elseif event == self.successAnim then
        -- Teleport player on success completion
        local finalX = self.character:getX()
        local finalY = self.character:getY()
        local finalZ = self.character:getZ() + 1
        MovePlayer.Teleport(self.character, finalX, finalY, finalZ)
    end
end
```

---

## Implementation Details

### ISClimbWall Action Class Architecture

**Inheritance:** `ISClimbWall` extends `ISBaseTimedAction`

#### Common Version (Single-Player)

```lua
ISClimbWall = ISBaseTimedAction:derive("ISClimbWall")

function ISClimbWall:new(character)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.stopOnWalk = false
    o.stopOnRun = false
    o.maxTime = -1  -- Infinite duration until animation completes

    -- Animation names
    o.startAnim = "ClimbWallStart"
    o.successAnim = "ClimbWallSuccess"
    o.struggleAnim = "ClimbWallStruggle"
    o.failAnim = "ClimbWallFail"
    o.endAnim = "ClimbWallEnd"

    -- State flags
    o.isFail = false
    o.isStruggle = false

    return o
end
```

**Key Methods:**

| Method | Purpose | Return Value |
|--------|---------|--------------|
| `isValidStart()` | Validate before action starts | Always `true` |
| `isValid()` | Check if action remains valid during execution | `true` if not invalidated |
| `update()` | Called every frame during action | None |
| `start()` | Initialize action, block movement, register listeners | None |
| `stop()` | Cleanup, unblock movement, unregister listeners | None |
| `perform()` | Final completion, trigger next action in queue | None |
| `animEvent(event, param)` | Handle animation milestone callbacks | None |
| `getDuration()` | Return action duration | `-1` (infinite) |
| `complete()` | Check if action finished | `true` on completion |

**Lifecycle:**
```
new() → isValidStart() → start() → update() (loop) → animEvent() (callbacks) → stop() → perform()
                                        ↓
                                   isValid() checked each update
```

---

### Build 42.13 Multiplayer Version

**File:** `42.13/media/lua/shared/Actions/ISClimbWallMP.lua`

**Key Enhancements:**

#### 1. Server Initialization
```lua
function ISClimbWall:serverStart()
    emulateAnimEvent = true
    Events.OnClientCommand.Add(ISClimbWall.OnClientCommandCallback)
end
```

#### 2. Client → Server Communication
```lua
function ISClimbWall:consumeEndurance()
    -- Client computes locally first
    local tractionDone = ZomboidGlobals.RunningEnduranceReduce * 1200.0
    if self.isStruggle then
        tractionDone = tractionDone + (ZomboidGlobals.RunningEnduranceReduce * 500.0)
    end

    -- Send to server for authoritative application
    sendClientCommand(
        self.character,
        "ClimbWall",
        "consumeEndurance",
        {tractionDone = tractionDone, isStruggle = self.isStruggle}
    )
end
```

#### 3. Server Command Handler
```lua
function ISClimbWall.OnClientCommandCallback(module, command, player, args)
    if module ~= "ClimbWall" or command ~= "consumeEndurance" then return end

    -- Server-side validation point (anti-cheat opportunity)
    -- Check if player can legitimately climb based on:
    -- - Health conditions
    -- - Endurance levels
    -- - Position validity

    -- Apply endurance cost on server
    player:getStats():remove(CharacterStat.ENDURANCE, args.tractionDone)
end
```

#### 4. Cleanup
```lua
function ISClimbWall:stop()
    -- Unregister callback to prevent memory leaks
    Events.OnClientCommand.Remove(ISClimbWall.OnClientCommandCallback)
    ISBaseTimedAction.stop(self)
end

function ISClimbWall:perform()
    Events.OnClientCommand.Remove(ISClimbWall.OnClientCommandCallback)
    ISBaseTimedAction.perform(self)
end
```

**Synchronization Flow:**
```
[CLIENT]                           [SERVER]
  F key pressed                      (idle)
       ↓
  Start animation                    (idle)
       ↓
  90% milestone reached              (idle)
       ↓
  Compute success locally            (idle)
       ↓
  sendClientCommand() ────────────→ OnClientCommand event
       ↓                                  ↓
  Visual animation continues        Validate request
       ↓                                  ↓
  (waiting for server)              Apply endurance cost
       ↓                                  ↓
  Animation completes               Stats synchronized
       ↓                                  ↓
  Teleport locally                  Position synchronized
```

**Anti-Cheat Notes (from code comments):**
```lua
-- TODO: check for cheater client here for available action conditions
-- like endurance / health
```

Suggested server-side validations:
- Re-run `isHealthInhibitingClimb()` on server
- Verify endurance sufficient for climb
- Validate wall exists at claimed position
- Check distance between player and target wall

---

### API Version Changes (Build 42 → 42.13)

#### Trait System
```lua
-- Build 42 (common)
local traits = character:getTraits()
if traits:contains("Emaciated") then

-- Build 42.13
if character:hasTrait(CharacterTrait.EMACIATED) then
```

#### Moodle System
```lua
-- Build 42 (common)
MoodleType.Endurance
MoodleType.HeavyLoad

-- Build 42.13
MoodleType.ENDURANCE  -- Enum constant
MoodleType.HEAVY_LOAD -- Enum constant
```

#### Stats System
```lua
-- Build 42 (common)
stats:setEndurance(stats:getEndurance() - amount)

-- Build 42.13
stats:remove(CharacterStat.ENDURANCE, amount)
```

#### Grid Square Flags
```lua
-- Build 42 (common)
square:Is(IsoFlagType.collideW)

-- Build 42.13
square:has(IsoFlagType.collideW)
```

#### Base Class Constructor
```lua
-- Build 42 (common)
local o = {}
setmetatable(o, self)
self.__index = self
o.character = character
-- ... set properties

-- Build 42.13
local o = ISBaseTimedAction.new(self, character)
-- ... set properties
return o
```

---

## Multiplayer Architecture

### Network Synchronization Strategy

**Philosophy:** Client-authoritative for visual feedback, server-authoritative for game state

**Client Responsibilities:**
1. Detect input (F key press)
2. Validate climb conditions locally
3. Start animation immediately (responsive feel)
4. Compute success/struggle/fail outcome
5. Send endurance cost to server
6. Apply visual teleport

**Server Responsibilities:**
1. Listen for `consumeEndurance` commands
2. Validate player eligibility (anti-cheat)
3. Apply authoritative endurance reduction
4. Synchronize stats to all clients

**Why This Design?**
- Instant client feedback (no network lag for starting animation)
- Server prevents cheating (stats modification)
- One-way communication reduces network overhead
- Animation events don't need server synchronization

**Alternative Approaches (not used):**
- ❌ Server-authoritative: High latency, poor UX
- ❌ Peer-to-peer: Security vulnerabilities
- ✅ Hybrid (chosen): Balance responsiveness & security

---

### OnClientCommand Pattern

**Setup:**
```lua
-- In serverStart()
Events.OnClientCommand.Add(ISClimbWall.OnClientCommandCallback)

-- In stop()/perform()
Events.OnClientCommand.Remove(ISClimbWall.OnClientCommandCallback)
```

**Sending Commands:**
```lua
sendClientCommand(player, module, command, args)
-- player: IsoPlayer object
-- module: "ClimbWall" (namespace)
-- command: "consumeEndurance" (action)
-- args: {tractionDone = number, isStruggle = boolean}
```

**Receiving Commands:**
```lua
function ISClimbWall.OnClientCommandCallback(module, command, player, args)
    if module ~= "ClimbWall" then return end
    if command ~= "consumeEndurance" then return end

    -- Process args.tractionDone, args.isStruggle
    player:getStats():remove(CharacterStat.ENDURANCE, args.tractionDone)
end
```

**Important:** Always unregister callbacks in `stop()` and `perform()` to prevent memory leaks and duplicate executions

---

## Code Patterns & Best Practices

### 1. Event-Driven Architecture

**Pattern:** Register callbacks to game events for automatic execution

```lua
-- Registration (in module initialization)
Events.OnPlayerUpdate.Add(Climb.OnPlayerUpdate)
Events.OnTick.Add(releaseBlockMovement)
Events.OnClientCommand.Add(ISClimbWall.OnClientCommandCallback)  -- MP only

-- Deregistration (in cleanup)
Events.OnClientCommand.Remove(ISClimbWall.OnClientCommandCallback)
```

**Benefits:**
- Decoupled from game loop
- Automatic lifecycle management
- Easy to add/remove features

**Use Cases:**
- `OnPlayerUpdate`: Continuous input detection
- `OnTick`: Deferred operations (movement unblocking)
- `OnClientCommand`: Network message handling (MP)

---

### 2. Early-Exit Validation Chains

**Pattern:** Sequential checks with early returns to minimize computation

```lua
function Climb.OnPlayerUpdate(isoPlayer)
    -- Cheapest checks first
    if not isKeyPressed(Climb.getKey()) then return end
    if isoPlayer:hasTimedActions() then return end

    -- More expensive checks later
    local square = isoPlayer:getSquare()
    if not square or square:HasStairs() then return end

    if Climb.isHealthInhibitingClimb(isoPlayer) then return end

    -- Most expensive validation last
    local targetSquare = Climb.getPlayerTarget(isoPlayer)
    if Climb.isClimbableWallInBounds(square, targetSquare) then
        -- Only execute if all checks pass
        ISTimedActionQueue.add(ISClimbWall:new(isoPlayer))
    end
end
```

**Performance Benefit:** Avoid expensive operations when preconditions fail

---

### 3. Animation-Driven State Machines

**Pattern:** Use animation milestones to trigger game logic

```lua
function ISClimbWall:animEvent(event, parameter)
    if event == "ClimbWallStart" and parameter == "90" then
        -- Animation 90% complete → trigger success computation
        self:computeSuccessRate()
        self:consumeEndurance()

        -- Transition to next state based on outcome
        if self.isFail then
            self:setActionAnim("ClimbWallFail")
        elseif self.isStruggle then
            self:setActionAnim("ClimbWallStruggle")
        else
            self:setActionAnim("ClimbWallSuccess")
        end
    elseif event == "ClimbWallSuccess" then
        -- Success animation done → teleport player
        MovePlayer.Teleport(character, finalX, finalY, finalZ)
    end
end
```

**Benefits:**
- Perfect synchronization between visuals and logic
- No manual timing required
- Easy to add new states

---

### 4. Teleportation Over Pathfinding

**Pattern:** Use instant teleportation for precise positioning

```lua
-- On success animation completion
MovePlayer.Teleport(character, finalX, finalY, finalZ)
```

**Why Not Pathfinding?**
- Pathfinding can fail (obstacles, nav mesh issues)
- Animation-based movement can desync in multiplayer
- Teleport guarantees correct final position
- Matches game's built-in "ClimbOverWall" behavior

**When to Use:**
- Vertical movement (climbing, jumping)
- Multiplayer actions (prevent desync)
- Guaranteed outcomes (success states)

---

### 5. Direction-Based Spatial Logic

**Pattern:** Convert character angle to cardinal directions

```lua
-- Get character facing angle (0, 90, -90, 180)
local angle = character:getAnimSetName()

-- Convert to unit vector
local deltaX = math.cos(math.rad(angle))
local deltaY = math.sin(math.rad(angle))

-- Normalize to cardinal directions (eliminate floating point errors)
deltaX = Climb.normalizeByDirection(deltaX)  -- -1, 0, or 1
deltaY = Climb.normalizeByDirection(deltaY)  -- -1, 0, or 1

-- Apply to position calculations
local targetX = playerX + (deltaX * distance)
local targetY = playerY + (deltaY * distance)
```

**Normalization Function:**
```lua
function Climb.normalizeByDirection(value)
    if value > 0 then return 1 end
    if value < 0 then return -1 end
    return 0
end
```

**Use Cases:**
- Target position calculation
- Wall side detection
- Collision checking by direction

---

### 6. Defensive Nil Checking

**Pattern:** Always validate object existence before use

```lua
-- Square validation
local square = player:getSquare()
if not square then return end

-- Target square validation
local targetSquare = getGridSquare(x, y, z)
if not targetSquare then return false end

-- Body part validation
local bodyDamage = player:getBodyDamage()
if not bodyDamage then return false end
```

**Critical in:**
- Grid square lookups (may return nil)
- Player state access (disconnected clients in MP)
- Body part iteration (injury system)

---

### 7. Flag-Based Collision Detection

**Pattern:** Use ISO flags for efficient spatial queries

```lua
function Climb.isBlockedOnWestSide(square)
    return square:has(IsoFlagType.collideW) or    -- Solid wall
           square:has(IsoFlagType.WindowW) or     -- Window obstacle
           square:has(IsoFlagType.doorW) or       -- Door obstacle
           square:has(IsoFlagType.HoppableW)      -- Fence/low wall
end
```

**Available Flag Types:**
- `collideW/N` - Solid collision on West/North side
- `WindowW/N` - Window on West/North side
- `doorW/N` - Door on West/North side
- `HoppableW/N` - Hoppable object (fence) on West/North side

**Why Not Raycast?**
- Flags are pre-computed (instant lookup)
- More reliable than object queries
- Consistent with game's built-in systems

---

### 8. Modular Configuration System

**Pattern:** Separate configuration from game logic

```lua
-- ClimbConfig.lua (configuration module)
if ModOptions and ModOptions.getInstance then
    local options = ModOptions:getInstance(require "ClimbWall")
    Climb.keyBind = options:addKeyBind("0", getText("UI_optionscreen_binding_Climb_Key"), Keyboard.KEY_F)
end

function Climb.getKey()
    if Climb.keyBind then
        return Climb.keyBind:isPressed()
    end
    return false
end

-- ClimbWall.lua (game logic module)
if isKeyPressed(Climb.getKey()) then  -- Uses accessor, not direct reference
    -- Climb logic
end
```

**Benefits:**
- Easy to add new keybinds
- Centralized configuration
- Users can customize without code changes
- Integration with PZAPI ModOptions

---

### 9. Verbose Logging Pattern

**Pattern:** Optional debug logging for development

```lua
-- Global debug flag
Climb.Verbose = false

-- Usage in code
if Climb.Verbose then
    print("Climb: Checking target at " .. tostring(targetX) .. ", " .. tostring(targetY))
end
```

**Best Practice:** Always use conditional logging (don't spam console in production)

---

## API Integration Points

### Project Zomboid Core APIs Used

#### 1. IsoPlayer
```lua
player:getSquare()              -- Current grid square
player:hasTimedActions()        -- Check action queue
player:getX(), :getY(), :getZ() -- Position
player:getAnimSetName()         -- Character angle (0, 90, -90, 180)
player:getPerkLevel(Perks.X)    -- Skill level
player:getTraits()              -- Character traits (Build 42)
player:hasTrait(CharacterTrait.X) -- Character traits (Build 42.13)
player:getBodyDamage()          -- Injury system
player:getStats()               -- Character stats
player:getMoodles()             -- Emotional/physical states
player:getAttackedBy()          -- Current attacker
player:getTargetSeenCount()     -- Nearby zombies
```

#### 2. IsoGridSquare
```lua
square:getX(), :getY(), :getZ() -- Square position
square:TreatAsSolidFloor()      -- Is walkable floor
square:isSolidTrans()           -- Has solid objects
square:isVehicleIntersecting()  -- Vehicle blocking
square:HasStairs()              -- Has stairs
square:Is(IsoFlagType.X)        -- Check flag (Build 42)
square:has(IsoFlagType.X)       -- Check flag (Build 42.13)
```

#### 3. BodyDamage System
```lua
bodyDamage:getBodyPart(BodyPartType.X)
bodyPart:getFractureTime()      -- Fracture duration
bodyPart:isDeepWounded()        -- Deep wound check
bodyPart:getHealth()            -- Health 0-100
bodyPart:getStiffness()         -- Pain/stiffness 0-100
```

#### 4. CharacterStats (Build 42.13)
```lua
stats:getEndurance()            -- Current endurance
stats:remove(CharacterStat.ENDURANCE, amount)  -- Reduce stat
```

#### 5. Moodles
```lua
moodles:getMoodleLevel(MoodleType.ENDURANCE)    -- Fatigue level 0-4
moodles:getMoodleLevel(MoodleType.HEAVY_LOAD)   -- Encumbrance level 0-4
```

#### 6. ISTimedActionQueue
```lua
ISTimedActionQueue.add(action)  -- Queue action for execution
```

#### 7. ISBaseTimedAction
```lua
ISBaseTimedAction:derive("ClassName")  -- Create action class
ISBaseTimedAction.new(self, character) -- Constructor (Build 42.13)
ISBaseTimedAction.start(self)   -- Inherited start method
ISBaseTimedAction.stop(self)    -- Inherited stop method
ISBaseTimedAction.perform(self) -- Inherited perform method
```

#### 8. MovePlayer
```lua
MovePlayer.Teleport(character, x, y, z)  -- Instant position change
```

#### 9. Events System
```lua
Events.OnPlayerUpdate.Add(callback)    -- Register update listener
Events.OnTick.Add(callback)            -- Register tick listener
Events.OnClientCommand.Add(callback)   -- Register network listener (MP)
Events.OnClientCommand.Remove(callback) -- Unregister network listener
```

#### 10. Network System (Multiplayer)
```lua
sendClientCommand(player, module, command, args)  -- Client → Server
-- Callback receives: (module, command, player, args)
```

#### 11. Translation System
```lua
getText("UI_optionscreen_binding_Climb_Key")  -- Localized string lookup
-- Defined in: media/lua/shared/Translate/EN/UI_EN.txt
```

---

### PZAPI ModOptions Integration

```lua
local options = ModOptions:getInstance(require "ClimbWall")

-- Add keybind setting
local keyBind = options:addKeyBind(
    "0",                                        -- Setting ID
    getText("UI_optionscreen_binding_Climb_Key"), -- Display name (localized)
    Keyboard.KEY_F                              -- Default key
)

-- Check if pressed
if keyBind:isPressed() then
    -- Key is currently pressed
end
```

**Configuration File Location:** User's options are saved automatically by PZAPI

---

## Quick Reference

### File Checklist for New Parkour-Style Mod

**Essential Files:**
```
✓ mod.info                      # Mod metadata
✓ ClimbIcon.png                 # UI icon
✓ preview.png                   # Workshop preview
✓ [Action]Config.lua            # Keybind configuration
✓ [Action]Health.lua            # Health validation (optional but recommended)
✓ [Action]Wall.lua              # Main game logic
✓ IS[Action]Wall.lua            # Single-player action class
✓ IS[Action]WallMP.lua          # Multiplayer action class (shared/)
✓ Animation XMLs (5 files)      # Animation state machine definitions
✓ UI_EN.txt                     # Localization strings
```

### Animation XML Template

```xml
<?xml version="1.0" encoding="UTF-8"?>
<animNode>
    <m_Name>[AnimationName]</m_Name>
    <m_AnimName>[BaseGameAnimation]</m_AnimName>
    <m_Speed>[0.80 or 1.00]</m_Speed>
    <m_Loop>[true or false]</m_Loop>
    <m_CustomEvents>
        <name>LuaNet.Event</name>
        <time>[0.30, 0.90, etc.]</time>
        <parameterValue>[parameter string]</parameterValue>
    </m_CustomEvents>
</animNode>
```

### Common Pitfalls & Solutions

| Problem | Cause | Solution |
|---------|-------|----------|
| Animation not triggering | XML file not in correct path | Must be in `media/AnimSets/player/actions/` |
| Diagonal climbing breaks | Missing direction normalization | Always normalize deltaX/deltaY to -1/0/1 |
| Multiplayer desync | No OnClientCommand handler | Implement client→server synchronization |
| Memory leaks | Event listeners not removed | Always unregister in stop()/perform() |
| Endurance not deducted | Using old API | Build 42.13 uses `stats:remove()` not `setEndurance()` |
| Flag checks fail | Wrong API method | Build 42.13 uses `square:has()` not `square:Is()` |
| Player stuck climbing | Movement not unblocked | Call `releaseBlockMovement()` in stop()/perform() |

### Build Version Compatibility Matrix

| Feature | Build 42 (common/) | Build 42.13 (42.13/) |
|---------|-------------------|----------------------|
| Trait checking | `traits:contains("Name")` | `character:hasTrait(CharacterTrait.ENUM)` |
| Moodle enums | `MoodleType.Endurance` | `MoodleType.ENDURANCE` |
| Stats modification | `setEndurance(value)` | `remove(CharacterStat.ENDURANCE, amount)` |
| Square flags | `square:Is(flag)` | `square:has(flag)` |
| Action constructor | Manual metatable | `ISBaseTimedAction.new(self, character)` |

### Performance Optimization Checklist

```
✓ Use early-exit validation chains (cheapest checks first)
✓ Cache frequently accessed objects (player:getSquare())
✓ Avoid redundant calculations in update loops
✓ Use event-driven callbacks instead of polling
✓ Unregister event listeners when no longer needed
✓ Use flag-based collision detection (not raycasts)
✓ Limit verbose logging to debug builds only
```

### Debugging Commands

```lua
-- Enable verbose logging
Climb.Verbose = true

-- Check player angle
print(player:getAnimSetName())  -- Should be 0, 90, -90, or 180

-- Check target square
local target = Climb.getPlayerTarget(player)
print("Target: " .. tostring(target:getX()) .. ", " .. tostring(target:getY()) .. ", " .. tostring(target:getZ()))

-- Check wall flags
print("Blocked West: " .. tostring(Climb.isBlockedOnWestSide(square)))
print("Blocked North: " .. tostring(Climb.isBlockedOnNorthSide(square)))

-- Check health inhibition
print("Health blocks climb: " .. tostring(Climb.isHealthInhibitingClimb(player)))
```

---

## Lessons Learned & Best Practices

### 1. Start Simple, Iterate
- Begin with single-player implementation
- Add multiplayer support once core mechanics work
- Version-specific folders allow gradual API migration

### 2. Use Game's Built-in Systems
- Leverage existing animations (Bob_ClimbFence_*)
- Follow ISBaseTimedAction patterns
- Use game's event system (don't poll)

### 3. Multiplayer Requires Different Thinking
- Client predictions for responsiveness
- Server authority for security
- One-way communication when possible (reduces complexity)

### 4. Health/Stat Systems Are Critical
- Players expect injuries to affect actions
- Endurance costs make actions meaningful
- Balance between realism and fun

### 5. Animation-Driven Design Works Well
- Tight coupling between visuals and logic
- Easy to add new states (success/struggle/fail)
- Events eliminate manual timing code

### 6. Direction-Based Logic Needs Care
- Project Zomboid uses cardinal directions (no true diagonals)
- Normalize floating point math to integers
- Direction-specific validation prevents edge cases

### 7. Version Management Strategy
- Common folder for cross-version code
- Version-specific folders for API changes
- Document API differences explicitly

### 8. Testing Checklist
```
✓ Test all 4 cardinal directions (N/S/E/W)
✓ Test with injured body parts
✓ Test with low endurance
✓ Test with heavy encumbrance
✓ Test with zombies nearby
✓ Test success/struggle/fail outcomes
✓ Test multiplayer synchronization
✓ Test keybind customization
```

---

## Extending This Mod

### Adding New Parkour Actions

**Example: Vault Over Objects**

1. **Create new animation XMLs:**
   - `VaultStart.xml`
   - `VaultSuccess.xml`
   - `VaultFail.xml`

2. **Create action class:**
   - `ISVault.lua` (based on ISClimbWall)
   - Modify target calculation (horizontal instead of vertical)
   - Adjust success rate modifiers (use Nimble/Sprinting perks)

3. **Create main logic file:**
   - `Vault.lua` (based on ClimbWall.lua)
   - Different key binding (default: V)
   - Different wall validation (check for hoppable objects)

4. **Reuse health system:**
   - Same health validation (leg injuries instead of arms)
   - Modify checked body parts in `VaultHealth.lua`

### Adding Skill Progression

```lua
-- In computeSuccessRate()
local climbSkill = character:getPerkLevel(Perks.ClimbingSkill)  -- Custom perk
successProba = successProba + (climbSkill * 3)  -- +3% per level

-- On success
character:getXp():AddXP(Perks.ClimbingSkill, 5)  -- Grant XP
```

### Adding Fatigue Recovery

```lua
-- In consumeEndurance()
if not self.isFail then
    -- Successful climb grants minor endurance recovery
    character:getStats():add(CharacterStat.ENDURANCE, 50)
end
```

---

## Summary

The Climb mod demonstrates:
- **Clean architecture** with separated concerns (config, health, logic, actions)
- **Proper multiplayer design** with client/server separation
- **Event-driven patterns** for performance and maintainability
- **Version management strategy** for API compatibility
- **Animation-driven state machines** for tight visual/logic coupling
- **Defensive programming** with nil checks and validation chains

**Use this documentation** as a reference for building similar action-based mods in Project Zomboid. The patterns and techniques here apply to:
- Parkour systems (vaulting, sliding, rolling)
- Interaction systems (crafting, repairs, construction)
- Combat actions (special attacks, dodges, blocks)
- Movement abilities (sprinting, crouching, prone)

**Key Takeaway:** Build incrementally, test thoroughly, and always consider multiplayer implications from the start.

---

**End of Documentation**
*Generated: 2026-02-04*
*For: Claude Code - Reference for Future Similar Projects*
