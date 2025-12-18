-- Auto-attack outfit animation (example)
-- When a player attacks a monster, the monster will briefly change outfit
-- to simulate an auto-attack animation. This example uses lookType = 24.

local creatureEvent = CreatureEvent("AutoAttackOutfit")

function creatureEvent.onHealthChange(self, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
    if not attacker then
        return true
    end

    -- only react when attacked by a player
    if not attacker:isPlayer() then
        return true
    end

    local attackOutfit = { lookType = 24 }
    local durationMs = 200 -- duration in milliseconds

    -- uses the helper in data/creaturescripts/lib/creaturescripts.lua
    if Creature.animateAutoAttack then
        Creature.animateAutoAttack(self, attackOutfit, durationMs)
    else
        -- fallback: directly set outfit and revert after duration
        local oldOutfit = self:getOutfit() or {}
        self:setOutfit(attackOutfit)
        addEvent(function(cid, outfit)
            local c = Creature(cid)
            if not c then return end
            c:setOutfit(outfit)
        end, durationMs, self:getId(), oldOutfit)
    end

    return true
end

creatureEvent:register()
