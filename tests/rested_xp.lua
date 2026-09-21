-- Drives SitMeansRest.lua against a mock ALE.
--   lua tests/rested_xp.lua SitMeansRest.lua
-- The mock's SetRestBonus follows Player::SetRestBonus in the core: zero at
-- max level, clamp to next-level XP * Rate.Rest.MaxBonus / 2.
local SCRIPT = arg[1]
local NEXT_LEVEL_XP_INDEX = 0x0006 + 0x008E + 0x01E7
local BEGIN, FULL = "You begin to feel rested.", "You are fully rested."

local function world(overrides, opts)
    local P = { stand = 1, combat = false, bot = false, x = 0, y = 0, bonus = 0,
                nextxp = 10000, rate = 1.5, maxlevel = false, msgs = {} }
    local player = {}
    function player:GetGUIDLow() return 1 end
    function player:GetStandState() return P.stand end
    function player:IsInCombat() return P.combat end
    function player:IsBot() return P.bot end
    function player:GetLocation() return P.x, P.y end
    function player:GetUInt32Value(index)
        assert(index == NEXT_LEVEL_XP_INDEX, "wrong update field: " .. tostring(index))
        return P.nextxp
    end
    function player:GetRestBonus() return P.bonus end
    function player:SetRestBonus(v)
        if P.maxlevel or v < 0 then v = 0 end
        P.bonus = math.min(v, P.nextxp * P.rate / 2)
    end
    function player:SendAreaTriggerMessage(m) P.msgs[#P.msgs + 1] = m end
    function player:SendBroadcastMessage() end
    function player:AddAura() end
    function player:RemoveAura() end
    function player:HasAura() return true end
    function player:RegisterEvent() return 1 end
    function player:RemoveEventById() end
    if opts and opts.noIsBot then player.IsBot = nil end

    local poll
    local env = setmetatable({
        GetPlayersInWorld = function() return { player } end,
        RegisterPlayerEvent = function() end,
        CreateLuaEvent = function(f) poll = f end,
    }, { __index = _G })

    local f = assert(io.open(SCRIPT)); local src = f:read("*a"); f:close()
    for key, value in pairs(overrides or {}) do
        local n
        src, n = src:gsub("(" .. key .. "%s*=%s*)[%w%.]+", "%1" .. tostring(value), 1)
        assert(n == 1, "no CONFIG key " .. key)
    end
    local chunk
    if setfenv then chunk = assert(loadstring(src, "=" .. SCRIPT)); setfenv(chunk, env)
    else chunk = assert(load(src, "=" .. SCRIPT, "t", env)) end
    chunk()

    P.run = function(n) for _ = 1, n do poll() end end
    P.said = function(text)
        local n = 0
        for _, m in ipairs(P.msgs) do if m:find(text, 1, true) then n = n + 1 end end
        return n
    end
    return P
end

-- delay, then the rate
local P = world()
P.run(30); assert(P.bonus == 0, "nothing before the delay")
P.run(60); assert(math.abs(P.bonus - 500) <= 10, "5% of 10000 in a minute, got " .. P.bonus)
assert(P.said(BEGIN) == 1)

-- the three resets, bots, chairs, sleep, standing
local b
P.x = 5; P.run(1); b = P.bonus; P.run(29); assert(P.bonus == b, "moving restarts the delay")
P.combat = true; P.run(5); P.combat = false; P.run(29); assert(P.bonus == b, "combat restarts the delay")
P.bot = true; P.run(100); assert(P.bonus == b, "bots get nothing"); P.bot = false
P.stand = 3; P.run(100); assert(P.bonus == b, "sleeping is not sitting")
P.stand = 2; P.run(31 + 60); assert(P.bonus > b, "a chair counts")
P.stand = 0; P.run(1); b = P.bonus; P.run(50); assert(P.bonus == b, "standing stops it")

-- the core's ceiling: 0.75 of a level at the stock rate, said once
P.stand = 1; P.msgs = {}; P.run(31 + 60 * 20)
assert(P.bonus == 7500, "core ceiling, got " .. P.bonus)
assert(P.said(FULL) == 1, "full is said once, not every poll")

-- full is not latched: XP spent while seated is rebuilt without standing up
P.bonus = 2000; P.run(60)
assert(P.bonus > 2000, "rebuilds after rested XP is spent while seated")
-- ...and neither is it after a level-up raises the ceiling
P.run(60 * 20); P.nextxp = 20000; b = P.bonus; P.run(60)
assert(P.bonus > b, "rebuilds after a level-up")

-- the script's own ceiling, below the core's
P = world({ REST_XP_MAX_LEVELS = 0.25 })
P.run(31 + 60 * 20); assert(P.bonus == 2500, "script ceiling, got " .. P.bonus)

-- max level: nothing, and not a word about rested XP
P = world(); P.maxlevel = true; P.run(200)
assert(P.bonus == 0 and P.said(BEGIN) == 0 and P.said(FULL) == 0, "max level is silent")

-- the master switch
P = world({ REST_XP_ENABLED = "false" }); P.run(200)
assert(P.bonus == 0 and P.said(BEGIN) == 0, "REST_XP_ENABLED = false")

-- a mod-ale without Player:IsBot must not take the regen buff down with it
P = world(nil, { noIsBot = true }); P.run(31 + 60)
assert(P.bonus > 0, "works without Player:IsBot")

print("rested_xp: all ok")
