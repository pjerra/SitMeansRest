local CONFIG = {
    DURATION = 20,          -- Seconds to rest
    CHECK_INTERVAL = 500,   -- Check for movement every 500ms
    POLL_INTERVAL = 1000,   -- Check stand-state (X key sit) every 1s
    REGEN_AURA = 25990,     -- Graccu's Mistletoe (Fruitcake effect)
    SIT_EMOTE_ID = 86,      -- TEXT_EMOTE_SIT
    STAND_STATE_SIT = 1,    -- UNIT_STAND_STATE_SIT (ground sit: X key or /sit;
                            -- chair states 2-4 deliberately excluded so bench
                            -- bots don't trigger)

    -- RESTED XP
    -- Sitting still also builds rested XP -- the blue part of the XP bar --
    -- the way an inn does, only fast enough to be worth a break. Ground or
    -- chair, any seat counts here; bots are skipped, so the bench bots the
    -- regen buff avoids are no concern.
    REST_XP_ENABLED = true, -- false turns the whole feature off

    -- Seconds of sitting still before rested XP starts to build. Standing up,
    -- moving or entering combat starts the count again, so a tap of the sit
    -- key between pulls earns nothing.
    REST_XP_DELAY = 30,

    -- How fast it builds: percent of the current level's XP bar per minute.
    -- 5 means a ten-minute break is worth half a level of rested XP. For
    -- scale, an inn gives 5 percent per EIGHT HOURS.
    REST_XP_RATE = 5.0,

    -- Stop building at this many levels' worth of rested XP. The core has its
    -- own ceiling and that one always applies as well: next-level XP times
    -- Rate.Rest.MaxBonus / 2, which at the stock 1.5 is 0.75 of a level --
    -- about fifteen minutes at the default rate. So this only bites when it
    -- is set BELOW the core's; lower it to keep inns worth a visit.
    REST_XP_MAX_LEVELS = 1.5,
}

-- PLAYER_NEXT_LEVEL_XP = UNIT_END + 0x01E7, UNIT_END = OBJECT_END + 0x008E,
-- OBJECT_END = 0x0006 (UpdateFields.h).
local PLAYER_NEXT_LEVEL_XP = 0x0006 + 0x008E + 0x01E7

-- UnitStandStateType seats: ground, chair, low/medium/high chair. Sleeping
-- (3) is not sitting.
local SEATED = { [1] = true, [2] = true, [4] = true, [5] = true, [6] = true }

-- ALE has no Player:SetData/GetData (that's an Eluna-only API and calling it
-- kills the handler mid-run) — rest state lives in this table instead.
-- phase "resting" = buff running; "done" = fully rested but still sitting
-- (blocks an immediate re-trigger until the player stands up).
local rest = {} -- [guidLow] = { x, y, eventId, phase }

-- Rested XP keeps its own record: it outlives the regen buff (which ends
-- after DURATION while the player may sit on for minutes) and it counts
-- chairs, which the buff does not.
local seat = {} -- [guidLow] = { x, y, polls, building, full }
                -- building/full only say which message was last shown

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

local restXPErrorShown = false

-- One poll's worth of rested XP for one player. Called every POLL_INTERVAL
-- for everyone online, so the cheap exits come first.
local function BuildRestedXP(player)
    local g = player:GetGUIDLow()

    -- Player:IsBot is newer than some mod-ale builds (added in #360); a
    -- missing method is nil on the userdata, and then nobody is a bot.
    if not SEATED[player:GetStandState()] or player:IsInCombat()
       or (player.IsBot and player:IsBot()) then
        seat[g] = nil
        return
    end

    local x, y = player:GetLocation()
    local state = seat[g]

    -- New seat, or the seat moved (a chair on a boat, a knockback): the
    -- wait starts over.
    if not state or math.abs(x - state.x) > 0.1 or math.abs(y - state.y) > 0.1 then
        seat[g] = { x = x, y = y, polls = 0 }
        return
    end

    state.polls = state.polls + 1
    if state.polls * CONFIG.POLL_INTERVAL < CONFIG.REST_XP_DELAY * 1000 then
        return
    end

    local nextLevelXP = player:GetUInt32Value(PLAYER_NEXT_LEVEL_XP)
    if not nextLevelXP or nextLevelXP <= 0 then return end

    local before = player:GetRestBonus()
    local ceiling = nextLevelXP * CONFIG.REST_XP_MAX_LEVELS
    local gain = nextLevelXP * (CONFIG.REST_XP_RATE / 100) * (CONFIG.POLL_INTERVAL / 60000)

    if before < ceiling then
        player:SetRestBonus(math.min(before + gain, ceiling))
    end

    -- The core clamps to its own ceiling and to zero at max level, so what
    -- was asked for is not what was given: read it back. No growth means
    -- one ceiling or the other has been reached.
    --
    -- Full is not latched. Rested XP is spent by any XP gained while seated
    -- (a group kill, a quest turned in) and a level-up raises the ceiling,
    -- so every poll asks again and building resumes by itself.
    local after = player:GetRestBonus()
    if after <= before then
        if state.building and not state.full then
            player:SendAreaTriggerMessage("|cff00ff00You are fully rested.|r")
        end
        state.full = true
        return
    end

    if not state.building or state.full then
        player:SendAreaTriggerMessage("|cff00ccffYou begin to feel rested.|r")
    end
    state.building = true
    state.full = false
end

-- X-key sitting sends a stand-state change, not a text emote, so poll for it.
local function PollStandState(eventId, delay, repeats)
    for _, player in ipairs(GetPlayersInWorld()) do
        -- Under pcall: an error here must not abort the loop and take the
        -- regen buff below away from every player after this one.
        if CONFIG.REST_XP_ENABLED then
            local ok, err = pcall(BuildRestedXP, player)
            if not ok and not restXPErrorShown then
                restXPErrorShown = true
                print("SitMeansRest rested XP error: " .. tostring(err))
            end
        end

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
    seat[player:GetGUIDLow()] = nil
end

RegisterPlayerEvent(24, OnEmote)  -- PLAYER_EVENT_ON_TEXT_EMOTE (instant path)
RegisterPlayerEvent(4, OnLogout)  -- PLAYER_EVENT_ON_LOGOUT
CreateLuaEvent(PollStandState, CONFIG.POLL_INTERVAL, 0)
