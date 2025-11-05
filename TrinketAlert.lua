-- TrinketAlert v2 (robust UnitDebuff handling, toggles, /trinkettest)
local TRINKET_SLOT = 13 -- upper trinket
local lastAlert = 0
local RAID_ENABLED = true
local YELL_ENABLED = true
local ALERT_THROTTLE = 3 -- seconds between alerts
local POLL_INTERVAL = 0.5

-- Map icon-token or partial icon path -> friendly name
local TARGET_DEBUFF_ICONS = {
    ["Spell_Nature_StarFall"] = "Moonfire",
    ["Spell_Shadow_ShadowWordDominate"] = "Charming Presence",
    -- you can also put the full path keys if you like:
    -- ["Interface\\Icons\\Spell_Nature_StarFall"] = "Moonfire",
}

-- util debug
local function debug(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TrinketAlert]|r " .. tostring(msg))
end

local function GetTrinketCooldown()
    local start, duration, enable = GetInventoryItemCooldown("player", TRINKET_SLOT)
    if enable == 1 and start > 0 and duration > 1.5 then
        return (start + duration) - GetTime()
    end
    return 0
end

-- Robust UnitDebuff handling:
-- UnitDebuff can return (texture) OR (name, texture, ...) depending on client.
-- This function extracts the texture reliably and compares against keys in TARGET_DEBUFF_ICONS.
local function HasTargetDebuff()
    for i = 1, 40 do
        -- Try reading common return patterns. We don't rely on specific order.
        local a, b, c, d, e, f = UnitDebuff("player", i)
        if not a and not b then break end

        local texture = nil
        -- case 1: API returns only texture as first value (common in some vanilla builds)
        if type(a) == "string" and string.find(a, "Interface") then
            texture = a
        end
        -- case 2: API returns name as first, texture as second
        if not texture and type(b) == "string" and string.find(b, "Interface") then
            texture = b
        end
        -- case 3: some servers report icon token without full path, e.g. "Spell_Nature_StarFall"
        if not texture then
            if type(a) == "string" and string.find(a, "Spell_") then
                texture = a
            elseif type(b) == "string" and string.find(b, "Spell_") then
                texture = b
            end
        end

        if texture then
            -- Normalize: use backslashes for comparisons
            local texLower = tostring(texture)

            -- Check all keys in TARGET_DEBUFF_ICONS; allow partial matches (token or path)
            for key, debName in pairs(TARGET_DEBUFF_ICONS) do
                if type(key) == "string" then
                    if string.find(texLower, key, 1, true) or string.find(key, texLower, 1, true) then
                        return true, debName
                    end
                end
            end
        end
    end
    return false
end

-- Alert logic (polling)
local lastPoll = 0
local lastSent = 0
local wasTriggered = false

local frame = CreateFrame("Frame")
frame:SetScript("OnUpdate", function()
    local now = GetTime()
    if now - lastPoll < POLL_INTERVAL then return end
    lastPoll = now

    local hasDebuff, debuffName = HasTargetDebuff()
    local cd = GetTrinketCooldown()

    if hasDebuff and cd > 0 then
        if (not wasTriggered) or (now - lastSent >= ALERT_THROTTLE) then
            local msg = string.format("Trinket on cooldown and debuffed by %s!", debuffName or "unknown")
            if RAID_ENABLED and UnitInRaid("player") then
                SendChatMessage(msg, "RAID")
            elseif RAID_ENABLED and UnitInParty("player") then
                -- not in raid but RAID was enabled: fallback to party if present
                SendChatMessage(msg, "PARTY")
            end
            if YELL_ENABLED then
                SendChatMessage(msg, "YELL")
            end
            debug("Alert sent: " .. msg)
            lastSent = now
            wasTriggered = true
        end
    else
        wasTriggered = false
    end
end)

-- Slash toggles
SLASH_TRINKETRAID1 = "/trinketraid"
SlashCmdList["TRINKETRAID"] = function()
    RAID_ENABLED = not RAID_ENABLED
    debug("RAID messages " .. (RAID_ENABLED and "ENABLED" or "DISABLED"))
end

SLASH_TRINKETYELL1 = "/trinketyell"
SlashCmdList["TRINKETYELL"] = function()
    YELL_ENABLED = not YELL_ENABLED
    debug("YELL messages " .. (YELL_ENABLED and "ENABLED" or "DISABLED"))
end

-- manual test trigger
SLASH_TRINKETTEST1 = "/trinkettest"
SlashCmdList["TRINKETTEST"] = function()
    local msg = "Trinket on cooldown and debuffed! (test)"
    if RAID_ENABLED and UnitInRaid("player") then
        SendChatMessage(msg, "RAID")
    elseif RAID_ENABLED and UnitInParty("player") then
        SendChatMessage(msg, "PARTY")
    end
    if YELL_ENABLED then
        SendChatMessage(msg, "YELL")
    end
    debug("Test alert sent.")
end

debug("TrinketAlert loaded. Use /trinketraid, /trinketyell and /trinkettest.")
