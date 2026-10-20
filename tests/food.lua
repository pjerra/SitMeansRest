-- Drives SitMeansRest.lua against a mock ALE: eating and drinking.
--   lua tests/food.lua SitMeansRest.lua
-- The mock follows the core's rule that one food, drink or food-and-drink
-- aura sits on a player at a time: applying one removes the others.
local SCRIPT = arg[1]
local REGEN = 25990
local FOOD, DRINK = 433, 430
local SPECIFIC = { [REGEN] = 21, [FOOD] = 19, [DRINK] = 20, [1459] = 0 } -- 1459: Arcane Intellect

local function world(opts)
    local P = { stand = 0, combat = false, x = 0, y = 0, auras = {}, msgs = {},
                checks = nil, repeats = 0 }
    local function aura(id)
        local a = {}
        function a:GetAuraId() return id end
        function a:GetSpellInfo()
            return { GetSpellSpecific = function() return SPECIFIC[id] end }
        end
        return a
    end
    local function apply(id)
        if SPECIFIC[id] ~= 0 then
            for other in pairs(P.auras) do
                if SPECIFIC[other] ~= 0 then P.auras[other] = nil end
            end
        end
        P.auras[id] = true
    end
    P.eat = function(id) apply(id); P.stand = 1 end
    P.buff = apply

    local player = {}
    function player:GetGUIDLow() return 1 end
    function player:GetStandState() return P.stand end
    function player:IsInCombat() return P.combat end
    function player:IsBot() return false end
    function player:GetLocation() return P.x, P.y end
    function player:GetUInt32Value() return 10000 end
    function player:GetRestBonus() return 0 end
    function player:SetRestBonus() end
    function player:SendAreaTriggerMessage(m) P.msgs[#P.msgs + 1] = m end
    function player:SendBroadcastMessage() end
    function player:AddAura(id) apply(id) end
    function player:RemoveAura(id) P.auras[id] = nil end
    function player:HasAura(id) return P.auras[id] == true end
    function player:GetAuras()
        local list = {}
        for id in pairs(P.auras) do list[#list + 1] = aura(id) end
        return list
    end
    function player:RegisterEvent(f, _, repeats) P.checks = f; P.repeats = repeats; return 1 end
    function player:RemoveEventById() P.checks = nil end
    if opts and opts.noGetAuras then player.GetAuras = nil end

    local poll
    local env = setmetatable({
        GetPlayersInWorld = function() return { player } end,
        RegisterPlayerEvent = function() end,
        CreateLuaEvent = function(f) poll = f end,
        print = function() end,
    }, { __index = _G })

    local f = assert(io.open(SCRIPT)); local src = f:read("*a"); f:close()
    local chunk
    if setfenv then chunk = assert(loadstring(src, "=" .. SCRIPT)); setfenv(chunk, env)
    else chunk = assert(load(src, "=" .. SCRIPT, "t", env)) end
    chunk()

    -- one poll, then the movement check as often as it would run meanwhile
    P.run = function(n)
        for _ = 1, n do
            poll()
            for _ = 1, 2 do
                if P.checks then
                    P.repeats = P.repeats - 1
                    P.checks(1, 500, P.repeats + 1, player)
                end
            end
        end
    end
    P.said = function(text)
        local n = 0
        for _, m in ipairs(P.msgs) do if m:find(text, 1, true) then n = n + 1 end end
        return n
    end
    return P
end

-- eating sits you down; the food stays and the regen buff stays away
local P = world()
P.eat(FOOD); P.run(5)
assert(P.auras[FOOD], "food is not thrown off")
assert(not P.auras[REGEN], "no regen buff while eating")
assert(P.said("Resting") == 0, "nothing said while eating")

-- the meal ends while still seated: the buff does not cut in
P.auras[FOOD] = nil; P.run(5)
assert(not P.auras[REGEN], "no buff until you stand up after eating")

-- stand, sit again with nothing to eat: the buff as before
P.stand = 0; P.run(1); P.stand = 1; P.run(1)
assert(P.auras[REGEN], "plain sitting still rests")

-- a drink taken mid-rest replaces the buff quietly, and the buff stays away
P.msgs = {}
P.eat(DRINK); P.run(5)
assert(P.auras[DRINK] and not P.auras[REGEN], "drink is kept")
assert(P.said("You stand up") == 0, "no 'You stand up.' on drinking")

-- an unrelated buff is not food
P = world(); P.buff(1459); P.stand = 1; P.run(1)
assert(P.auras[REGEN], "an ordinary buff does not block resting")

-- a mod-ale without Unit:GetAuras keeps the old behaviour and does not break
P = world({ noGetAuras = true }); P.stand = 1; P.run(1)
assert(P.auras[REGEN], "works without Unit:GetAuras")

print("food: all ok")
