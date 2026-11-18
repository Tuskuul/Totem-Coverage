-- WoW Forever friendly totem nameplates: default enabled, user-controllable.
local addonName = ...
local cv = "nameplateShowFriendlyPlayerTotems"
local events = CreateFrame("Frame")
local panel, checkbox, label, stackedBox, inlineBox, unknownBox
local pending = false
local function get()
  local fn = (C_CVar and C_CVar.GetCVar) or GetCVar
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, cv)
  if not ok or v == nil then return nil end
  return tostring(v) == "1"
end
local function setPreference()
  local db = TotemCoverageDB
  if not db then return end
  if InCombatLockdown and InCombatLockdown() then pending = true; return end
  pending = false
  local want = db.showTotemNameplates ~= false
  if get() == want then return end
  local fn = (C_CVar and C_CVar.SetCVar) or SetCVar
  if type(fn) ~= "function" then return end
  local ok, err = pcall(fn, cv, want and "1" or "0")
  if not ok then print("Totem Coverage: nameplate CVar failed: " .. tostring(err)) end
end
local function refresh()
  if not checkbox then return end
  checkbox:SetChecked(TotemCoverageDB and TotemCoverageDB.showTotemNameplates ~= false)
  local layout = TotemCoverageDB and TotemCoverageDB.nameLayout or "stacked"
  if stackedBox then stackedBox:SetChecked(layout ~= "inline") end
  if inlineBox then inlineBox:SetChecked(layout == "inline") end
  if unknownBox then unknownBox:SetChecked(not TotemCoverageDB or TotemCoverageDB.showUnknownEnemies ~= false) end
  local value = get()
  label:SetText(value == nil and "Client nameplate setting unavailable" or
    ("Client nameplates: " .. (value and "Enabled" or "Disabled")))
end
function TotemCoverage_ShowSettings()
  if not panel then
    panel = CreateFrame("Frame", "TotemCoverageSettingsFrame", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(460, 300)
    panel:SetPoint("CENTER")
    panel:Hide()
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    if panel.TitleText then panel.TitleText:SetText("Totem Coverage Settings") end
    checkbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", 14, -45)
    local caption = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    caption:SetPoint("LEFT", checkbox, "RIGHT", 6, 0)
    caption:SetText("Show friendly totem nameplates (default ON)")
    label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", 26, -95)
    checkbox:SetScript("OnClick", function(self)
      if not TotemCoverageDB then return end
      TotemCoverageDB.showTotemNameplates = self:GetChecked() and true or false
      setPreference()
      refresh()
    end)
    local section = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    section:SetPoint("TOPLEFT", 26, -129)
    section:SetText("Party member name layout")

    local function addOption(y, value, description)
      local control = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
      control:SetPoint("TOPLEFT", 22, y)
      local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
      text:SetPoint("LEFT", control, "RIGHT", 4, 0)
      text:SetText(description)
      control:SetScript("OnClick", function()
        if not TotemCoverageDB then return end
        TotemCoverageDB.nameLayout = value
        refresh()
        if type(TotemCoverage_RefreshDisplay) == "function" then
          TotemCoverage_RefreshDisplay()
        end
      end)
      return control
    end
    stackedBox = addOption(-148, "stacked", "Stacked (one player per line)")
    inlineBox = addOption(-182, "inline", "Inline (names side by side)")
    unknownBox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    unknownBox:SetPoint("TOPLEFT", 22, -222)
    local unknownLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    unknownLabel:SetPoint("LEFT", unknownBox, "RIGHT", 4, 0)
    unknownLabel:SetText("Show observed enemies with unknown debuff status (?)")
    unknownBox:SetScript("OnClick", function(self)
      if not TotemCoverageDB then return end
      TotemCoverageDB.showUnknownEnemies = self:GetChecked() and true or false
      refresh()
      if type(TotemCoverage_RefreshDisplay) == "function" then TotemCoverage_RefreshDisplay() end
    end)
    panel:SetScript("OnShow", refresh)
  end
  if panel:IsShown() then panel:Hide() else refresh(); panel:Show() end
end
pcall(events.RegisterEvent, events, "ADDON_LOADED")
pcall(events.RegisterEvent, events, "PLAYER_ENTERING_WORLD")
pcall(events.RegisterEvent, events, "PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, name)
  if event == "ADDON_LOADED" then
    if name ~= addonName or not TotemCoverageDB then return end
    if TotemCoverageDB.showTotemNameplates == nil then
      TotemCoverageDB.showTotemNameplates = true
    end
    if TotemCoverageDB.nameLayout ~= "inline" then TotemCoverageDB.nameLayout = "stacked" end
    setPreference()
  elseif TotemCoverageDB and (event == "PLAYER_ENTERING_WORLD" or pending) then
    setPreference()
  end
end)
