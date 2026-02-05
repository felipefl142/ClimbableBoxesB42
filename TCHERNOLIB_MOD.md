# TchernoLib - Project Zomboid B42.13 Mod Library

## Overview

**TchernoLib** is a comprehensive framework/library mod for Project Zomboid B42.13 that provides essential infrastructure systems for other mods. It acts as a dependency mod that other mods (like Climb) rely on for advanced functionality.

**Steam Workshop ID**: 3389605231
**Primary Purpose**: Provide reusable systems for player state management, movement control, object spawning, spectating, UI extensions, and more.

---

## Directory Structure

```
TchernoLib/
├── common/           # Code for all game versions
│   ├── media/lua/
│   │   ├── client/   # Client-side only code
│   │   ├── server/   # Server-side only code
│   │   └── shared/   # Shared code (client + server)
│   └── mod.info
├── 42.13/            # Version-specific code for B42.13
│   └── media/lua/
└── 42/               # Assets (icons/images)
```

---

## Core Systems

### 1. Player Variable System
**Files**: `PlayerVariable/*` (client/server/shared)
**Purpose**: Synchronized boolean state management for players across network

#### Key Components

**PlayerVariableShared.lua** (Base System)
- Global ModData storage keyed by username
- Network sync with 10ms period
- Timestamp-based validation

**API Functions**:
```lua
-- Check if variable is true
PlaVar.is(isoPlayer, 'VariableName') -- returns boolean

-- Set variable (client-side, syncs to server)
PlaVar.set(isoPlayer, 'VariableName', true)

-- Set without network sync
PlaVar.setLocal(isoPlayer, 'VariableName', false)

-- Get variable value
PlaVar.getLocal(isoPlayer, 'VariableName')

-- Get all variables for player
local vars = PlaVar.getMD(isoPlayer)
```

**Built-in Variables**:
- `PlaVar.ZombiesDontAttack` - Zombies ignore this player
- `PlaVar.Invisible` - Player invisibility
- `PlaVar.AvoidDamage` - Damage immunity

**Network Flow**:
1. Client calls `PlaVar.set()` → sends `sendClientCommand()`
2. Server receives via `Events.OnClientCommand`
3. Server updates global ModData and broadcasts via `ModData.transmit()`
4. All clients receive via `Events.OnReceiveGlobalModData`
5. Clients apply changes locally

**Zombie Integration** (ZombieDontAttack.lua):
- Hooks `Events.OnZombieUpdate`
- Redirects zombie targets away from protected players
- Marks zombies as "useless" when no valid targets

**Validation System** (ValidateClientCommand.lua):
```lua
-- Check if sync is ready before sending commands
if isCmdReady() then
  PlaVar.set(player, 'MyVar', true)
end

-- Register callback for when sync completes
PlaVar.onResync(playerNum, function()
  print("Sync ready!")
end)
```

---

### 2. Global Object System
**Files**: `GlobalObject/*` (client/server/shared)
**Purpose**: Create persistent, networked world objects with custom data

#### Architecture

**SharedGlobalObjectTools.lua** (Unified API)
- Single interface for both client and server operations
- Dynamically creates custom event hooks per object type

**Key Concepts**:
- **Key**: Unique identifier for your object type (e.g., "ClimbRope")
- **System Class**: Auto-generated management class for your object type
- **Lua Object**: Custom class representing your object instance

#### API Functions

**Initialization**:
```lua
-- Client-side registration (call early, before OnInitGlobalModData)
ShGO.initCGO('MyObjectType')

-- Server-side registration
ShGO.initSGO('MyObjectType', {'field1', 'field2', 'field3'})
```

**Object Operations**:
```lua
-- Create object at square
ShGO.createCGO('MyObjectType', square, character, {
  field1 = "value",
  field2 = 123
})

-- Remove object
ShGO.removeCGO('MyObjectType', square, character)

-- Update existing object
ShGO.updateCGO('MyObjectType', square, character, {
  field1 = "newvalue"
})

-- Retrieve object data
local obj = ShGO.getGO('MyObjectType', x, y, z)
if obj then
  print(obj.field1)
end

-- Enable context menu in pause mode
ShGO.setContextMenuInPause('MyObjectType', true)
```

**Custom Events** (automatically created):
```lua
-- Object lifecycle events
Events['OnObjectAdded_MyObjectType'].Add(function(obj)
  print("Object created:", obj.field1)
end)

Events['OnObjectRemoved_MyObjectType'].Add(function(obj)
  print("Object removed")
end)

Events['OnObjectUpdated_MyObjectType'].Add(function(obj)
  print("Object updated:", obj.field1)
end)

-- Context menu hook (client)
Events['OnCGlobalObjectContextMenu_MyObjectType'].Add(function(player, context, worldobjects)
  context:addOption("Custom Action", player, function()
    -- Do something
  end)
end)

-- Server command processing
Events['OnSGlobalObjectReceiveCommand_MyObjectType'].Add(function(command, player, args)
  if command == "add_MyObjectType" then
    print("Object created by", player:getUsername())
  end
end)
```

**ISCreateGOAction.lua** (Timed Action Helper):
```lua
-- Create object with animation
local action = ISCreateGOAction:new(
  character,
  square,
  key,           -- Your object type
  args,          -- Object parameters
  maxTime,       -- Duration in ticks
  soundStr,      -- "DigFurrowWithHands"
  metabolic      -- Metabolics.DiggingSpade
)
ISTimedActionQueue.add(action)
```

**Server Implementation Details**:
- Objects are IsoObject instances with ModData
- Auto-saves to world save files
- Integrates with MapObjects for pre-existing objects
- Deferred removal tracking prevents double-delete

**Client Implementation Details**:
- Registers with vanilla GlobalObject system
- Auto-creates Lua wrapper classes
- Updates from server ModData changes
- Context menu integration via ISWorldObjectContextMenu patch

---

### 3. Movement System
**Files**: `Movement/*` (shared)
**Purpose**: Player movement validation, pathfinding, teleportation, and speed control

#### Movement Validation

**MovePlayer.lua**:
```lua
-- Check if movement is blocked
local blocked = MovePlayer.isBlockedTo(fromSquare, toSquare)

-- Check if diagonal movement is possible (handles corners)
local canTraverse = MovePlayer.canTraverseTo(fromSquare, toSquare, deltaX, deltaY)

-- Full movement validation
local canMove = MovePlayer.canDoMoveTo(character, deltaX, deltaY, deltaZ, {
  extrapolation = 0.15,  -- Animation margin
  allowPseudo = false    -- Allow "fake" movement
})
```

**Corner-Cutting Prevention**:
- Diagonal movement requires at least one adjacent square to be traversable
- Prevents players from slipping through tight diagonal gaps

#### Teleportation

**TeleportFunc.lua**:
```lua
-- Instant teleport
MovePlayer.Teleport(isoMovingObject, x, y, z, {
  allowPseudo = false,      -- Don't update lastX/lastY (prevents momentum)
  teleportFarValidation = true  -- Force zone loading for long distances
})
```

#### Speed Framework

**SpeedFramework.lua**:
```lua
-- Set custom player speed (1.0 = normal, 2.0 = double, 0.5 = half)
SpeedFramework.SetPlayerSpeed(player, 1.5)

-- Check if speed framework is active
local active = SpeedFramework.isSpeedFrameworkActive(player, md, speedModifier)
-- Blocked by: vehicles, TrueAction, zombie contact

-- Automatic update (call in OnPlayerUpdate)
SpeedFramework.OnPlayerUpdate(player)
```

**Speed modifier affects**:
- Manual movement (WASD keys)
- Pathfinding movement (click to move)
- Automatically disabled in vehicles or when grabbed by zombie

#### Walk Speed Calculation

**WalkSpeedReverseEngineering.lua** (Vanilla-accurate calculation):
```lua
-- Calculate complete walk speed
local speed = RE.calculateWalkSpeed(isoPlayer, {
  debug = false,
  animation = true  -- Include animation fix multiplier
})

-- Components include:
-- - Endurance and heavy load
-- - Panic effects
-- - Injuries (bleeding, fractured, glass, bullets)
-- - Shoes (barefoot = 0.85x penalty)
-- - Foot injuries (asymmetric limping)
-- - Body damage
-- - Temperature effects
-- - Tree slowdown
-- - Strafe penalty
```

**WalkSpeedTuning.lua** (Configurable system):
```lua
-- Enable/disable specific components
WalkSpeedTuning.TakeSaturation = true
WalkSpeedTuning.TakeTemperature = true
WalkSpeedTuning.TakeTreeModifier = true
WalkSpeedTuning.TakeEnduranceAndHeavyLoad = true
WalkSpeedTuning.TakeInjuriesWalk = true
-- ... more options

-- Update player speed
WalkSpeedTuning.update(isoPlayer)

-- Activate/deactivate system
WalkSpeedTuning.activate(true)
```

---

### 4. Spectate System
**Files**: `Spectate/*` (client/server/shared)
**Purpose**: Ghost mode for observing players without interaction

#### API Functions

```lua
-- Start spectating
Spectate.doSpectatePlayer(playerObj)

-- Stop spectating
Spectate.stopSpectate(playerObj)

-- Check if player is spectating
local isSpectator = Spectate.isSpectatorOther(isoPlayer)
```

#### What Spectate Mode Does

**Player Powers Enabled**:
- NoClip (walk through walls)
- GodMode (invincible)
- Invisible to other players
- ZombiesDontAttack
- Can see all players on map
- Invisible sprint
- All debug options enabled

**Key Bindings Modified**:
- Disables: combat keys, interact, shout, yell, vehicle actions
- Keeps: movement, zoom, pause, chat, admin tools
- Restores original bindings when exiting

**Context Menu Filtering**:
- Blocks all object interactions (no pickup, no doors, no crafting)
- Disables inventory transfers
- Read-only health check for other players
- Removes debug/disassemble/TV options

**Network Synchronization**:
- Client sends spectate flag to server
- Server updates global ModData
- All clients receive update and render spectator as invisible
- Other players cannot interact with spectators

**Server-Side Validation**:
- All object click handlers bypassed for spectators
- Prevents cheating via modified client

---

### 5. Spawner System
**Files**: `Spawner/*` (client/server)
**Purpose**: Persistent item spawning and investigation mechanics

#### Spawn Types

**Container Spawn** (`cItem`):
```lua
-- Spawn item in first container on square
Spawn.addToSpawn({
  rKey = "UniqueKey123",          -- Unique identifier (prevents respawn)
  lootPos = {x = 100, y = 200, z = 0},
  cItem = "Base.Axe",             -- Item to spawn
  hItem = "Base.Note",            -- Optional item inside cItem
  doRespawn = false               -- Respawn on world reload?
})
```

**Investigation Spawn** (`sItem`):
```lua
-- Spawn suspicious object that player must investigate
Spawn.addToSpawn({
  rKey = "UniqueKey456",
  lootPos = {x = 100, y = 200, z = 0},
  sprite = "location_shop_accesories_01_22",  -- Object appearance
  sItem = "Base.Hammer",          -- Item to discover
  doRespawn = false
})
```

#### Investigation Mechanics

**Client-side**:
- Right-click suspicious object → "Investigate" context menu
- Plays dig animation with sound
- Extracts item and adds to inventory
- Player says discovery notification
- Object removed from world when empty

**Book Spawning** (TL_ISReadABook.lua):
```lua
-- Special case: FakeBook that contains real item
-- When player reads Base.FakeBook, receives actual item from ModData
```

#### Spawn Persistence

- Uses global ModData with key `Spawn.SpawnKey` ('spawn')
- Tracks which rKeys have been spawned
- Prevents duplicate spawns across server restarts
- Optional respawn system for renewable resources

**Remove spawn definition**:
```lua
Spawn.removeFromSpawn("UniqueKey123", true)  -- true = keep in ModData (prevent future spawn)
```

---

### 6. UI Components
**Files**: `UI/*` (client)
**Purpose**: UI extensions and debug tools

#### Character Info Tabs

**CharacterInfoAddTab.lua**:
```lua
-- Add custom tab to Character Info window
addCharacterPageTab("MyTab", MyCustomPageClass)

-- MyCustomPageClass must inherit from ISCollapsableWindow
-- Implements: createChildren(), render(), update()
```

**Features**:
- Automatic layout persistence
- Tab tear-off support (separate windows)
- Integrates with vanilla character info window

#### Drawing Utilities

**DrawCircle.lua**:
```lua
-- Draw circle at world position
luautils.renderIsoCircle(
  playerNum,
  posX, posY, posZ,  -- World coordinates
  ray,               -- Radius in tiles
  r, g, b, a         -- Color (0-1 range)
)

-- Draw thick line
luautils.drawLine2(x1, y1, x2, y2, a, r, g, b, angle, thick)

-- Get screen boundaries
local mask = luautils.getScreenMask(playerNum)
-- Returns {x1, y1, x2, y2, x3, y3, x4, y4}
```

**Features**:
- Screen clipping via mask
- Angular step ~6.3° for smooth circles
- Perspective-aware thickness

#### Admin Tools

**ISItemListTable_PatchModdedIcons.lua**:
- Patches admin panel item list
- Shows custom item icons from mods
- Falls back to texture if icon missing

**PlayerModData.lua**:
```lua
-- Debug panel showing all player ModData
-- Accessible via debug menu "PlayerModData" button
-- Features:
-- - Lists all players (local, active, online)
-- - Shows complete ModData tree
-- - Auto-refresh toggle
-- - Nested table serialization
```

---

### 7. World Chat System
**Files**: `WorldChat/*` (client)
**Purpose**: Floating text above objects in 3D space

#### API Functions

```lua
-- Display text above object
WorldChat.say(isoObject, "Hello world!")

-- Get or create chat bubble
local chat = WorldChat.get(isoObject, {
  font = UIFont.Dialogue,
  red = 1.0, green = 1.0, blue = 1.0,
  OffsetX = 0, OffsetY = 0, OffsetZ = 0.66,
  UIOffsetY = -30,
  DisplayTime = 8  -- Seconds
})

-- Add line to existing chat
chat:addLine("Additional text")

-- Customize parameters
chat:setParams({
  red = 1.0, green = 0.0, blue = 0.0,
  DisplayTime = 5
})
```

#### Default Behaviors

**IsoGameCharacter** (players/NPCs):
- Z offset: 0.66 (above head)
- UI Y offset: -30 pixels
- Random RGB color saved to ModData (persistent per character)

**Other Objects**:
- Centered above object sprite
- White text by default

**Rendering**:
- Auto-renders each frame via UIManager
- Expires after DisplayTime seconds
- Multiple lines supported
- Screen position auto-calculated from world position

**Customization**:
Override `WorldChat.computeClassParams(isoObject)` for custom object types

---

### 8. Key Control System
**File**: `KeyControl/TchKeysControl.lua` (B42.13 client)
**Purpose**: Save/restore keybindings for custom input schemes

#### API Functions

```lua
-- Save current keybinds and clear core keys
Tch.activateKeyControl(playerObj)

-- Restore original keybinds
Tch.deactivateKeyControl(playerObj)

-- Check if custom control is active
local active = Tch.hasKeyControl(playerObj)
```

#### Controlled Keys

- Forward, Backward, Left, Right
- Run, Sprint
- Interact

#### Storage Format

```lua
-- Saved to player ModData as:
{
  k = keyCode,      -- Primary key
  j = altKeyCode,   -- Alternate key
  s = shift,        -- Shift modifier
  c = ctrl,         -- Ctrl modifier
  a = alt           -- Alt modifier
}
```

#### Event Handlers

```lua
-- Check if specific key pressed
Tch.istKeyForward(key, player)
Tch.istKeyBackward(key, player)
Tch.istKeyLeft(key, player)
Tch.istKeyRight(key, player)
Tch.istKeyRun(key, player)
Tch.istKeySprint(key, player)
Tch.istKeyInteract(key, player)

-- Use in OnKeyPressed event
Events.OnKeyPressed.Add(function(key)
  if Tch.istKeyForward(key, player) then
    -- Handle custom forward
  end
end)
```

**Use Case**: Mods that need custom player control schemes (like Climb mod's climbing controls)

---

### 9. Geometry Utilities
**File**: `Geometry/ShIntersect.lua` (shared)
**Purpose**: 2D collision detection and geometric calculations

#### API Functions

```lua
-- Point in rectangle test
local inside = Sh.isPointInQuadrilateral(
  {x = 5, y = 5},  -- Point to test
  0, 10,           -- X bounds
  0, 10            -- Y bounds
)

-- Point in triangle test
local inside = Sh.isPointInTriangle(
  {x = 5, y = 5},           -- Point to test
  {x = 0, y = 0},           -- Triangle vertex 1
  {x = 10, y = 0},          -- Triangle vertex 2
  {x = 5, y = 10}           -- Triangle vertex 3
)

-- Line segment intersection
local intersection = Sh.get_line_intersection(
  {x = 0, y = 0}, {x = 10, y = 10},    -- Line segment 1
  {x = 0, y = 10}, {x = 10, y = 0}     -- Line segment 2
)
-- Returns {x, y} or nil if no intersection
```

**Implementation**:
- Uses cross products for triangle tests
- Parametric equations for line intersection
- Validates segment bounds (t ∈ [0,1])

---

### 10. Override and Reflection System
**Files**: `Override/*` (shared)
**Purpose**: Access and modify Java classes at runtime

#### Access Public Fields

**AccessPublicParameter.lua**:
```lua
-- Get field value from Java instance
local value = getPublicFieldValue(classInstance, "fieldName")

-- Manually get field object
local field = APP.getField(javaClass, "fieldName")
if field then
  local value = field:get(classInstance)
end
```

**Features**:
- Memoization per instance via `APP.fieldMap`
- Skips private/protected fields (prevents crashes)
- String parsing for safety

**Use Case**: Access Java fields not exposed to Lua API

#### Override Java Methods

**OverrideJavaPublicMethod.lua**:
```lua
-- Patch a Java class method
Override.patchClassMetaMethod(
  javaClass,
  "methodName",
  function(originalMethod)
    -- Return patched method
    return function(instance, ...)
      -- Pre-processing
      print("Method called")

      -- Call original
      local result = originalMethod(instance, ...)

      -- Post-processing
      print("Method result:", result)

      return result
    end
  end
)
```

**How it Works**:
1. Retrieves class metatable from `__classmetatables`
2. Wraps original method with custom function
3. Patch receives original as parameter
4. Functional wrapper pattern for interception

**Credit**: Technique from Steam mod by Deon and Poltergeist

---

### 11. Shared Utilities
**Files**: `Shared_*.lua` (shared)
**Purpose**: Common utility functions used across all systems

#### Lua Utils (Shared_luautils.lua)

```lua
-- Convert any table to string
local str = tab2str(myTable)

-- Grid square to string
local str = sq2str(isoGridSquare)  -- "x=100 y=200 z=0"

-- Grid square to table
local pos = sq2tab(isoGridSquare)  -- {x=100, y=200, z=0}

-- Player to string
local str = p2str(isoPlayer)  -- "Username"

-- Object to string
local str = o2str(isoObject)  -- "Object Name"

-- Boolean to string
local str = b2str(true)  -- "true"

-- Deep table copy with cycle detection
local copy = luautils.copyTable(originalTable)
```

#### Mouse Targeting (Shared_target.lua)

```lua
-- Get grid square player is pointing at
local square = getPlayerMouseSquare(player, {
  block = true,              -- Respect blocking objects
  door = true,               -- Doors block
  window = true,             -- Windows block
  verticalBlocker = true,    -- Floor blocks looking down
  windowSeeThrough = false   -- Windows transparent?
})

-- Get precise iso position
local pos = getPlayerMouseIsoPosition(player, args)
-- Returns IsoPosition object

-- Create lightweight position (no grid square)
local pos = IsoPosition:new(x, y, z)
```

**Features**:
- 3D raycasting with vertical detection
- Line-of-sight validation
- Window transparency toggle
- Blocking object detection

#### Time Conversion (Shared_time.lua)

```lua
-- Real seconds to game hours
local gameHours = luatime.getRealtimeSeconds2WorldHours(60)

-- Game hours to real seconds
local realSeconds = luatime.getWorldHours2RealtimeSeconds(1.0)
```

**Accounts for**: Minutes-per-day variable from GameTime

#### Java Method Caching (Shared_local.lua)

```lua
-- Get cached Java method pointers
local methods = getLocalJavaFuncPointers()
```

**Optimized Classes**:
- IsoPlayer, IsoRoom, RoomDef, IsoBuilding, BuildingDef
- ArrayList, PZArrayList, IsoCell, IsoGridSquare
- IsoObject, PropertyContainer

**Performance**: Avoids repeated Lua→Java method lookups

#### Color System (SharedColor.lua)

```lua
-- Get color from enum (1-22)
local color = Sh.getColorFromEnum(5)  -- {r=0.0, g=0.0, b=1.0} (Blue)
```

**Available Colors** (22 total):
Black, White, Red, Lime, Blue, Yellow, Cyan, Magenta, Silver, Gray, Maroon, Olive, Green, Purple, Teal, Navy, OrangeSalmon, OrangeTangerine, OrangePeach, OrangeMacaroni, Gold, Azure

**Use Case**: Sandbox options with ColorEnum valueTranslation

---

### 12. Identification System
**File**: `Identification/Identification.lua` (shared)
**Purpose**: Object type identification utilities

```lua
-- Search objects list with predicate
local found = Id.getFromWorldObjects(worldobjects, function(obj)
  return obj:getName() == "Target"
end)

-- Check if object is dead body
local isDead = Id.isDeadBody(isoObject)
```

**Pattern**: Predicate function approach for flexible queries

---

## Integration Patterns

### Network Synchronization Flow

**Standard Pattern** (PlayerVariable, Spectate, GlobalObject):

1. **Client Initiates**:
   ```lua
   PlaVar.set(player, 'Variable', true)
   ```

2. **Client Sends Command**:
   ```lua
   sendClientCommand(modId, command, args)
   ```

3. **Server Receives**:
   ```lua
   Events.OnClientCommand.Add(function(module, command, player, args)
     if module == modId then
       -- Validate and process
       -- Update global ModData
       ModData.transmit(key)
     end
   end)
   ```

4. **All Clients Receive**:
   ```lua
   Events.OnReceiveGlobalModData.Add(function(key)
     if key == modId then
       -- Apply changes locally
     end
   end)
   ```

### ModData Storage Strategy

**Global ModData Keys**:
- `'Variables'` - PlayerVariable system (per-player booleans)
- `'Spectate'` - Spectate flags (per-player)
- `'spawn'` - Spawner tracking (rKeys spawned)
- `'ShGO'` - GlobalObject deferred removals

**Instance ModData**:
- Objects: `isoObject:getModData()[key]` for GlobalObject data
- Players: `playerModData['Tch'..keyName]` for keybindings
- Players: `modData.WorldChat` for chat parameters

### Event System

**Custom Events** (dynamically created):
```lua
Events['OnObjectAdded_<key>']
Events['OnObjectRemoved_<key>']
Events['OnObjectUpdated_<key>']
Events['OnCGlobalObjectContextMenu_<key>']
Events['OnSGlobalObjectReceiveCommand_<key>']
Events['OnOtherPlayerDetected']
```

**Standard Events Used**:
- `Events.OnPlayerUpdate` - Per-frame player logic
- `Events.OnPlayerMove` - Movement detection
- `Events.OnClientCommand` - Network commands (server)
- `Events.OnInitGlobalModData` - Mod data initialization
- `Events.OnReceiveGlobalModData` - Mod data sync (client)
- `Events.LoadGridsquare` - Chunk loading (spawner)
- `Events.OnTick` - Global tick (60 FPS)
- `Events.OnZombieUpdate` - Zombie behavior (ZombieDontAttack)
- `Events.OnMiniScoreboardUpdate` - Player list changes

### Naming Conventions

**Module Prefixes**:
- `Sh*` / `Sh` - Shared (client + server)
- `C*` - Client-only (CGO, CSpawn)
- `S*` - Server-only (SGO, SSpawn)
- `PlaVar` - PlayerVariable namespace
- `Spectate` - Spectate namespace
- `Spawn` - Spawner namespace

**Function Types**:
- `get*/set*/is*/has*` - Query/modify state
- `On*` - Event handlers
- `*To/*From` - Conversion functions
- `create*/add*/remove*` - Lifecycle management

---

## Common Use Cases

### Creating a Custom Object Type

```lua
-- 1. Register systems (early initialization)
ShGO.initCGO('MyRope')
ShGO.initSGO('MyRope', {'length', 'attached', 'ownerName'})

-- 2. Create object when player uses item
local square = player:getSquare()
ShGO.createCGO('MyRope', square, player, {
  length = 5,
  attached = true,
  ownerName = player:getUsername()
})

-- 3. Listen for creation
Events['OnObjectAdded_MyRope'].Add(function(obj)
  print("Rope created with length:", obj.length)
end)

-- 4. Add context menu options
Events['OnCGlobalObjectContextMenu_MyRope'].Add(function(player, context, worldobjects)
  local rope = worldobjects[1]
  context:addOption("Climb Rope", player, function()
    -- Implement climb logic
  end)
end)

-- 5. Update object state
ShGO.updateCGO('MyRope', square, player, {
  attached = false
})

-- 6. Remove when done
ShGO.removeCGO('MyRope', square, player)
```

### Managing Player State

```lua
-- Make player invisible to zombies
PlaVar.set(player, PlaVar.ZombiesDontAttack, true)

-- Check if another player is invisible
if PlaVar.is(otherPlayer, PlaVar.ZombiesDontAttack) then
  print(otherPlayer:getUsername(), "is hidden from zombies")
end

-- Custom variable
PlaVar.set(player, 'IsClimbing', true)

-- Wait for sync before sending commands
if isCmdReady() then
  PlaVar.set(player, 'MyVariable', true)
end
```

### Custom Player Movement

```lua
-- Validate before moving
local newX = player:getX() + deltaX
local newY = player:getY() + deltaY
local newZ = player:getZ()

if MovePlayer.canDoMoveTo(player, deltaX, deltaY, 0) then
  -- Apply movement
  player:setX(newX)
  player:setY(newY)
  player:setLx(newX)
  player:setLy(newY)
else
  print("Movement blocked!")
end

-- Teleport player
MovePlayer.Teleport(player, x, y, z)

-- Custom speed boost
SpeedFramework.SetPlayerSpeed(player, 1.5)  -- 50% faster
```

### Item Spawning

```lua
-- Spawn item in container
Spawn.addToSpawn({
  rKey = "quest_item_basement",
  lootPos = {x = 10500, y = 9800, z = 0},
  cItem = "Base.Bag_DuffelBag",
  hItem = "Base.HandTorch",  -- Inside the bag
  doRespawn = false
})

-- Investigation spawn
Spawn.addToSpawn({
  rKey = "hidden_stash_warehouse",
  lootPos = {x = 10600, y = 9900, z = 0},
  sprite = "furniture_storage_02_8",
  sItem = "Base.Shotgun",
  doRespawn = false
})
```

### Spectator Mode

```lua
-- Enter spectate mode
Spectate.doSpectatePlayer(player)

-- Check before allowing actions
if not Spectate.isSpectating(player) then
  -- Allow interaction
end

-- Exit spectate
Spectate.stopSpectate(player)
```

### World Chat Notifications

```lua
-- Player says something
WorldChat.say(player, "I found something!")

-- Object notification
local item = player:getInventory():getItemFromType("Base.Hammer")
WorldChat.say(item, "This is my hammer")

-- Custom styling
local chat = WorldChat.get(player, {
  red = 1.0, green = 0.0, blue = 0.0,
  DisplayTime = 10
})
chat:addLine("Warning: Danger ahead!")
```

### Custom Keybindings

```lua
-- Save and clear original bindings
Tch.activateKeyControl(player)

-- Handle custom input
Events.OnKeyPressed.Add(function(key)
  if not Tch.hasKeyControl(player) then return end

  if Tch.istKeyForward(key, player) then
    -- Custom forward behavior
  elseif Tch.istKeyBackward(key, player) then
    -- Custom backward behavior
  end
end)

-- Restore original bindings
Tch.deactivateKeyControl(player)
```

---

## Debugging and Verbose Mode

Most systems have verbose logging:

```lua
-- Enable debug output
PlaVar.Verbose = true
Spectate.Verbose = true
ShGO.Verbose = true
MovePlayer.Verbose = true
Spawn.Verbose = true

-- Disable
PlaVar.Verbose = false
```

**Player ModData Viewer**:
- Access via Debug menu → "PlayerModData"
- Shows all player variables in real-time
- Auto-refresh option
- Useful for debugging sync issues

---

## External Dependencies

**PZ Vanilla Systems**:
- Event system (`Events.*`)
- Global ModData (`ModData.get/add/transmit`)
- Network commands (`sendClientCommand`, `OnClientCommand`)
- UI framework (ISUIElement, ISPanel, ISCollapsableWindow)
- Context menus (ISContextMenu, ISWorldObjectContextMenu)
- Timed actions (ISBaseTimedAction)
- Global Objects (CGlobalObjectSystem, SGlobalObjectSystem)
- MapObjects (OnNewWithSprite, OnLoadWithSprite)

**Lua Standard Library**:
- `pairs`, `ipairs` - iteration
- `table.*` - table manipulation
- `math.*` - mathematical operations
- `string.*` - string operations

---

## Best Practices for Dependent Mods

### Initialization Order

1. **Early** (before `OnInitGlobalModData`):
   ```lua
   ShGO.initCGO('MyKey')
   ShGO.initSGO('MyKey', {'field1'})
   ```

2. **OnInitGlobalModData**:
   ```lua
   Events.OnInitGlobalModData.Add(function(isNewGame)
     -- Subscribe to ModData
     ModData.getOrCreate('MyModKey')
   end)
   ```

3. **Late** (OnGameBoot/OnLoad):
   ```lua
   Events.OnGameBoot.Add(function()
     -- Register event listeners
     Events['OnObjectAdded_MyKey'].Add(myHandler)
   end)
   ```

### Network Command Validation

```lua
-- Always validate sync before sending
if isCmdReady() then
  PlaVar.set(player, 'Variable', true)
else
  -- Queue for later or use onResync callback
  PlaVar.onResync(playerNum, function()
    PlaVar.set(player, 'Variable', true)
  end)
end
```

### Error Handling

```lua
-- Check objects exist
local obj = ShGO.getGO('MyKey', x, y, z)
if obj then
  -- Safe to use
else
  print("Object not found at", x, y, z)
end

-- Validate player
if player and player:isLocalPlayer() then
  PlaVar.set(player, 'Variable', true)
end
```

### Performance Considerations

- Cache Java method pointers via `getLocalJavaFuncPointers()`
- Use `PlaVar.setLocal()` for temporary state (no network)
- Minimize `OnPlayerUpdate` hook usage (60 FPS)
- Use `OnPlayerMove` only when movement matters
- Disable verbose logging in production (`*.Verbose = false`)

---

## Version Compatibility

**TchernoLib Structure**:
- `/common/` - Works on all PZ versions
- `/42.13/` - Specific to B42.13
- `/42/` - Assets only

**Version-Specific Files**:
- `TchKeysControl.lua` - B42.13 only (keybinding system changed)
- Most systems in `/common/` are version-agnostic

---

## Credits and Attribution

**OverrideJavaPublicMethod.lua**: Based on technique by Deon and Poltergeist from their Steam workshop mod

**Author**: Tcherno (Steam Workshop)

---

## Summary

TchernoLib provides the following production-ready systems:

1. **PlayerVariable** - Synchronized boolean flags
2. **GlobalObject** - Persistent networked world objects
3. **Movement** - Validation, pathfinding, teleport, speed control
4. **Spectate** - Observer mode with restrictions
5. **Spawner** - Persistent loot placement
6. **UI Extensions** - Character tabs, circles, chat bubbles
7. **Key Control** - Custom input schemes
8. **Geometry** - 2D collision detection
9. **Override** - Java reflection utilities
10. **Utilities** - Targeting, time, colors, identification

All systems follow consistent patterns for network sync, ModData storage, and event handling. The framework is designed for extensibility and provides a solid foundation for complex Project Zomboid mods.
