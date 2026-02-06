-- PZ Globals Mock - Busted helper loaded before every test
-- Defines all PZ enums, globals, functions needed by the mod

-- Suppress print during tests (mod is very chatty)
local _realPrint = print
_G._testPrints = {}
function print(...)
    local args = {...}
    local parts = {}
    for i = 1, select('#', ...) do
        parts[#parts + 1] = tostring(args[i])
    end
    table.insert(_G._testPrints, table.concat(parts, "\t"))
end

-- ============================================================
-- PZ Enums
-- ============================================================

_G.IsoDirections = {
    N = "N", NE = "NE", E = "E", SE = "SE",
    S = "S", SW = "SW", W = "W", NW = "NW",
}

_G.BodyPartType = {
    Hand_L = "Hand_L", Hand_R = "Hand_R",
    ForeArm_L = "ForeArm_L", ForeArm_R = "ForeArm_R",
    UpperArm_L = "UpperArm_L", UpperArm_R = "UpperArm_R",
    Torso_Upper = "Torso_Upper", Torso_Lower = "Torso_Lower",
    UpperLeg_L = "UpperLeg_L", UpperLeg_R = "UpperLeg_R",
    LowerLeg_L = "LowerLeg_L", LowerLeg_R = "LowerLeg_R",
    Foot_L = "Foot_L", Foot_R = "Foot_R",
    Head = "Head", Neck = "Neck",
    Groin = "Groin",
}

_G.CharacterTrait = {
    EMACIATED = "EMACIATED",
    OBESE = "OBESE",
    VERY_UNDERWEIGHT = "VERY_UNDERWEIGHT",
    UNDERWEIGHT = "UNDERWEIGHT",
    OVERWEIGHT = "OVERWEIGHT",
}

_G.MoodleType = {
    ENDURANCE = "ENDURANCE",
    HEAVY_LOAD = "HEAVY_LOAD",
}

_G.Perks = {
    Fitness = "Fitness",
    Strength = "Strength",
}

_G.CharacterStat = {
    ENDURANCE = "ENDURANCE",
}

_G.IsoFlagType = {
    stairTW = "stairTW", stairNW = "stairNW",
}

_G.Keyboard = {
    KEY_G = 34,
}

-- ============================================================
-- PZ Global Functions
-- ============================================================

_G._instanceofMap = {}
function _G.instanceof(obj, className)
    if not obj then return false end
    if obj._className == className then return true end
    return false
end

function _G.getText(key)
    return key or ""
end

_G._keyDownState = {}
function _G.isKeyDown(key)
    return _G._keyDownState[key] or false
end

_G._isClientVal = false
function _G.isClient()
    return _G._isClientVal
end

_G._isServerVal = false
function _G.isServer()
    return _G._isServerVal
end

_G._specificPlayers = {}
function _G.getSpecificPlayer(num)
    return _G._specificPlayers[num]
end

_G._zombRandVal = 50
function _G.ZombRand(min, max)
    return _G._zombRandVal
end

_G._sentClientCommands = {}
function _G.sendClientCommand(character, module, command, args)
    table.insert(_G._sentClientCommands, {
        character = character,
        module = module,
        command = command,
        args = args,
    })
end

-- ============================================================
-- PZ Global Tables
-- ============================================================

_G.ZomboidGlobals = {
    RunningEnduranceReduce = 0.005,
}

_G.MovePlayer = {
    _calls = {},
    Teleport = function(character, x, y, z)
        table.insert(_G.MovePlayer._calls, {
            character = character,
            x = x, y = y, z = z,
        })
    end,
}

_G.ISTimedActionQueue = {
    _added = {},
    add = function(action)
        table.insert(_G.ISTimedActionQueue._added, action)
    end,
}

_G.SandboxVars = {
    ClimbableBoxes = {
        DifficultyMode = 1,
        BaseSuccessRate = 90,
        EnduranceCostMultiplier = 1.0,
        EnableHealthCheck = true,
    }
}

_G.ModOptions = nil  -- nil by default, tests can set it

_G.emulateAnimEvent = false

-- ============================================================
-- Events System Mock
-- ============================================================

local function createEventMock()
    local event = {
        _callbacks = {},
    }
    function event.Add(callback)
        table.insert(event._callbacks, callback)
    end
    function event.Remove(callback)
        for i, cb in ipairs(event._callbacks) do
            if cb == callback then
                table.remove(event._callbacks, i)
                return
            end
        end
    end
    return event
end

_G.Events = {
    OnPlayerUpdate = createEventMock(),
    OnClientCommand = createEventMock(),
    OnFillWorldObjectContextMenu = createEventMock(),
}

-- ============================================================
-- ISBaseTimedAction Mock
-- ============================================================

_G.ISBaseTimedAction = {}
ISBaseTimedAction.__index = ISBaseTimedAction

function ISBaseTimedAction:derive(name)
    local derived = {}
    derived.__index = derived
    setmetatable(derived, { __index = ISBaseTimedAction })
    derived._derivedName = name
    return derived
end

function ISBaseTimedAction.new(self, character)
    local o = {}
    setmetatable(o, { __index = self })
    o.character = character
    o.action = {
        _jobDelta = 0,
        getJobDelta = function(a) return a._jobDelta end,
    }
    return o
end

function ISBaseTimedAction:setActionAnim(anim)
    self._currentAnim = anim
end

function ISBaseTimedAction:forceComplete()
    self._forceCompleted = true
end

function ISBaseTimedAction:stop()
    self._stopped = true
end

function ISBaseTimedAction:perform()
    self._performed = true
end

-- Pre-populate require cache for PZ modules
package.loaded["TimedActions/ISBaseTimedAction"] = true

-- ============================================================
-- Module path setup
-- ============================================================

local projectRoot = debug.getinfo(1, "S").source:match("@?(.*/)")
-- Go up from tests/mocks/ to project root
projectRoot = projectRoot:gsub("tests/mocks/$", "")

local modBase = projectRoot .. "Climbable Boxes B42/Contents/mods/ClimbableBoxes/42.13/media/"
package.path = modBase .. "lua/client/?.lua;"
    .. modBase .. "lua/shared/?.lua;"
    .. modBase .. "lua/shared/Actions/?.lua;"
    .. package.path

-- ============================================================
-- Reset function for before_each hooks
-- ============================================================

function _G.resetAllMocks()
    _G._testPrints = {}
    _G._keyDownState = {}
    _G._isClientVal = false
    _G._isServerVal = false
    _G._specificPlayers = {}
    _G._zombRandVal = 50
    _G._sentClientCommands = {}
    _G._instanceofMap = {}
    _G.emulateAnimEvent = false

    _G.MovePlayer._calls = {}
    _G.ISTimedActionQueue._added = {}

    _G.SandboxVars.ClimbableBoxes = {
        DifficultyMode = 1,
        BaseSuccessRate = 90,
        EnduranceCostMultiplier = 1.0,
        EnableHealthCheck = true,
    }

    _G.ModOptions = nil

    -- Reset events
    _G.Events.OnPlayerUpdate = createEventMock()
    _G.Events.OnClientCommand = createEventMock()
    _G.Events.OnFillWorldObjectContextMenu = createEventMock()

    -- Clear loaded mod modules so they can be re-required cleanly
    for key, _ in pairs(package.loaded) do
        if key:match("ClimbBox") or key:match("ISClimbBox") or key:match("ClimbableBoxes") then
            package.loaded[key] = nil
        end
    end

    -- Reset global mod tables
    _G.ClimbBox = nil
    _G.ISClimbBox = nil

    -- Keep ISBaseTimedAction loaded
    package.loaded["TimedActions/ISBaseTimedAction"] = true
end
