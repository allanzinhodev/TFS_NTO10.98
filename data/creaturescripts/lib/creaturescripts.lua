-- Utility functions for creature scripts
-- Adds a helper to animate a creature's auto-attack by temporarily changing its outfit.

-- Usage:
-- In a creature event (e.g. onHealthChange) call:
--   if attacker and attacker:isPlayer() then
--     Creature.animateAutoAttack(self, { lookType = 128 }, 200)
--   end

-- Parameters:
--  - creature: Creature object (usually 'self' inside a creature event)
--  - outfit: table with outfit fields (lookType, lookTypeEx, lookHead, lookBody, lookLegs, lookFeet)
--  - durationMs: integer milliseconds to keep the outfit before reverting

local STORAGE_OUTFIT_TOKEN = 2147483645 -- storage key used to track latest outfit change

function Creature.animateAutoAttack(creature, outfit, durationMs)
	if not creature then
		return false
	end

	-- only apply when the creature is alive (basic check)
	if creature.getHealth and creature:getHealth() <= 0 then
		return false
	end

	-- store current outfit so we can revert later
	local oldOutfit = creature:getOutfit() or {}

	-- apply new outfit
	creature:setOutfit(outfit)

	-- create token to avoid reverting from older scheduled events
	local token = math.random(1, 2147483)
	if creature.setStorageValue then
		creature:setStorageValue(STORAGE_OUTFIT_TOKEN, token)
	end

	addEvent(function(cid, token, oldOutfit)
		local c = Creature(cid)
		if not c then
			return
		end

		-- if storage is available, only revert when token matches
		if c.getStorageValue and c:getStorageValue(STORAGE_OUTFIT_TOKEN) ~= token then
			return
		end

		c:setOutfit(oldOutfit)
		if c.setStorageValue then
			c:setStorageValue(STORAGE_OUTFIT_TOKEN, -1)
		end
	end, durationMs, creature:getId(), token, oldOutfit)

	return true
end


-- Example helper wrapper for creature events. You can call this inside
-- `creatureEvent.onHealthChange(self, attacker, ...)` after checking attacker:isPlayer().
-- empty file --
