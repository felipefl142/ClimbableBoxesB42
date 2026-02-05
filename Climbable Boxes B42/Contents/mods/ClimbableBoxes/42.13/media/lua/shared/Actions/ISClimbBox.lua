require "TimedActions/ISBaseTimedAction"

ISClimbBox = ISBaseTimedAction:derive("ISClimbBox")

function ISClimbBox:new(character, targetSquare, targetBox)
    local o = ISBaseTimedAction.new(self, character)
    o.stopOnWalk = false
    o.stopOnRun = false
    o.maxTime = -1  -- Animation-driven

    -- Target info
    o.targetSquare = targetSquare
    o.targetBox = targetBox

    -- Animation names
    o.startAnim = "ClimbBoxStart"
    o.successAnim = "ClimbBoxSuccess"
    o.struggleAnim = "ClimbBoxStruggle"
    o.failAnim = "ClimbBoxFail"
    o.endAnim = "ClimbBoxEnd"

    -- State
    o.isFail = false
    o.isStruggle = false

    return o
end

function ISClimbBox:isValidStart()
    return true
end

function ISClimbBox:isValid()
    return true
end

function ISClimbBox:update()
end

function ISClimbBox:start()
    self:setActionAnim(self.startAnim)
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

-- Animation event handler - drives the state machine
function ISClimbBox:animEvent(event, parameter)
    if event == self.startAnim and parameter == "90" then
        -- At 90% of start animation: determine outcome
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
            self:setActionAnim(self.failAnim)
        elseif self.isStruggle then
            self:setActionAnim(self.struggleAnim)
        else
            self:setActionAnim(self.successAnim)
        end

    elseif event == self.successAnim then
        -- Success animation completed: teleport player to box square
        MovePlayer.Teleport(
            self.character,
            self.targetSquare:getX() + 0.5,
            self.targetSquare:getY() + 0.5,
            self.targetSquare:getZ()
        )
        self:setActionAnim(self.endAnim)

    elseif event == self.struggleAnim then
        -- Struggle animation completed: transition to success (retry)
        self:setActionAnim(self.successAnim)

    elseif event == self.failAnim then
        -- Fail animation completed: go to end
        self:setActionAnim(self.endAnim)

    elseif event == self.endAnim then
        -- End animation completed: finish action
        self:forceComplete()
    end
end
