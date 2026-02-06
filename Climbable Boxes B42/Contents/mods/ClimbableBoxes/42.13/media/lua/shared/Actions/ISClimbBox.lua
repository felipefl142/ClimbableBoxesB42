require "TimedActions/ISBaseTimedAction"

ISClimbBox = ISBaseTimedAction:derive("ISClimbBox")

function ISClimbBox:new(character, targetSquare, targetBox)
    local o = ISBaseTimedAction.new(self, character)
    o.stopOnWalk = false
    o.stopOnRun = false
    o.maxTime = -1  -- Infinite duration, we control completion via forceComplete()

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
    o.currentState = "start"  -- start -> outcome -> ending -> complete
    o.tickCount = 0
    o.stateStartTick = 0
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
    self.tickCount = self.tickCount + 1

    -- Log once at start to confirm update() is running
    if self.tickCount == 1 then
        print("[ISClimbBox] update() running, state=" .. self.currentState)
    end

    -- STATE: start -> wait ~45 ticks (~0.75s) then compute outcome
    if self.currentState == "start" and not self.outcomeComputed then
        if self.tickCount >= 45 then
            print("[ISClimbBox] Timer: Computing outcome at tick " .. self.tickCount)
            self:computeOutcome()
            self.outcomeComputed = true
            self.currentState = "outcome"
            self.stateStartTick = self.tickCount
        end

    -- STATE: outcome -> wait ~40 ticks (~0.67s) for outcome anim, then teleport + transition to end
    elseif self.currentState == "outcome" then
        if self.tickCount >= self.stateStartTick + 40 then
            if not self.isFail and not self.teleported then
                print("[ISClimbBox] Timer: Teleporting at tick " .. self.tickCount)
                self:teleportPlayer()
                self.teleported = true
            end
            self.currentState = "ending"
            self.stateStartTick = self.tickCount
            print("[ISClimbBox] Timer: Playing end animation at tick " .. self.tickCount)
            self:setActionAnim(self.endAnim)
        end

    -- STATE: ending -> wait ~30 ticks (~0.5s) for end anim, then complete
    elseif self.currentState == "ending" then
        if self.tickCount >= self.stateStartTick + 30 then
            print("[ISClimbBox] Timer: Completing action at tick " .. self.tickCount)
            self:forceComplete()
        end
    end
end

function ISClimbBox:start()
    print("[ISClimbBox] start() called, setting animation: " .. self.startAnim)
    self:setActionAnim(self.startAnim)
    self.tickCount = 0
    self.stateStartTick = 0
    print("[ISClimbBox] Timer-based state machine initialized (tick counter)")
end

function ISClimbBox:stop()
    print("[ISClimbBox] stop() called at tick " .. tostring(self.tickCount) .. ", state=" .. tostring(self.currentState))
    Events.OnClientCommand.Remove(ISClimbBox.OnClientCommandCallback)
    ISBaseTimedAction.stop(self)
end

function ISClimbBox:perform()
    print("[ISClimbBox] perform() called - action complete")
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

-- Animation event handler - dual approach: handle events if they fire (backup to timer)
function ISClimbBox:animEvent(event, parameter)
    print("[ISClimbBox] animEvent: event=" .. tostring(event) .. ", parameter=" .. tostring(parameter) .. ", state=" .. tostring(self.currentState))

    -- If we receive a custom animation event, let it drive the state machine
    -- (This provides faster, animation-synced transitions if events work)
    if event == self.startAnim and parameter == "90" and self.currentState == "start" then
        print("[ISClimbBox] Animation event driving outcome (overriding timer)")
        self:computeOutcome()
        self.outcomeComputed = true
        self.currentState = "outcome"
        self.stateStartTick = self.tickCount

    elseif (event == self.successAnim or event == self.struggleAnim or event == self.failAnim) and self.currentState == "outcome" then
        print("[ISClimbBox] Animation event driving teleport (overriding timer)")
        if not self.isFail and not self.teleported then
            self:teleportPlayer()
            self.teleported = true
        end
        self.currentState = "ending"
        self.stateStartTick = self.tickCount
        self:setActionAnim(self.endAnim)

    elseif event == self.endAnim and self.currentState == "ending" then
        print("[ISClimbBox] Animation event driving completion (overriding timer)")
        self:forceComplete()
    end
end
