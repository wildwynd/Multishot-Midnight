Multishot = LibStub("AceAddon-3.0"):NewAddon("Multishot", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

-- ---------------------------------------------------------------------------
-- Keybindings (shown in Esc > Options > Keybindings > AddOns)
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Slash commands
-- /multishot test   -> takes a test screenshot via addon flow
-- /multishot ui     -> toggles UI hide for eligible events (current setting)
-- /multishot wm     -> toggles watermark on/off (overlay)
-- ---------------------------------------------------------------------------
SLASH_MULTISHOT1 = "/multishot"
SLASH_MULTISHOT2 = "/ms"
SlashCmdList["MULTISHOT"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if not Multishot or not Multishot.configDB then
        print("Multishot: not initialized yet.")
        return
    end

    if msg == "test" or msg == "" then
        Multishot:CustomScreenshot("SLASH_TEST")
        print("Multishot: test screenshot fired.")
        return
    end

    if msg == "ui" then
        local v = not Multishot.configDB.global.uihide
        Multishot.configDB.global.uihide = v
        print("Multishot: UI hide set to " .. tostring(v))
        return
    end

    if msg == "wm" or msg == "watermark" or msg == "overlay" then
        local v = not Multishot.configDB.global.watermark
        Multishot.configDB.global.watermark = v
        Multishot:RefreshWatermark(false)
        print("Multishot: watermark (overlay) set to " .. tostring(v))
        return
    end

    print("Multishot commands:")
    print("  /ms test      - take a test screenshot")
    print("  /ms wm        - toggle watermark (overlay)")
    print("  /ms ui        - toggle UI hide")
end

BINDING_HEADER_MULTISHOT = "Multishot"
BINDING_NAME_MULTISHOTSCREENSHOT = "Custom Screenshot"

-- ---------------------------------------------------------------------------
-- Localization (minimal; prevents AceLocale crash if no external locale files are bundled)
-- ---------------------------------------------------------------------------
local AceLocale = LibStub("AceLocale-3.0")
local L = AceLocale:NewLocale("Multishot", "enUS", true)
if L then
    L["timeline"] = "timeline"
    L["Custom screenshot"] = "Custom screenshot"
end
-- Now that at least one locale is registered, this is safe:
L = AceLocale:GetLocale("Multishot")

local isEnabled, isDelayed
local strMatch = string.gsub(FACTION_STANDING_CHANGED, "%%%d?%$?s", "(.+)")
local prefix = "WoWScrnShot_"
local player = (UnitName("player"))
local class = (UnitClass("player"))
local realm = GetRealmName()
local extension, intAlpha, minimapStatus
local timeLineStart, timeLineElapsed


-- ---------------------------------------------------------------------------
-- Startup (DB + Options)
-- ---------------------------------------------------------------------------
function Multishot:OnInitialize()
    -- Config.lua defines RegisterDB() and RegisterMenus()
    if self.RegisterDB then self:RegisterDB() end
    if self.RegisterMenus then self:RegisterMenus() end
end

function Multishot:OnEnable()
    -- Ensure DB is ready even if initialization was interrupted
    if not self.configDB and self.RegisterConfigs then
        self:RegisterConfigs()
    end
    if not self.configDB then
        -- Hard stop: without config DB, later handlers will explode
        return
    end
    self:RegisterEvent("PLAYER_LEVEL_UP")
    -- self:RegisterEvent("UNIT_GUILD_LEVEL")
    self:RegisterEvent("ACHIEVEMENT_EARNED")
    self:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
    self:RegisterEvent("TRADE_ACCEPT_UPDATE")
    self:RegisterEvent("CHAT_MSG_SYSTEM")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    -- self:RegisterEvent("GARISSON_BUILDING_ACTIVATED")
    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("SHOW_LOOT_TOAST_LEGENDARY_LOOTED")
    self:RegisterEvent("ENCOUNTER_END")
    self:RegisterEvent("SCREENSHOT_FAILED", "Debug")
    self:RegisterEvent("ISLAND_COMPLETED") --20250131 Nukme
    -- self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    if self.configDB.global.timeLineEnable then
        self.timeLineTimer = self:ScheduleRepeatingTimer("TimeLineProgress", 5)
        timeLineStart, timeLineElapsed = GetTime(), 0
    end
    local ssformat = GetCVar("screenshotFormat")
    extension = (ssformat == "tga") and ".tga" or (ssformat == "png") and ".png" or ".jpg"
    Multishot.watermarkFrame = Multishot.watermarkFrame or Multishot:CreateWatermark()
    self:RefreshWatermark(false)
end

function Multishot:PLAYER_LEVEL_UP(strEvent)
    if self.configDB.global.levelup then
        self:ScheduleTimer("CustomScreenshot", self.configDB.global.delay1, strEvent)
    end
end

--[[
function Multishot:UNIT_GUILD_LEVEL(strEvent, strUnit)
  if self.configDB.global.guildlevelup and strUnit == "player" then self:ScheduleTimer("CustomScreenshot", self.configDB.global.delay1, strEvent) end
end
--]]
function Multishot:ACHIEVEMENT_EARNED(strEvent, intId)
    if self.configDB.global.guildachievement and select(12, GetAchievementInfo(intId)) then
        self:ScheduleTimer("CustomScreenshot", self.configDB.global.delay1, strEvent)
    end
    if self.configDB.global.achievement and not select(12, GetAchievementInfo(intId)) then
        self:ScheduleTimer("CustomScreenshot", self.configDB.global.delay1, strEvent)
    end
end

function Multishot:TRADE_ACCEPT_UPDATE(strEvent, strPlayer, strTarget)
    if ((strPlayer == 1 and strTarget == 0) or (strPlayer == 0 and strTarget == 1)) and self.configDB.global.trade then
        self:CustomScreenshot(strEvent)
    end
end

function Multishot:CHALLENGE_MODE_COMPLETED(strEvent)
    if not self.configDB.global.challengemode then
        return
    end
    -- hooksecurefunc(ChallengeModeCompleteBanner,"PlayBanner",function()
    --	self:ScheduleTimer("CustomScreenshot", self.configDB.global.delay1, strEvent)
    -- end)
end

function Multishot:ADDON_LOADED(strEvent, subev)
    if not self.configDB.global.mythicpluscompletion then
        return
    end
    if subev == "Blizzard_ChallengesUI" then
        hooksecurefunc(ChallengeModeCompleteBanner, "PlayBanner", function()
            self:ScheduleTimer("CustomScreenshot", self.configDB.global.delay1, subev)
        end)
    else
        return
    end
end

function Multishot:SHOW_LOOT_TOAST_LEGENDARY_LOOTED(strEvent)
    if self.configDB.global.legendaryloot then
        self:ScheduleTimer("CustomScreenshot", self.configDB.global.delay1, strEvent)
    end
end

function Multishot:UPDATE_BATTLEFIELD_STATUS(strEvent)
    if not self.configDB.global.arena or self.configDB.global.battleground then
        return
    end
    local winner = GetBattlefieldWinner()
    if not winner then
        return
    end
    local isArena, registered = IsActiveBattlefieldArena()
    if (isArena) and not self.configDB.global.arena then
        return
    end
    if isArena then
        if IsInArenaTeam() then
            if not PLAYER_FACTION_GROUP[winner] then -- draw, get our screenshot and bail
                self:ScheduleTimer("CustomScreenshot", self.configDB.global.delay1, strEvent)
                return
            end
            local playerTeamId
            for i = 1, GetNumBattlefieldScores() do
                local name, _, _, _, _, teamId = GetBattlefieldScore(i)
                if name == player then
                    playerTeamId = teamId
                    break
                end
            end
            if playerTeamId and playerTeamId == winner then
                self:ScheduleTimer("CustomScreenshot", self.configDB.global.delay1, strEvent)
            end
        end
    else
        if PLAYER_FACTION_GROUP[winner] == GetPlayerFactionGroup() then
            self:ScheduleTimer("CustomScreenshot", self.configDB.global.delay1, strEvent)
        end
    end
end

function Multishot:CHAT_MSG_SYSTEM(strEvent, strMessage)
    if self.configDB.global.repchange then
        if string.match(strMessage, strMatch) then
            self:ScheduleTimer("CustomScreenshot", self.configDB.global.delay1, strEvent)
        end
    end
end

function Multishot:CHAT_MSG_MONSTER_SAY(strEvent, strBuilding, arg2, arg3, arg4, strPlayer)
    if self.configDB.global.timeLineEnable then
        timeLineStart, timeLineElapsed = GetTime(), 0
    end
    if self.configDB and self.configDB.global and self.configDB.global.watermark then

        self:RefreshWatermark(true)

    end

    Screenshot()
    self:UnregisterEvent("CHAT_MSG_MONSTER_SAY")
end

function Multishot:TIME_PLAYED_MSG(strEvent, total, thislevel)
    if self.configDB.global.timeLineEnable then
        timeLineStart, timeLineElapsed = GetTime(), 0
    end
    Screenshot()
    self:UnregisterEvent("TIME_PLAYED_MSG")
end

--[[
function Multishot:GARISSON_BUILDING_ACTIVATED(strEvent, arg1, arg2)
	if self.configDB.global.garissonbuild then
		self:RegisterEvent("CHAT_MSG_MONSTER_SAY")
	end
end
--]]
--[[
function Multishot:COMBAT_LOG_EVENT_UNFILTERED(strEvent, ...)
  local strType, _, sourceGuid, _, _, _, destGuid = select(2, ...) -- 4.1 compat, 4.2 compat
  --local currentId = destGuid and tonumber(destGuid:sub(-16, -12)) -- 6.x
  local currentId = tonumber((select(6, strsplit("-", destGuid))))  -- 7.x
  if strType == "UNIT_DIED" or strType == "PARTY_KILL" then
    local solo, inParty, inRaid
    if IsInRaid() then inRaid = true elseif IsInGroup() then inParty = true else solo = true end
    local _,_,difficultyID = GetInstanceInfo()
    if not (sourceGuid == UnitGUID("player") and self.configDB.global.rares and Multishot.RareID[currentId]) and strType == "PARTY_KILL" then return end
    if not ((solo and self.configDB.global.groupstatus["1solo"]) or (inParty and self.configDB.global.groupstatus["2party"]) or (inRaid and self.configDB.global.groupstatus["3raid"])) then return end
    if difficultyID and not self.configDB.global.difficulty[difficultyID] then return end
    if not (Multishot_dbWhitelist[currentId] or Multishot.BossID[currentId] or Multishot.RareID[currentId]) or Multishot_dbBlacklist[currentId] then return end
    if self.configDB.global.firstkill and Multishot.historyDB.char.history[UnitName("player") .. currentId] then return end
    Multishot.historyDB.char.history[player .. currentId] = true
    isDelayed = currentId  --FLAG
    if UnitIsDead("player") then
      self:PLAYER_REGEN_ENABLED(strType)
    end
  end
end
--]]
-- Debug event created for watermark issues by Nukme@20220504
--[[
function Multishot:COMBAT_LOG_EVENT_UNFILTERED(strEvent)
    if not self.configDB.global.debug then
        return
    else
        local timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName,
            destFlags, destRaidFlags, spellID, _, _, auraType = CombatLogGetCurrentEventInfo()

        if subevent == "SPELL_CAST_SUCCESS" and spellID == 50842 then
            self:ScheduleTimer("CustomScreenshot", self.configDB.global.delay2, subevent .. spellID)
        end
    end
end
]]

function Multishot:PLAYER_REGEN_ENABLED(strEvent)
    if isDelayed then
        self:ScheduleTimer("CustomScreenshot", self.configDB.global.delay2, strEvent .. isDelayed)
        isDelayed = nil
    end
end

function Multishot:ENCOUNTER_END(strEvent, ...)
    if not self.configDB.global.encounter_success then
        return
    end

    local encoutnerID, encounterName, difficultyID, raidsize, endstatus = ...

    if endstatus ~= 1 then
        return
    end

    local solo = false
    local inParty = false
    local inRaid = false
    if IsInRaid() then
        inRaid = true
    elseif IsInGroup() then
        inParty = true
    else
        solo = true
    end

    if inRaid and not self.configDB.global.groupstatus["3raid"] then
        return
    end

    if inParty and not self.configDB.global.groupstatus["2party"] then
        return
    end

    if solo and not self.configDB.global.groupstatus["1solo"] then
        return
    end

    -- if not ((solo and self.configDB.global.groupstatus["1solo"]) or
    --         (inParty and self.configDB.global.groupstatus["2party"]) or
    --         (inRaid and self.configDB.global.groupstatus["3raid"])) then
    --     return
    -- end

    if difficultyID and not self.configDB.global.difficulty[difficultyID] then
        return
    end

    if Multishot_dbBlacklist[encoutnerID] then
        return
    end

    if self.configDB.global.firstkill and Multishot.historyDB.char.history[player .. encoutnerID] then
        return
    end

    Multishot.historyDB.char.history[player .. encoutnerID] = true
    isDelayed = encoutnerID -- FLAG
    if isDelayed then
        self:ScheduleTimer("CustomScreenshot", self.configDB.global.delay2, strEvent .. isDelayed)
        isDelayed = nil
    end
end

function Multishot:ISLAND_COMPLETED(strEvent, ...)
    if not self.configDB.global.island_completed then
        return
    end

    local mapID, winner = ...
    -- print("mapID: " .. mapID .. ", winner: " .. winner)

    self:ScheduleTimer("CustomScreenshot", self.configDB.global.delay2, strEvent .. mapID)
end

function Multishot:SCREENSHOT_SUCCEEDED(strEvent)
    if self.configDB.global.debug then
        self:Print(strEvent)
    end
    local minus1, now, plus1 = date(nil, time() - 1), date(), date(nil, time() + 1)
    local filea = prefix .. minus1:gsub("[/:]", ""):gsub(" ", "_") .. extension
    local fileb = prefix .. now:gsub("[/:]", ""):gsub(" ", "_") .. extension
    local filec = prefix .. plus1:gsub("[/:]", ""):gsub(" ", "_") .. extension
    if not MultishotPlayerScreens then
        MultishotPlayerScreens = {}
    end
    if not MultishotPlayerScreens[player] then
        MultishotPlayerScreens[player] = {}
    end
    tinsert(MultishotPlayerScreens[player], filea)
    tinsert(MultishotPlayerScreens[player], fileb)
    tinsert(MultishotPlayerScreens[player], filec)
    self:UIToggle(true)
    self:RefreshWatermark(false)
    self:UnregisterEvent("SCREENSHOT_SUCCEEDED")
end

-- not sure whether the persistent watermark is caused by this event. put here as a fail-safe.
--[[
function Multishot:SCREENSHOT_FAILED(strEvent)
    if self.configDB.global.debug then
        self:Print(strEvent)
    end
    local minus1, now, plus1 = date(nil, time() - 1), date(), date(nil, time() + 1)
    local filea = prefix .. minus1:gsub("[/:]", ""):gsub(" ", "_") .. extension
    local fileb = prefix .. now:gsub("[/:]", ""):gsub(" ", "_") .. extension
    local filec = prefix .. plus1:gsub("[/:]", ""):gsub(" ", "_") .. extension
    if not MultishotPlayerScreens then
        MultishotPlayerScreens = {}
    end
    if not MultishotPlayerScreens[player] then
        MultishotPlayerScreens[player] = {}
    end
    tinsert(MultishotPlayerScreens[player], filea)
    tinsert(MultishotPlayerScreens[player], fileb)
    tinsert(MultishotPlayerScreens[player], filec)
    self:UIToggle(true)
    self:RefreshWatermark(false)
    self:UnregisterEvent("SCREENSHOT_SUCCEEDED")
	self:UnregisterEvent("SCREENSHOT_FAILED")
end
]]

function Multishot:CreateWatermark()
    local parent = WorldFrame or UIParent
    local f = CreateFrame("Frame", "MultishotWatermark", parent)
    if f.SetIgnoreParentAlpha then f:SetIgnoreParentAlpha(true) end
    f:SetFrameStrata("TOOLTIP")
    f:SetFrameLevel(0)
    f:SetWidth(350)
    f:SetHeight(100)

    f.Text = f:CreateFontString(nil, "OVERLAY")
    if f.Text.SetIgnoreParentAlpha then f.Text:SetIgnoreParentAlpha(true) end
    f.Text:SetShadowOffset(1, -1)

    return f
end

function Multishot:RefreshWatermark(show)
    -- Set Watermark Position
    local anchor = self.configDB.global.watermarkanchor
    Multishot.watermarkFrame:ClearAllPoints()
    Multishot.watermarkFrame:SetPoint(anchor)

    -- Set Watermark Text Position
    Multishot.watermarkFrame.Text:ClearAllPoints()
    Multishot.watermarkFrame.Text:SetPoint("CENTER", Multishot.watermarkFrame, "CENTER")
    Multishot.watermarkFrame.Text:SetJustifyH("CENTER")

    -- Set Watermark Text Font
    Multishot.watermarkFrame.Text:SetFont(self.configDB.global.watermarkfont,
        self.configDB.global.watermarkfontsize, "OUTLINE")

    if show then
        Multishot:ShowWatermark()
    else
        Multishot:HideWatermark()
    end
end

--[[
    Wraps API f:Show() and f:Hide()
]]

function Multishot:ShowWatermark()
    -- Set Text
    local text = self.configDB.global.watermarkformat
    local level = UnitLevel("player")
    local tdate = date()

    -- 20231117 fix for nil zone string
    local zone = " "
    local zone1 = GetRealZoneText()
    local map_id = C_Map.GetBestMapForUnit("player")

    if map_id then
        zone = C_Map.GetMapInfo(map_id).name
    end

    if zone1 then
        zone = zone1
    end

    text = text:gsub("$n", player)
    text = text:gsub("$l", level)
    text = text:gsub("$c", class)
    text = text:gsub("$z", zone)
    text = text:gsub("$r", realm)
    text = text:gsub("$d", tdate)
    text = text:gsub("$b", "\n")

    Multishot.watermarkFrame.Text:SetFormattedText("%s%s%s", YELLOW_FONT_COLOR_CODE, text, FONT_COLOR_CODE_CLOSE)

    -- Brutal Force Show
    local attempt = 0
    while Multishot.watermarkFrame and not Multishot.watermarkFrame:IsShown() and attempt < 100 do
        Multishot.watermarkFrame:Show()
        attempt = attempt + 1
    end

    -- Debug Info
    if self.configDB.global.debug then
        self:Print("WATERMARK_SHOW " .. attempt .. " attempt(s)")
    end
end

function Multishot:HideWatermark()
    -- Set Text to nil
    Multishot.watermarkFrame.Text:SetText("")

    -- Brutal Force Hide
    local attempt = 0
    while Multishot.watermarkFrame and Multishot.watermarkFrame:IsShown() and attempt < 100 do
        Multishot.watermarkFrame:Hide()
        attempt = attempt + 1
    end

    -- Debug Info
    if self.configDB.global.debug then
        self:Print("WATERMARK_HIDE " .. attempt .. " attempt(s)")
    end
end

function Multishot:TimeLineProgress()
    local now = GetTime()
    timeLineStart = timeLineStart or now
    timeLineElapsed = timeLineElapsed or 0
    if UnitIsAFK("player") then
        timeLineStart = now - timeLineElapsed
    else
        timeLineElapsed = now - timeLineStart
    end
    if timeLineElapsed >= (self.configDB.global.delay3 * 60) then
        self:ScheduleTimer("CustomScreenshot", 0.2, L["timeline"])
    end
end

function Multishot:CustomScreenshot(strDebug)
    self:Debug(strDebug)
    self:RegisterEvent("SCREENSHOT_SUCCEEDED")
    if self.configDB.global.charpane and not PaperDollFrame:IsVisible() then
        ToggleCharacter("PaperDollFrame")
        if not PaperDollFrame:IsVisible() then
            self:ScheduleTimer("CustomScreenshot", 0.2, "RETRY")
        end
    end
    if self.configDB.global.close and strDebug ~= "TRADE_ACCEPT_UPDATE" then
        CloseAllWindows()
    end
    if self.configDB.global.uihide and
        (string.find(strDebug, "PLAYER_REGEN_ENABLED") or string.find(strDebug, "UNIT_DIED") or
            string.find(strDebug, "PARTY_KILL") or string.find(strDebug, "CHALLENGE_MODE_COMPLETED") or
            string.find(strDebug, "PLAYER_LEVEL_UP") or string.find(strDebug, L["timeline"]) or
            string.find(strDebug, KEY_BINDING)) then
        self:UIToggle()
    end
    if self.configDB.global.watermark then
        self:RefreshWatermark(true)
    end
    if self.configDB.global.played and
        (
            strDebug == "PLAYER_LEVEL_UP" or strDebug == "ACHIEVEMENT_EARNED" or strDebug == "CHAT_MSG_SYSTEM" or
            strDebug ==
            "CHAT_MSG_MONSTER_SAY" or strDebug == KEY_BINDING) and strDebug ~= "TIME_PLAYED_MSG" then
        self:RegisterEvent("TIME_PLAYED_MSG")
        RequestTimePlayed()
        return
    end
    if self.configDB.global.timeLineEnable then
        timeLineStart, timeLineElapsed = GetTime(), 0
    end
    Screenshot()
    -- if bug still exists, force a delayed watermark hiding here
end

function Multishot:UIToggle(show)
    if not show then
        intAlpha = UIParent:GetAlpha()
        minimapStatus = Minimap:IsShown()
        -- 		if minimapStatus then Minimap:Hide() end -- taints if called in combat
        UIParent:SetAlpha(0)
    else
        -- 		if minimapStatus then Minimap:Show() end
        if intAlpha and intAlpha > 0 then
            UIParent:SetAlpha(intAlpha)
            intAlpha = nil
        else
            UIParent:SetAlpha(1)
        end
    end
end

function Multishot:Debug(strMessage)
    if strMessage == "SCREENSHOT_FAILED" then
        self:UIToggle(true)
        self:RefreshWatermark(false)
    end
    if self.configDB.global.debug then
        self:Print(strMessage)
    end
end

BINDING_HEADER_MULTISHOT = "Multishot"
BINDING_NAME_MULTISHOTSCREENSHOT = L["Custom screenshot"]

--[[
Notes
SetUIVisibility(visible)
]]
