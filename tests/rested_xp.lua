-- Mock ALE just enough to drive PollStandState.
local poll
local P = { stand = 1, combat = false, bot = false, x = 0, y = 0, bonus = 0, nextxp = 10000, coremax = 15000, msgs = {} }
local player = {}
function player:GetGUIDLow() return 1 end
function player:GetStandState() return P.stand end
function player:IsInCombat() return P.combat end
function player:IsBot() return P.bot end
function player:GetLocation() return P.x, P.y end
function player:GetUInt32Value() return P.nextxp end
function player:GetRestBonus() return P.bonus end
function player:SetRestBonus(v) P.bonus = math.min(v, P.coremax) end
function player:SendAreaTriggerMessage(m) P.msgs[#P.msgs+1] = m end
function player:SendBroadcastMessage() end
function player:AddAura() end
function player:RemoveAura() end
function player:HasAura() return true end
function player:RegisterEvent() return 1 end
function player:RemoveEventById() end
function GetPlayersInWorld() return { player } end
function RegisterPlayerEvent() end
function CreateLuaEvent(f) poll = f end
dofile(arg[1])
local function run(n) for _ = 1, n do poll() end end

run(30); assert(P.bonus == 0, "nothing before the delay: " .. P.bonus)
run(60); local perMin = P.bonus
print(("after 30 s delay + 60 s: %.1f XP  (expect 5%% of 10000 = 500, within one tick)"):format(perMin))
assert(math.abs(perMin - 500) <= 10)
P.x = 5; run(1); local b = P.bonus; run(29); assert(P.bonus == b, "moving restarts the delay")
P.combat = true; run(5); P.combat = false; run(29); assert(P.bonus == b, "combat restarts the delay")
P.bot = true; run(100); assert(P.bonus == b, "bots get nothing"); P.bot = false
P.stand = 2; run(31 + 60); assert(P.bonus > b, "a chair counts")
P.stand = 0; run(1); local c = P.bonus; run(50); assert(P.bonus == c, "standing stops it")
P.stand = 1; run(31 + 60 * 40); print(("after 40 more minutes: %.0f XP (core max %d)"):format(P.bonus, P.coremax))
assert(P.bonus == 15000)
P.nextxp = 10000; P.coremax = 0; P.bonus = 0; P.stand = 0; run(1); P.stand = 1; P.msgs = {}; run(100)
assert(P.bonus == 0 and #P.msgs <= 2, "max level: nothing, and no rested-XP messages")
print("messages seen at max level: " .. table.concat(P.msgs, " | "))
print("ALL OK")
