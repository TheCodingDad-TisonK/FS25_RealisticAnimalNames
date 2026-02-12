-- ============================================================================
-- Animal Names Dialog - GUI Controller
-- FS25 Realistic Animal Names
-- Version: 2.1.0.0
-- ============================================================================
-- COMPLETE REWRITE: Fixed focus, UTF-8, error handling
-- ============================================================================

---@class AnimalNamesDialog
AnimalNamesDialog = {}
AnimalNamesDialog.__index = AnimalNamesDialog
setmetatable(AnimalNamesDialog, { __index = DialogElement })

---Create new dialog instance
---@param target table The mod instance
function AnimalNamesDialog:new(target)
    local self = DialogElement.new(target, AnimalNamesDialog)
    
    -- UI Element references
    self.animal = nil
    self.nameInput = nil
    self.applyButton = nil
    self.resetButton = nil
    self.cancelButton = nil
    self.titleText = nil
    self.nameLabel = nil
    
    -- State
    self.isOpen = false
    self.originalName = ""
    
    -- Pre-bound callbacks for performance
    self._boundOnClickApply = function() self:onClickApply() end
    self._boundOnClickReset = function() self:onClickReset() end
    self._boundOnClickCancel = function() self:onClickCancel() end
    self._boundOnEnterPressed = function() self:onEnterPressed() end
    self._boundOnEscPressed = function() self:onEscPressed() end
    self._boundOnTextChanged = function(text) self:onTextChanged(text) end
    
    return self
end

---Called when GUI element is created
---@param element table The GUI element
function AnimalNamesDialog:onCreate(element)
    DialogElement.onCreate(self, element)
    
    -- Get all UI element references with error checking
    self.nameInput = self:getElement("nameInput")
    self.applyButton = self:getElement("applyButton")
    self.resetButton = self:getElement("resetButton")
    self.cancelButton = self:getElement("cancelButton")
    self.titleText = self:getElement("titleText")
    self.nameLabel = self:getElement("nameLabel")
    
    -- Set up button callbacks
    if self.applyButton then
        self.applyButton:setCallback("onClickCallback", self._boundOnClickApply)
    end
    
    if self.resetButton then
        self.resetButton:setCallback("onClickCallback", self._boundOnClickReset)
    end
    
    if self.cancelButton then
        self.cancelButton:setCallback("onClickCallback", self._boundOnClickCancel)
    end
    
    -- Set up input callbacks
    if self.nameInput then
        self.nameInput:setCallback("onEnterPressedCallback", self._boundOnEnterPressed)
        self.nameInput:setCallback("onEscPressedCallback", self._boundOnEscPressed)
        self.nameInput:setCallback("onTextChangedCallback", self._boundOnTextChanged)
    end
    
    -- Apply localization to dynamic text
    self:applyLocalization()
    
    print("[AnimalNamesDialog] Created")
end

---Safely get an element by name
function AnimalNamesDialog:getElement(name)
    if not self.element then return nil end
    
    local success, element = pcall(function()
        return self.element:getDescendantByName(name)
    end)
    
    if success and element then
        return element
    end
    
    return nil
end

---Apply localization to static UI text
function AnimalNamesDialog:applyLocalization()
    if not self.target or not self.target.i18n then return end
    
    local i18n = self.target.i18n
    
    -- Set title text
    if self.titleText then
        self.titleText:setText(i18n:getText("ran_ui_title"))
    end
    
    -- Set label text
    if self.nameLabel then
        self.nameLabel:setText(i18n:getText("ran_ui_nameLabel"))
    end
    
    -- Set placeholder text
    if self.nameInput then
        self.nameInput:setPlaceholderText(i18n:getText("ran_ui_placeholder"))
    end
    
    -- Set button texts
    if self.applyButton then
        self.applyButton:setText(i18n:getText("ran_button_apply"))
    end
    
    if self.resetButton then
        self.resetButton:setText(i18n:getText("ran_button_reset"))
    end
    
    if self.cancelButton then
        self.cancelButton:setText(i18n:getText("ran_button_cancel"))
    end
end

---Called when dialog is opened
function AnimalNamesDialog:onOpen()
    DialogElement.onOpen(self)
    self.isOpen = true
    
    -- Focus on text input after a short delay to ensure UI is ready
    self:scheduleFocusInput()
    
    print("[AnimalNamesDialog] Opened")
end

---Schedule focus on input element
function AnimalNamesDialog:scheduleFocusInput()
    if not self.nameInput then return end
    
    -- Use timer to defer focus (FS25 needs this sometimes)
    local function setFocusDelayed()
        if self.isOpen and self.nameInput then
            FocusManager:setFocus(self.nameInput)
            
            -- Select all text for easy editing
            local text = self.nameInput:getText()
            if text and text ~= "" then
                -- UTF-8 safe length calculation
                local len = self:utf8len(text)
                if len > 0 then
                    self.nameInput:setSelection(0, len)
                end
            end
        end
    end
    
    g_currentMission:addUpdateCallback(setFocusDelayed)
end

---UTF-8 string length (handles multibyte characters)
function AnimalNamesDialog:utf8len(str)
    if not str then return 0 end
    
    local len = 0
    for _ in string.gmatch(str, "[%z\1-\127\194-\244][\128-\191]*") do
        len = len + 1
    end
    return len
end

---Called when dialog is closed
function AnimalNamesDialog:onClose()
    DialogElement.onClose(self)
    self.isOpen = false
    self.animal = nil
    self.originalName = ""
    
    print("[AnimalNamesDialog] Closed")
end

---Set the animal to name
---@param animal table The animal object
---@param currentName string The current name of the animal
function AnimalNamesDialog:setAnimal(animal, currentName)
    self.animal = animal
    self.originalName = currentName or ""
    
    if self.nameInput then
        self.nameInput:setText(currentName or "")
    end
    
    -- Update animal info if we have additional display
    if self.titleText and animal then
        -- Could show animal type in title
        local title = self.target.i18n:getText("ran_ui_title")
        self.titleText:setText(title)
    end
    
    -- Enable/disable reset button based on whether there's a name
    if self.resetButton then
        self.resetButton:setDisabled(currentName == nil or currentName == "")
    end
end

---Text changed callback
function AnimalNamesDialog:onTextChanged(text)
    -- Enable apply button only if text changed
    if self.applyButton then
        local isChanged = (text ~= self.originalName)
        self.applyButton:setDisabled(not isChanged)
    end
    
    -- Update reset button state
    if self.resetButton then
        local hasName = (text ~= nil and text ~= "")
        self.resetButton:setDisabled(not hasName)
    end
end

---Apply button clicked - save the name
function AnimalNamesDialog:onClickApply()
    if not self:validateState() then return end
    
    local newName = ""
    if self.nameInput then
        newName = self.nameInput:getText() or ""
    end
    
    -- Call the mod's setAnimalName function
    local success, result = pcall(function()
        return self.target:setAnimalName(self.animal, newName)
    end)
    
    if success and result then
        self:close()
    else
        print("[AnimalNamesDialog] Failed to set animal name")
        -- Show error notification
        if self.target.showNotification then
            self.target:showNotification("ran_notification_error", FSBaseMission.INGAME_NOTIFICATION_ERROR)
        end
    end
end

---Reset button clicked - remove the name
function AnimalNamesDialog:onClickReset()
    if not self:validateState() then return end
    
    local success, result = pcall(function()
        return self.target:resetAnimalName(self.animal)
    end)
    
    if success and result then
        self:close()
    else
        print("[AnimalNamesDialog] Failed to reset animal name")
    end
end

---Cancel button clicked - close without saving
function AnimalNamesDialog:onClickCancel()
    self:close()
end

---Validate that dialog has required references
function AnimalNamesDialog:validateState()
    if not self.target then
        print("[AnimalNamesDialog] ERROR: No target mod reference")
        return false
    end
    
    if not self.animal then
        print("[AnimalNamesDialog] ERROR: No animal selected")
        return false
    end
    
    return true
end

---Handle Enter key press
function AnimalNamesDialog:onEnterPressed()
    -- Only trigger if apply button is enabled
    if self.applyButton and not self.applyButton:getDisabled() then
        self:onClickApply()
    end
    return true
end

---Handle Escape key press
function AnimalNamesDialog:onEscPressed()
    self:onClickCancel()
    return true
end

---Called after GUI setup is finished
function AnimalNamesDialog:onGuiSetupFinished()
    DialogElement.onGuiSetupFinished(self)
    
    -- Final localization pass
    self:applyLocalization()
end

---Clean up resources
function AnimalNamesDialog:delete()
    -- Remove callbacks to prevent memory leaks
    self._boundOnClickApply = nil
    self._boundOnClickReset = nil
    self._boundOnClickCancel = nil
    self._boundOnEnterPressed = nil
    self._boundOnEscPressed = nil
    self._boundOnTextChanged = nil
    
    self.nameInput = nil
    self.applyButton = nil
    self.resetButton = nil
    self.cancelButton = nil
    self.titleText = nil
    self.nameLabel = nil
    self.animal = nil
    
    DialogElement.delete(self)
    
    print("[AnimalNamesDialog] Deleted")
end