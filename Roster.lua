local _, ns = ...
local Roster = ns:RegisterModule("Roster", {})
ns.Roster = Roster

Roster.entries = {}

local testNames = {
    "Valawrath", "Thibodeauxz", "Aurelia", "Kargan", "Mistfen", "Cinderleaf", "Solenne", "Rimepaw",
    "Ashmantle", "Duskwhisper", "Goldhorn", "Lunessa", "Brightshield", "Mournroot", "Stormveil", "Hollowmere",
    "Sunwarden", "Emberwake", "Ravenmend", "Tidecaller", "Gloomvine", "Lightspire", "Frostmire", "Wildbloom",
    "Stonebind", "Dawnpetal", "Nightquill", "Ironbark", "Starward", "Sablemist", "Wispheart", "Netherdew",
    "Moonquartz", "Gravewillow", "Skydrift", "Thornwatch", "Silverreed", "Auricvale", "Dreamfen", "Brassroot"
}

local function buildLiveList()
    wipe(Roster.entries)
    if UnitInRaid("player") then
        for i = 1, GetNumRaidMembers() do
            local _, _, subgroup = GetRaidRosterInfo(i)
            table.insert(Roster.entries, { unit = "raid"..i, group = subgroup, fake = false })
        end
    elseif GetNumPartyMembers() > 0 then
        table.insert(Roster.entries, { unit = "player", group = 1, fake = false })
        for i = 1, GetNumPartyMembers() do
            table.insert(Roster.entries, { unit = "party"..i, group = 1, fake = false })
        end
    else
        table.insert(Roster.entries, { unit = "player", group = 1, fake = false })
    end
end

local function buildFakeList(size)
    wipe(Roster.entries)
    local debuffTypes = { "Magic", "Curse", "Poison", "Disease" }
    for i = 1, size do
        table.insert(Roster.entries, {
            unit = nil,
            name = testNames[i] or ("Player"..i),
            group = math.floor((i-1)/5) + 1,
            fake = true,
            classToken = ({"PRIEST", "PALADIN", "SHAMAN", "DRUID", "MAGE", "WARLOCK", "ROGUE", "WARRIOR"})[(i-1)%8 + 1],
            fakeDebuff = (i % 4 == 0) and debuffTypes[(i/4)%4 + 1] or nil
        })
    end
end

function Roster:Refresh()
    if ns.DB.frame.fakeMode then buildFakeList(ns.DB.frame.fakeSize or 10) else buildLiveList() end
    if ns.Frames then ns.Frames:ApplyLayout() end
end

function Roster:SetFakeMode(enabled, size)
    ns.DB.frame.fakeMode = enabled
    ns.DB.frame.fakeSize = size or 10
    self:Refresh()
end

function Roster:OnEnable()
    self:Refresh()
end

function Roster:OnEvent(event)
    if event == "PLAYER_ENTERING_WORLD" or event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        if not ns.DB.frame.fakeMode then self:Refresh() end
    end
end
