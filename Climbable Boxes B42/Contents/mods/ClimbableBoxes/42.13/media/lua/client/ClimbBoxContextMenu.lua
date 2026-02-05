require "ClimbBoxConfig"
require "ClimbBoxHealth"

ClimbBox = ClimbBox or {}

local function onClimbBox(player, targetSquare, targetBox)
    ISTimedActionQueue.add(ISClimbBox:new(player, targetSquare, targetBox))
end

local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    if player:hasTimedActions() then return end

    for _, obj in ipairs(worldobjects) do
        if ClimbBox.isClimbableBox(obj) then
            local square = obj:getSquare()
            if square then
                local pSquare = player:getSquare()
                if pSquare and ClimbBox.isAdjacent(pSquare, square) then
                    -- Health check (if enabled)
                    if SandboxVars.ClimbableBoxes.EnableHealthCheck then
                        if ClimbBox.isHealthInhibitingClimb(player) then
                            break
                        end
                    end

                    context:addOption(
                        getText("ContextMenu_ClimbBox"),
                        player, onClimbBox, square, obj
                    )
                    break
                end
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
