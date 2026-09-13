local CONFIG = {
    DURATION = 20,          -- Seconds to rest
    CHECK_INTERVAL = 500,   -- Check for movement every 500ms
    POLL_INTERVAL = 1000,   -- Check stand-state (X key sit) every 1s
    REGEN_AURA = 25990,     -- Graccu's Mistletoe (Fruitcake effect)
    SIT_EMOTE_ID = 86,      -- TEXT_EMOTE_SIT
    STAND_STATE_SIT = 1,    -- UNIT_STAND_STATE_SIT (ground sit: X key or /sit;
                            -- chair states 2-4 deliberately excluded so bench
                            -- bots don't trigger)
}

-- ALE has no Player:SetData/GetData (that's an Eluna-only API and calling it
-- kills the handler mid-run) — rest state lives in this table instead.
-- phase "resting" = buff running; "done" = fully rested but still sitting
-- (blocks an immediate re-trigger until the player stands up).
local rest = {} -- [guidLow] = { x, y, eventId, phase }

local function StopResting(player, silent)
    local g = player:GetGUIDLow()
    local state = rest[g]
    if not state then
        return
    end
    rest[g] = nil
    if state.eventId then
        player:RemoveEventById(state.eventId)
    end
    player:RemoveAura(CONFIG.REGEN_AURA)
    if not silent then
        player:SendAreaTriggerMessage("You stand up.")
    end
end

local function RestMovementCheck(eventId, delay, repeats, player)
    if not player then
        return
    end

    local g = player:GetGUIDLow()
    local state = rest[g]
    if not state or state.phase ~= "resting" or not player:HasAura(CONFIG.REGEN_AURA) then
        StopResting(player)
        return
    end

    local x, y = player:GetLocation()

    -- Cancel if player moves more than 0.1 yards
    if math.abs(x - state.x) > 0.1 or math.abs(y - state.y) > 0.1 then
        StopResting(player)
        return
    end

    if repeats == 1 then
        state.phase = "done"
        state.eventId = nil
        player:RemoveAura(CONFIG.REGEN_AURA)
        player:SendAreaTriggerMessage("|cff00ff00Fully Rested!|r")
    end
end

local function StartResting(player)
    if player:IsInCombat() then
        player:SendBroadcastMessage("You can't rest while in combat!")
        return
    end

    StopResting(player, true) -- restart cleanly if already resting

    local x, y = player:GetLocation()
    local state = { x = x, y = y, phase = "resting" }
    rest[player:GetGUIDLow()] = state

    player:AddAura(CONFIG.REGEN_AURA, player)
    player:SendAreaTriggerMessage("|cff00ccffResting...|r")

    state.eventId = player:RegisterEvent(RestMovementCheck, CONFIG.CHECK_INTERVAL, CONFIG.DURATION * 2)
end

local function OnEmote(event, player, textEmote, emoteNum, guid)
    if textEmote == CONFIG.SIT_EMOTE_ID then
        StartResting(player)
    end
end

-- X-key sitting sends a stand-state change, not a text emote, so poll for it.
local function PollStandState(eventId, delay, repeats)
    for _, player in ipairs(GetPlayersInWorld()) do
        local sitting = player:GetStandState() == CONFIG.STAND_STATE_SIT
        local state = rest[player:GetGUIDLow()]
        if sitting and not state then
            StartResting(player)
        elseif not sitting and state then
            if state.phase == "done" then
                rest[player:GetGUIDLow()] = nil -- stood up after full rest
            else
                StopResting(player)
            end
        end
    end
end

local function OnLogout(event, player)
    rest[player:GetGUIDLow()] = nil
end

RegisterPlayerEvent(24, OnEmote)  -- PLAYER_EVENT_ON_TEXT_EMOTE (instant path)
RegisterPlayerEvent(4, OnLogout)  -- PLAYER_EVENT_ON_LOGOUT
CreateLuaEvent(PollStandState, CONFIG.POLL_INTERVAL, 0)
