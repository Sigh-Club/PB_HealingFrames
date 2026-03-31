local _, ns = ...
local RoleInference = ns:RegisterModule("RoleInference", {})
ns.RoleInference = RoleInference

RoleInference.roleVector = { healer = 0, support = 0, dps = 0 }

local function clamp01(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function normalizeKit(sig)
    if not sig then return { heal = 0, hot = 0, shield = 0, d2h = 0, support = 0 } end
    local maxVal = 0
    for _, v in pairs(sig) do
        if v > maxVal then maxVal = v end
    end
    if maxVal == 0 then maxVal = 1 end
    return {
        heal = sig.heal / maxVal,
        hot = sig.hot / maxVal,
        shield = sig.shield / maxVal,
        d2h = sig.d2h / maxVal,
        support = sig.support / maxVal,
    }
end

function RoleInference:Compute()
    local kit = { heal = 0, hot = 0, shield = 0, d2h = 0, support = 0 }
    if ns.BuildState and ns.BuildState.GetKitSignature then
        kit = ns.BuildState:GetKitSignature()
    end
    kit = normalizeKit(kit)

    local beh = {
        healGCDShare = 0,
        damageGCDShare = 0,
        damageToHealRatio = 0,
        buffUptimeShare = 0,
        totalGCDs = 0,
    }
    if ns.CombatLog and ns.CombatLog.GetRoleBehavior then
        beh = ns.CombatLog:GetRoleBehavior()
    end

    local healer = clamp01(
        0.5 * kit.heal
        + 0.3 * kit.support
        + 0.2 * beh.healGCDShare
    )

    if beh.damageToHealRatio > 0.2 then
        healer = clamp01(healer + 0.2)
    end

    if kit.d2h > 0.3 then
        healer = clamp01(healer + 0.1)
    end

    local support = clamp01(
        0.4 * kit.support
        + 0.3 * kit.shield
        + 0.3 * beh.buffUptimeShare
    )

    local dps = clamp01(
        0.6 * beh.damageGCDShare
        + 0.4 * (1 - kit.heal)
    )

    self.roleVector = {
        healer = healer,
        support = support,
        dps = dps,
    }

    PB_HF_Global = PB_HF_Global or {}
    PB_HF_Global.roleVector = {
        healer = healer,
        support = support,
        dps = dps,
    }
end

function RoleInference:GetRoleVector()
    return self.roleVector
end

function RoleInference:IsHealer()
    return self.roleVector.healer >= 0.5
end

function RoleInference:GetPrimaryRole()
    local rv = self.roleVector
    if rv.healer >= rv.support and rv.healer >= rv.dps then return "healer" end
    if rv.support >= rv.dps then return "support" end
    return "dps"
end

function RoleInference:LoadPersisted()
    PB_HF_Global = PB_HF_Global or {}
    local persisted = PB_HF_Global.roleVector
    if persisted and persisted.healer then
        self.roleVector = {
            healer = persisted.healer or 0,
            support = persisted.support or 0,
            dps = persisted.dps or 0,
        }
    end
end

function RoleInference:OnInitialize()
    self:LoadPersisted()
end

function RoleInference:OnEnable()
    self:Compute()
end

function RoleInference:OnEvent(event)
    if event == "PLAYER_REGEN_ENABLED" then
        self:Compute()
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:Compute()
    end
end
