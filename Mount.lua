--[[----------------------------------------------------------------------------

  LiteMount/Mount.lua

  Information about one mount.

  Copyright 2011 Mike Battersby

----------------------------------------------------------------------------]]--

local _, LM = ...

local L = LM.Localize

-- Rarity data repackaged daily from DataForAzeroth by Sören Gade
--  https://github.com/sgade/MountsRarity
local MountsRarity = LibStub("MountsRarity-2.0")

--@debug@
if LibDebug then LibDebug() end
--@end-debug@

LM.Mount = { }
LM.Mount.__index = LM.Mount

function LM.Mount:new()
    return setmetatable({ }, self)
end

function LM.Mount:Get(className, ...)
    local class = LM[className]

    local m = class:Get(...)
    if not m then return end

    if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
        for familyName, familyMounts in pairs(LM.MOUNTFAMILY) do
            if familyMounts[m.spellID] then
                m.family = familyName
            end
        end

        if not m.family then
            m.family = UNKNOWN
            LM.MOUNTFAMILY["Unknown"][m.spellID] = true
            --@debug@
            LM.PrintError('No family: %s (%d)', m.name, m.spellID)
            --@end-debug@
        end
    end

    return m
end

function LM.Mount:GetFlags()
    return LM.Options:GetMountFlags(self)
end

function LM.Mount:GetGroups()
    return LM.Options:GetMountGroups(self)
end

function LM.Mount:Refresh()
    -- Nothing in base
end

function LM.Mount.FilterToDisplay(f)
    if not f or f == "NONE" then
        return NONE
    elseif f == "FAVORITES" then
        return FAVORITES
    elseif f:sub(1,1) == '~' then
        return string.format(L.LM_NOT_FORMAT, LM.Mount.FilterToDisplay(f:sub(2)))
    elseif f:match('^id:%d+$') then
        local _, id = string.split(':', f, 2)
        return C_MountJournal.GetMountInfoByID(tonumber(id))
    elseif f:match('^family:') then
        local _, family = string.split(':', f, 2)
        return L.LM_FAMILY .. ' : ' .. L[family]
    elseif f:match('^mt:%d+$') then
        local _, id = string.split(':', f, 2)
        return TYPE .. " : " .. ( LM.MOUNT_TYPES[tonumber(id)] or id )
    elseif LM.Options:IsGroup(f) then
        return L.LM_GROUP .. ' : ' .. f
    elseif LM.Options:IsFlag(f) then
        -- XXX LOCALIZE XXX
        return TYPE .. ' : ' .. L[f]
    else
        local n = GetSpellInfo(f)
        if n then return n end
        return DISABLED_FONT_COLOR:WrapTextInColorCode(f)
    end
end

function LM.Mount:MatchesOneFilter(flags, groups, f)
    if f == "" or f == self.name then
        return true
    elseif f == "NONE" then
        return false
    elseif f == "CASTABLE" then
        return self:IsCastable() == true
    elseif f == "COLLECTED" then
        return self.isCollected == true
    elseif f == "MAWUSABLE" then
        return self:MawUsable() == true
    elseif f == "JOURNAL" then
        return self.mountTypeID ~= nil
    elseif f == "FAVORITES" then
        return self.isFavorite == true
    elseif f == "ZONEMATCH" then
        local zone = GetZoneText()
        return self:IsFromZone(zone)
    elseif tonumber(f) then
        return self.spellID == tonumber(f)
    elseif f:sub(1, 3) == 'id:' then
        return self.mountID == tonumber(f:sub(4))
    elseif f:sub(1, 3) == 'mt:' then
        return self.mountTypeID == tonumber(f:sub(4))
    elseif f:sub(1, 7) == 'family:' then
        return ( self.family == f:sub(8) or L[self.family] == f:sub(8) )
    elseif f:sub(1, 1) == '~' then
        return not self:MatchesOneFilter(flags, groups, f:sub(2))
    elseif flags[f] ~= nil then
        return true
    elseif groups[f] ~= nil then
        return true
    end
end

function LM.Mount:MatchesFilterOr(flags, groups, ...)
    local f
    for i = 1, select('#', ...) do
        f = select(i, ...)
        if self:MatchesOneFilter(flags, groups, f) then
            return true
        end
    end
    return false
end

function LM.Mount:MatchesFilterAnd(flags, groups, ...)
    local f
    for i = 1, select('#', ...) do
        f = select(i, ...)
        if type(f) == 'table' then
            if not self:MatchesFilterOr(flags, groups, unpack(f)) then
                return false
            end
        else
            if not self:MatchesFilterOr(flags, groups, f) then
                return false
            end
        end
    end
    return true
end

function LM.Mount:MatchesFilters(...)
    local currentFlags = self:GetFlags()
    local currentGroups = self:GetGroups()
    return self:MatchesFilterAnd(currentFlags, currentGroups, ...)
end

function LM.Mount:FlagsSet(checkFlags)
    for _,f in ipairs(checkFlags) do
        if self.flags[f] == nil then return false end
    end
    return true
end

function LM.Mount:IsActive(buffTable)
    return buffTable[self.spellID]
end

function LM.Mount:IsCastable()
    local castTime = select(4, GetSpellInfo(self.spellID))
    if LM.Environment:IsMovingOrFalling() then
        if castTime > 0 then return false end
    elseif LM.Options:GetOption('instantOnlyMoving') then
        if castTime == 0 then return false end
    end
    return true
end

function LM.Mount:IsCancelable()
    return true
end

function LM.Mount:IsUsable()
    return true
end

function LM.Mount:IsMountable()
    return true
end

function LM.Mount:IsFromZone(zone)
    if self.sourceText then
        zone = zone:gsub('%-', '%%-')
        local source = self.sourceText:gsub("|c........(.-)|r", "%1")
        local zt = ZONE_COLON .. '[^|]+' .. zone
        local lt = LOCATION_COLON .. '[^|]+' .. zone
        return source:find(zt, 1) ~= nil or source:find(lt, 1) ~= nil
    end
end

-- These should probably not be making new identical objects all the time.

function LM.Mount:GetCastAction()
    local spellName = GetSpellInfo(self.spellID)
    return LM.SecureAction:Spell(spellName)
end

function LM.Mount:GetCancelAction()
    local spellName = GetSpellInfo(self.spellID)
    return LM.SecureAction:CancelAura(spellName)
end

function LM.Mount:OnSummon()
    local n = LM.Options:IncrementSummonCount(self)

    if not LM.Options:GetOption('announceViaChat') then return end

    if LM.Options:GetOption('randomWeightStyle') == 'Rarity' then
        local rarity = self:GetRarity()
        rarity = string.format(L.LM_RARITY_FORMAT, rarity or 0)
        LM.Print(L.LM_SUMMON_CHAT_MESSAGE_RARITY, self.name, rarity, n)
    else
        LM.Print(L.LM_SUMMON_CHAT_MESSAGE, self.name, self:GetPriority(), n)
    end
end

function LM.Mount:GetSummonCount()
    return LM.Options:GetSummonCount(self)
end

function LM.Mount:GetPriority()
    return LM.Options:GetPriority(self)
end

function LM.Mount:GetRarity()
    if self.mountID then
        return MountsRarity:GetRarityByID(self.mountID) or 0
    end
end

-- This is gross

local MawUsableSpells = {
    [LM.SPELL.TRAVEL_FORM] = true,
    [LM.SPELL.MOUNT_FORM] = true,
    [LM.SPELL.RUNNING_WILD] = true,
    [LM.SPELL.SOULSHAPE] = true,
    [LM.SPELL.GHOST_WOLF] = true,
    [312762] = true,                -- Mawsworn Soulhunter
    [344578] = true,                -- Corridor Creeper
    [344577] = true,                -- Bound Shadehound
}

function LM.Mount:MawUsable()
    -- The True Maw Walker unlocks all mounts, but the spell (353214) doesn't
    -- seem to return true for IsSpellKnown(). The unlock is not account-wide
    -- so the quest is good enough (for now).

    if C_QuestLog.IsQuestFlaggedCompleted(63994) then
        return true
    else
        return MawUsableSpells[self.spellID]
    end
end

function LM.Mount:Dump(prefix)
    prefix = prefix or ""

    local spellName = GetSpellInfo(self.spellID)

    local currentFlags, defaultFlags = {}, {}
    for f in pairs(self:GetFlags()) do tinsert(currentFlags, f) end
    for f in pairs(self.flags) do tinsert(defaultFlags, f) end
    sort(currentFlags)
    sort(defaultFlags)

    LM.Print("--- Mount Dump ---")
    LM.Print(prefix .. self.name)
    LM.Print(prefix .. " spell: " .. format("%s (id %d)", spellName, self.spellID))
    LM.Print(prefix .. " flags: " ..
             format("%s (default %s)",
                    table.concat(currentFlags, ','),
                    table.concat(defaultFlags, ',')
                   )
            )
    LM.Print(prefix .. " mountID: " .. tostring(self.mountID))
    LM.Print(prefix .. " family: " .. tostring(self.family))
    LM.Print(prefix .. " dragonRiding: " .. tostring(self.dragonRiding))
    LM.Print(prefix .. " isCollected: " .. tostring(self.isCollected))
    LM.Print(prefix .. " isFavorite: " .. tostring(self.isFavorite))
    LM.Print(prefix .. " isFiltered: " .. tostring(self.isFiltered))
    LM.Print(prefix .. " priority: " .. tostring(self:GetPriority()))
    LM.Print(prefix .. " castable: " .. tostring(self:IsCastable()) .. " (spell " .. tostring(IsUsableSpell(self.spellID)) .. ")")
end
