local _, ns = ...
local CombatLog = ns:RegisterModule("CombatLog", {})
ns.CombatLog = CombatLog

local playerGUID
local PROC_WINDOW = 0.5
local MIN_PROC_PAIRS = 3
local GRAPH_DECAY = 300
local WINDOW_RESET_THRESHOLD = 120

CombatLog.procGraph = {}
CombatLog.throughput = {
    healGCDs = 0,
    damageGCDs = 0,
    buffCasts = 0,
    dispelCasts = 0,
    totalHealing = 0,
    totalDamage = 0,
    windowStart = 0,
    lastUpdate = 0,
}
CombatLog.pendingDamage = {}

local healSubevents = {
    SPELL_HEAL = true,
    SPELL_PERIODIC_HEAL = true,
}
local damageSubevents = {
    SPELL_DAMAGE = true,
    SPELL_PERIODIC_DAMAGE = true,
}
local castSuccessSubevents = {
    SPELL_CAST_SUCCESS = true,
}
local auraSubevents = {
    SPELL_AURA_APPLIED = true,
    SPELL_AURA_REMOVED = true,
}

local function classifySpell(spellId, spellName)
    if not spellId and not spellName then return nil end
    local intel = ns.HealingIntel or {}
    local role
    if spellId and intel.knownSpellRolesById then
        role = intel.knownSpellRolesById[spellId]
    end
    if not role and spellName and intel.knownSpellRolesByName then
        role = intel.knownSpellRolesByName[string.lower(spellName)]
    end
    if role then
        local healingRoles = intel.healingRoles or {}
        local supportRoles = intel.supportRoles or {}
        if healingRoles[role] then return "heal" end
        if supportRoles[role] then
            if role == "cleanse" then return "dispel" end
            if role == "buff" or role == "support" then return "buff" end
        end
    end
    return "damage"
end

local function updateProcGraph(sourceSpellId, destSpellId, amount)
    if not sourceSpellId or not destSpellId or sourceSpellId == destSpellId then return end
    local node = CombatLog.procGraph[sourceSpellId]
    if not node then
        node = { triggers = {}, totalCasts = 0, lastSeen = 0 }
        CombatLog.procGraph[sourceSpellId] = node
    end
    local edge = node.triggers[destSpellId]
    if not edge then
        edge = { count = 0, totalHealing = 0, lastSeen = 0 }
        node.triggers[destSpellId] = edge
    end
    edge.count = edge.count + 1
    edge.totalHealing = edge.totalHealing + (amount or 0)
    edge.lastSeen = GetTime()
    node.lastSeen = GetTime()
end

local function decayProcGraph()
    local now = GetTime()
    for srcId, node in pairs(CombatLog.procGraph) do
        if now - node.lastSeen > GRAPH_DECAY then
            CombatLog.procGraph[srcId] = nil
        else
            for destId, edge in pairs(node.triggers) do
                if now - edge.lastSeen > GRAPH_DECAY then
                    node.triggers[destId] = nil
                end
            end
        end
    end
end

local function resetThroughput()
    wipe(CombatLog.throughput)
    local t = CombatLog.throughput
    t.healGCDs = 0
    t.damageGCDs = 0
    t.buffCasts = 0
    t.dispelCasts = 0
    t.totalHealing = 0
    t.totalDamage = 0
    t.windowStart = GetTime()
    t.lastUpdate = GetTime()
end

function CombatLog:OnEvent(event, ...)
    if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then
        if event == "PLAYER_REGEN_DISABLED" then
            resetThroughput()
            wipe(self.pendingDamage)
        end
        return
    end

    if not playerGUID then
        playerGUID = UnitGUID("player")
        if not playerGUID then return end
    end

    local timestamp, subevent = ...
    if not subevent then return end

    if healSubevents[subevent] then
        local sourceGUID = select(3, ...)
        local destGUID = select(7, ...)
        local spellId = select(10, ...)
        local spellName = select(11, ...)
        local amount = select(13, ...)

        if sourceGUID == playerGUID and amount and amount > 0 then
            local now = GetTime()
            local pending = self.pendingDamage
            for dmgSpellId, dmgData in pairs(pending) do
                if now - dmgData.time <= PROC_WINDOW then
                    updateProcGraph(dmgSpellId, spellId, amount)
                end
            end

            self.throughput.healGCDs = self.throughput.healGCDs + 1
            self.throughput.totalHealing = self.throughput.totalHealing + amount
            self.throughput.lastUpdate = now
        end

    elseif damageSubevents[subevent] then
        local sourceGUID = select(3, ...)
        local spellId = select(10, ...)
        local amount = select(13, ...)

        if sourceGUID == playerGUID and spellId then
            self.pendingDamage[spellId] = { time = GetTime(), amount = amount or 0 }
            self.throughput.damageGCDs = self.throughput.damageGCDs + 1
            self.throughput.totalDamage = self.throughput.totalDamage + (amount or 0)
            self.throughput.lastUpdate = GetTime()
        end

    elseif castSuccessSubevents[subevent] then
        local sourceGUID = select(3, ...)
        local spellId = select(10, ...)
        local spellName = select(11, ...)

        if sourceGUID == playerGUID then
            local kind = classifySpell(spellId, spellName)
            if kind == "buff" then
                self.throughput.buffCasts = self.throughput.buffCasts + 1
            elseif kind == "dispel" then
                self.throughput.dispelCasts = self.throughput.dispelCasts + 1
            end
            self.throughput.lastUpdate = GetTime()
        end

    elseif auraSubevents[subevent] then
        local sourceGUID = select(3, ...)
        if sourceGUID == playerGUID then
            self.throughput.lastUpdate = GetTime()
        end
    end
end

function CombatLog:GetProcGraph()
    return self.procGraph
end

function CombatLog:GetConfirmedEdges()
    local edges = {}
    for srcId, node in pairs(self.procGraph) do
        for destId, edge in pairs(node.triggers) do
            if edge.count >= MIN_PROC_PAIRS then
                edges[#edges + 1] = {
                    sourceSpellId = srcId,
                    destSpellId = destId,
                    count = edge.count,
                    totalHealing = edge.totalHealing,
                }
            end
        end
    end
    return edges
end

function CombatLog:GetThroughputWindow()
    return self.throughput
end

function CombatLog:GetRoleBehavior()
    local t = self.throughput
    local totalGCDs = t.healGCDs + t.damageGCDs + t.buffCasts + t.dispelCasts
    if totalGCDs == 0 then
        return {
            healGCDShare = 0,
            damageGCDShare = 0,
            damageToHealRatio = 0,
            buffUptimeShare = 0,
            totalGCDs = 0,
        }
    end

    local d2hRatio = 0
    if t.totalDamage > 0 then
        d2hRatio = t.totalHealing / t.totalDamage
        if d2hRatio > 1 then d2hRatio = 1 end
    end

    return {
        healGCDShare = t.healGCDs / totalGCDs,
        damageGCDShare = t.damageGCDs / totalGCDs,
        damageToHealRatio = d2hRatio,
        buffUptimeShare = (t.buffCasts + t.dispelCasts) / totalGCDs,
        totalGCDs = totalGCDs,
    }
end

function CombatLog:HasDamageToHealProc()
    local edges = self:GetConfirmedEdges()
    for _, edge in ipairs(edges) do
        local srcRole = classifySpell(edge.sourceSpellId)
        if srcRole == "damage" then
            local destRole = classifySpell(edge.destSpellId)
            if destRole == "heal" then
                return true, edge.sourceSpellId, edge.destSpellId
            end
        end
    end
    return false
end

function CombatLog:Reset()
    wipe(self.procGraph)
    wipe(self.pendingDamage)
    resetThroughput()
end

function CombatLog:OnInitialize()
    playerGUID = UnitGUID("player")
    resetThroughput()
end

function CombatLog:OnEnable()
    playerGUID = UnitGUID("player")
    if ns.frame then
        ns.frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        ns.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    end
end

local decayTimer = 0
local function OnUpdate(_, elapsed)
    decayTimer = decayTimer + elapsed
    if decayTimer >= 30 then
        decayTimer = 0
        decayProcGraph()
    end
end

local updater = CreateFrame("Frame")
updater:SetScript("OnUpdate", OnUpdate)
