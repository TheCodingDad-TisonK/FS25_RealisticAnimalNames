-- ============================================================================
-- Animal Names Dialog - GUI Controller v2.2.0.0
-- FS25 Realistic Animal Names
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
    self.charCounter = nil
    
    -- State
    self.isOpen = false
    self.originalName = ""
    self.modInstance = target
    
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
    
    -- Get all UI element references safely
    self.nameInput = self:getElement("nameInput")
    self.applyButton = self:getElement("applyButton")
    self.resetButton = self:getElement("resetButton")
    self.cancelButton = self:getElement("cancelButton")
    self.titleText = self:getElement("titleText")
    self.nameLabel = self:getElement("nameLabel")
    self.charCounter = self:getElement("charCounter")
    
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
        
        -- Enable UTF-8 input
        self.nameInput:setValidCharacters("ALL")
    end
    
    -- Apply localization
    self:applyLocalization()
    
    print("[RAN Dialog] Created")
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
    if not self.modInstance or not self.modInstance.i18n then return end
    
    local i18n = self.modInstance.i18n
    
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
    
    -- Focus on text input after a short delay
    self:scheduleFocusInput()
    
    print("[RAN Dialog] Opened")
end

---Schedule focus on input element
function AnimalNamesDialog:scheduleFocusInput()
    if not self.nameInput then return end
    
    local function setFocusDelayed()
        if self.isOpen and self.nameInput then
            FocusManager:setFocus(self.nameInput)
            
            -- Select all text for easy editing
            local text = self.nameInput:getText()
            if text and text ~= "" then
                local len = self:utf8len(text)
                if len > 0 then
                    self.nameInput:setSelection(0, len)
                end
            end
        end
    end
    
    g_currentMission:addUpdateCallback(setFocusDelayed)
end

---UTF-8 string length
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
    
    print("[RAN Dialog] Closed")
end

---Set the animal to name
---@param animal table The animal object
---@param currentName string The current name
function AnimalNamesDialog:setAnimal(animal, currentName)
    self.animal = animal
    self.originalName = currentName or ""
    
    if self.nameInput then
        self.nameInput:setText(currentName or "")
        self:updateCharCounter(currentName or "")
    end
    
    -- Update reset button state
    if self.resetButton then
        self.resetButton:setDisabled(currentName == nil or currentName == "")
    end
    
    -- Update apply button state
    if self.applyButton then
        self.applyButton:setDisabled(true) -- Initially disabled until change
    end
end

---Update character counter
function AnimalNamesDialog:updateCharCounter(text)
    if not self.charCounter then return end
    
    local len = self:utf8len(text)
    local maxLen = 30
    self.charCounter:setText(string.format("%d/%d", len, maxLen))
    
    -- Change color if approaching limit
    if len >= maxLen then
        self.charCounter:setTextColor(1, 0, 0, 1) -- Red
    elseif len >= maxLen - 5 then
        self.charCounter:setTextColor(1, 1, 0, 1) -- Yellow
    else
        self.charCounter:setTextColor(0.8, 0.8, 0.8, 1) -- Gray
    end
end

---Text changed callback
function AnimalNamesDialog:onTextChanged(text)
    self:updateCharCounter(text)
    
    -- Enable apply button only if text changed and not empty?
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

---Apply button clicked
function AnimalNamesDialog:onClickApply()
    if not self:validateState() then return end
    
    local newName = ""
    if self.nameInput then
        newName = self.nameInput:getText() or ""
    end
    
    local success, result = pcall(function()
        return self.modInstance:setAnimalName(self.animal, newName)
    end)
    
    if success and result then
        self:close()
    else
        print("[RAN Dialog] Failed to set animal name")
    end
end

---Reset button clicked
function AnimalNamesDialog:onClickReset()
    if not self:validateState() then return end
    
    local success, result = pcall(function()
        return self.modInstance:resetAnimalName(self.animal)
    end)
    
    if success and result then
        self:close()
    else
        print("[RAN Dialog] Failed to reset animal name")
    end
end

---Cancel button clicked
function AnimalNamesDialog:onClickCancel()
    self:close()
end

---Validate dialog state
function AnimalNamesDialog:validateState()
    if not self.modInstance then
        print("[RAN Dialog] ERROR: No mod instance")
        return false
    end
    
    if not self.animal then
        print("[RAN Dialog] ERROR: No animal selected")
        return false
    end
    
    return true
end

---Handle Enter key press
function AnimalNamesDialog:onEnterPressed()
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
    self.charCounter = nil
    self.animal = nil
    
    DialogElement.delete(self)
    
    print("[RAN Dialog] Deleted")
end