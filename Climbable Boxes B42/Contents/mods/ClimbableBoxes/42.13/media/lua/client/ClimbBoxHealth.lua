require "ClimbBoxConfig"

ClimbBox = ClimbBox or {}

-- Upper body parts (same as Climb mod)
local upperBodyParts = {
    BodyPartType.Hand_L,
    BodyPartType.Hand_R,
    BodyPartType.ForeArm_L,
    BodyPartType.ForeArm_R,
    BodyPartType.UpperArm_L,
    BodyPartType.UpperArm_R,
    BodyPartType.Torso_Upper,
    BodyPartType.Torso_Lower,
}

-- Leg parts (box climbing requires legs)
local legParts = {
    BodyPartType.UpperLeg_L,
    BodyPartType.UpperLeg_R,
    BodyPartType.LowerLeg_L,
    BodyPartType.LowerLeg_R,
    BodyPartType.Foot_L,
    BodyPartType.Foot_R,
}

local function isPartInhibiting(part)
    if part:getFractureTime() > 0.0 then return true end
    if part:isDeepWounded() then return true end
    if part:getHealth() < 50.0 then return true end
    if part:getStiffness() >= 50.0 then return true end
    return false
end

function ClimbBox.isHealthInhibitingClimb(isoPlayer)
    local bodyDamage = isoPlayer:getBodyDamage()
    if not bodyDamage then return false end

    for _, partType in ipairs(upperBodyParts) do
        local part = bodyDamage:getBodyPart(partType)
        if isPartInhibiting(part) then return true end
    end

    for _, partType in ipairs(legParts) do
        local part = bodyDamage:getBodyPart(partType)
        if isPartInhibiting(part) then return true end
    end

    return false
end
