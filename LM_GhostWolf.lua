--[[----------------------------------------------------------------------------

  LiteMount/LM_GhostWolf.lua

  Copyright 2011-2017 Mike Battersby

----------------------------------------------------------------------------]]--

local TABLET_OF_GHOST_WOLF_AURA = GetSpellInfo(168799)

LM_GhostWolf = setmetatable({ }, LM_Spell)
LM_GhostWolf.__index = LM_GhostWolf

function LM_GhostWolf:Flags(v)
    if UnitAura("player", TABLET_OF_GHOST_WOLF_AURA) then
        return LM_FLAG.RUN
    else
        return LM_FLAG.WALK
    end
end

function LM_GhostWolf:Get()
    local m = LM_Spell:Get(LM_SPELL.GHOST_WOLF)
    if m then setmetatable(m, LM_GhostWolf) end
    return m
end
