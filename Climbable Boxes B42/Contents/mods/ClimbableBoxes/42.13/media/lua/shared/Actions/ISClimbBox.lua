require "TimedActions/ISBaseTimedAction"

ISClimbBox = ISBaseTimedAction:derive("ISClimbBox")

function ISClimbBox:new(character, targetSquare, targetBox)
    local o = ISBaseTimedAction.new(self, character)
    o.stopOnWalk = false
    o.stopOnRun = false
    o.maxTime = 150  -- Approximate total time for all animations (ticks at 60 FPS)

    -- Target info
    o.targetSquare = targetSquare
    o.targetBox = targetBox

    -- Animation names
    o.startAnim = "ClimbBoxStart"
    o.successAnim = "ClimbBoxSuccess"
    o.struggleAnim = "ClimbBoxStruggle"
    o.failAnim = "ClimbBoxFail"
    o.endAnim = "ClimbBoxEnd"

    -- State tracking for timer-based progression
    o.isFail = false
    o.isStruggle = false
    o.currentState = "start"  -- start, outcome, teleport, end, complete
    o.stateStartTime = 0
    o.outcomeComputed = false
    o.teleported = false

    return o
end

function ISClimbBox:isValidStart()
    return true
end

function ISClimbBox:isValid()
    return true
end

function ISClimbBox:update()
    -- Timer-based state machine (runs every frame at ~60 FPS)
    local currentTime = self.action:getJobDelta()

    -- Start animation: wait ~45 ticks (0.75 seconds at 60 FPS) before computing outcome
    if self.currentState == "start" and not self.outcomeComputed then
        if currentTime >= 45 then
            print("[ISClimbBox] Timer: Computing outcome at " .. currentTime .. " ticks")
            self:computeOutcome()
            self.outcomeComputed = true
            self.currentState = "outcome"
            self.stateStartTime = currentTime
        end

    -- Outcome animation: wait for success/struggle/fail animation to play (~40 ticks)
    elseif self.currentState == "outcome" and not self.teleported then
        if currentTime >= self.stateStartTime + 40 then
            if not self.isFail then
                print("[ISClimbBox] Timer: Teleporting at " .. currentTime .. " ticks")
                self:teleportPlayer()
                self.teleported = true
            end
            self.currentState = "end"
            self.stateStartTime = currentTime
            self:setActionAnim(self.endAnim)
        end

    -- End animation: wait ~30 ticks then complete
    elseif self.currentState == "end" then
        if currentTime >= self.stateStartTime + 30 then
            print("[ISClimbBox] Timer: Completing action at " .. currentTime .. " ticks")
            self:forceComplete()
        end
    end
end

function ISClimbBox:start()
    print("[ISClimbBox] start() called, setting animation: " .. self.startAnim)
    self:setActionAnim(self.startAnim)
    self.stateStartTime = 0
    print("[ISClimbBox] Timer-based state machine initialized")
end

function ISClimbBox:stop()
    Events.OnClientCommand.Remove(ISClimbBox.OnClientCommandCallback)
    ISBaseTimedAction.stop(self)
end

function ISClimbBox:perform()
    Events.OnClientCommand.Remove(ISClimbBox.OnClientCommandCallback)
    ISBaseTimedAction.perform(self)
end

function ISClimbBox:getDuration()
    return -1
end

function ISClimbBox:complete()
    return false
end

-- Server-side initialization for multiplayer
function ISClimbBox:serverStart()
    emulateAnimEvent = true
    Events.OnClientCommand.Add(ISClimbBox.OnClientCommandCallback)
end

-- Server command handler for multiplayer endurance sync
function ISClimbBox.OnClientCommandCallback(module, command, player, args)
    if module ~= "ClimbBox" then return end
    if command == "consumeEndurance" then
        player:getStats():remove(CharacterStat.ENDURANCE, args.tractionDone)
    end
end

-- Compute success rate based on character stats (Full difficulty only)
function ISClimbBox:computeSuccessRate()
    local character = self.character

    local successProba = SandboxVars.ClimbableBoxes.BaseSuccessRate or 90

    -- Positive modifiers: fitness and strength
    successProba = successProba + (character:getPerkLevel(Perks.Fitness) * 2)
    successProba = successProba + (character:getPerkLevel(Perks.Strength) * 2)

    -- Negative modifiers: moodles
    local enduranceMoodle = character:getMoodles():getMoodleLevel(MoodleType.ENDURANCE)
    local heavyLoadMoodle = character:getMoodles():getMoodleLevel(MoodleType.HEAVY_LOAD)
    successProba = successProba - (enduranceMoodle * 10)
    successProba = successProba - (heavyLoadMoodle * 16)

    -- Negative modifiers: traits
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
        successProba = successProba - 25
    end
    local nearbyZombies = character:getTargetSeenCount()
    successProba = successProba - (nearbyZombies * 7)

    -- Clamp
    if successProba < 0 then successProba = 0 end
    if successProba > 100 then successProba = 100 end

    -- Roll
    local rand = ZombRand(0, 101)

    -- Critical success (1% chance)
    if rand == 1 then
        self.isFail = false
        self.isStruggle = false
        return
    end

    -- Struggle: rand between (successProba - 25) and successProba
    self.isStruggle = (rand > (successProba - 25))

    -- Fail: rand > successProba
    self.isFail = (rand > successProba)
end

-- Compute outcome and transition to appropriate animation
function ISClimbBox:computeOutcome()
    local difficultyMode = SandboxVars.ClimbableBoxes.DifficultyMode or 1

    if difficultyMode == 1 then
        -- Full mode: compute success/struggle/fail
        self:computeSuccessRate()
    else
        -- Simplified mode: always succeed
        self.isFail = false
        self.isStruggle = false
    end

    self:consumeEndurance()

    -- Transition to next animation based on outcome
    if self.isFail then
        print("[ISClimbBox] Outcome: FAIL")
        self:setActionAnim(self.failAnim)
    elseif self.isStruggle then
        print("[ISClimbBox] Outcome: STRUGGLE")
        self:setActionAnim(self.struggleAnim)
    else
        print("[ISClimbBox] Outcome: SUCCESS")
        self:setActionAnim(self.successAnim)
    end
end

-- Teleport player to target square
function ISClimbBox:teleportPlayer()
    MovePlayer.Teleport(
        self.character,
        self.targetSquare:getX() + 0.5,
        self.targetSquare:getY() + 0.5,
        self.targetSquare:getZ()
    )
    print("[ISClimbBox] Player teleported to box square")
end

-- Consume endurance, scaled by sandbox multiplier
function ISClimbBox:consumeEndurance()
    local multiplier = SandboxVars.ClimbableBoxes.EnduranceCostMultiplier or 1.0
    local tractionDone = ZomboidGlobals.RunningEnduranceReduce * 800.0

    if self.isStruggle then
        tractionDone = tractionDone + (ZomboidGlobals.RunningEnduranceReduce * 500.0)
    end

    tractionDone = tractionDone * multiplier

    -- Send to server for authoritative application in MP
    sendClientCommand(
        self.character,
        "ClimbBox",
        "consumeEndurance",
        { tractionDone = tractionDone, isStruggle = self.isStruggle }
    )
end

-- Animation event handler - for logging only (state machine now uses timer in update())
function ISClimbBox:animEvent(event, parameter)
    -- Log animation events for debugging (state machine uses timer-based approach)
    print("[ISClimbBox] animEvent called: event=" .. tostring(event) .. ", parameter=" .. tostring(parameter))
end
