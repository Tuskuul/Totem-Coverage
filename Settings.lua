-- WoW Forever friendly totem nameplates: default enabled, user-controllable.
local addonName = ...
local cv = "nameplateShowFriendlyPlayerTotems"
local events = CreateFrame("Frame")
local panel, checkbox, label
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
  local value = get()
  label:SetText(value == nil and "Client nameplate setting unavailable" or
    ("Client nameplates: " .. (value and "Enabled" or "Disabled")))
end
function TotemCoverage_ShowSettings()
  if not panel then
    panel = CreateFrame("Frame", "TotemCoverageSettingsFrame", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(430, 170)
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
    label:SetPoint("TOPLEFT", 26, -100)
    checkbox:SetScript("OnClick", function(self)
      if not TotemCoverageDB then return end
      TotemCoverageDB.showTotemNameplates = self:GetChecked() and true or false
      setPreference()
      refresh()
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
    setPreference()
  elseif TotemCoverageDB and (event == "PLAYER_ENTERING_WORLD" or pending) then
    setPreference()
  end
end)
