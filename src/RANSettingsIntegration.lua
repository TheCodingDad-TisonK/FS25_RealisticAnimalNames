-- ============================================================================
-- Realistic Animal Names - Settings Integration v2.2.0.0
-- Injects mod settings into ESC > Settings > Game Settings
-- Pattern: NPCFavor NPCSettingsIntegration (proven FS25 approach)
-- ============================================================================

RANSettingsIntegration = {}

-- ============================================================================
-- Frame hook — fires when the settings page opens
-- ============================================================================

function RANSettingsIntegration:onFrameOpen()
    -- self = InGameMenuSettingsFrame instance
    if not self.ran_initDone then
        RANSettingsIntegration:addElements(self)

        self.gameSettingsLayout:invalidateLayout()
        if self.updateAlternatingElements then
            self:updateAlternatingElements(self.gameSettingsLayout)
        end
        if self.updateGeneralSettings then
            self:updateGeneralSettings(self.gameSettingsLayout)
        end

        self.ran_initDone = true
        print("[RAN] Settings injected into game settings")
    end

    RANSettingsIntegration:updateUI(self)
end

-- ============================================================================
-- Build UI elements
-- ============================================================================

function RANSettingsIntegration:addElements(frame)
    -- Section header
    local header = TextElement.new()
    header:loadProfile(g_gui:getProfile("fs25_settingsSectionHeader"), true)
    header:setText(g_i18n:getText("ran_setting_section") or "Realistic Animal Names")
    frame.gameSettingsLayout:addElement(header)
    header:onGuiSetupFinished()

    -- Show Animal Names toggle
    frame.ran_showNamesToggle = RANSettingsIntegration:addBinaryOption(
        frame, "onShowNamesChanged",
        g_i18n:getText("ran_setting_showNames") or "Show Animal Names"
    )

    -- Show Details (Type & Age) toggle
    frame.ran_showDetailsToggle = RANSettingsIntegration:addBinaryOption(
        frame, "onShowDetailsChanged",
        g_i18n:getText("ran_setting_showDetails") or "Show Animal Details (Type & Age)"
    )
end

function RANSettingsIntegration:addBinaryOption(frame, callbackName, title)
    local bitMap = BitmapElement.new()
    bitMap:loadProfile(g_gui:getProfile("fs25_multiTextOptionContainer"), true)

    local binaryOption = BinaryOptionElement.new()
    binaryOption.useYesNoTexts = true
    binaryOption:loadProfile(g_gui:getProfile("fs25_settingsBinaryOption"), true)
    binaryOption.target = RANSettingsIntegration
    binaryOption:setCallback("onClickCallback", callbackName)

    local titleElement = TextElement.new()
    titleElement:loadProfile(g_gui:getProfile("fs25_settingsMultiTextOptionTitle"), true)
    titleElement:setText(title)

    bitMap:addElement(binaryOption)
    bitMap:addElement(titleElement)

    binaryOption:onGuiSetupFinished()
    titleElement:onGuiSetupFinished()
    frame.gameSettingsLayout:addElement(bitMap)
    bitMap:onGuiSetupFinished()

    return binaryOption
end

-- ============================================================================
-- Sync UI state from current settings
-- ============================================================================

function RANSettingsIntegration:updateUI(frame)
    if not frame.ran_initDone then return end
    local mod = g_realisticAnimalNames
    if not mod then return end

    if frame.ran_showNamesToggle then
        frame.ran_showNamesToggle:setIsChecked(mod.settings.showNames == true, false, false)
    end
    if frame.ran_showDetailsToggle then
        frame.ran_showDetailsToggle:setIsChecked(mod.settings.showDetails == true, false, false)
    end
end

function RANSettingsIntegration:updateGameSettings()
    -- self = InGameMenuSettingsFrame
    RANSettingsIntegration:updateUI(self)
end

-- ============================================================================
-- Callbacks — fire when the player toggles a setting
-- ============================================================================

function RANSettingsIntegration:onShowNamesChanged(state)
    local value = (state == BinaryOptionElement.STATE_RIGHT)
    if g_realisticAnimalNames then
        g_realisticAnimalNames.settings.showNames = value
    end
    pcall(function()
        g_gameSettings:setValue("ran_showNames", value)
        g_gameSettings:save()
    end)
end

function RANSettingsIntegration:onShowDetailsChanged(state)
    local value = (state == BinaryOptionElement.STATE_RIGHT)
    if g_realisticAnimalNames then
        g_realisticAnimalNames.settings.showDetails = value
    end
    pcall(function()
        g_gameSettings:setValue("ran_showDetails", value)
        g_gameSettings:save()
    end)
end

-- ============================================================================
-- Install hooks at file load time
-- ============================================================================

if InGameMenuSettingsFrame then
    InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(
        InGameMenuSettingsFrame.onFrameOpen,
        RANSettingsIntegration.onFrameOpen
    )

    if InGameMenuSettingsFrame.updateGameSettings then
        InGameMenuSettingsFrame.updateGameSettings = Utils.appendedFunction(
            InGameMenuSettingsFrame.updateGameSettings,
            RANSettingsIntegration.updateGameSettings
        )
    end
end
