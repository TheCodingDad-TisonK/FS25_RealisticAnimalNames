-- ============================================================================
-- Animal Names Dialog - GUI Controller
-- ============================================================================

AnimalNamesDialog = {}
local AnimalNamesDialog_mt = Class(AnimalNamesDialog, DialogElement)

---Create new dialog instance
---@param target table The mod instance
function AnimalNamesDialog.new(target)
    local self = DialogElement.new(target, AnimalNamesDialog_mt)
    
    self.animal = nil
    self.nameInput = nil
    self.applyButton = nil
    self.resetButton = nil
    self.cancelButton = nil
    
    -- Bind callbacks to self (critical for proper function calls)
    self.onClickApplyBound = function() self:onClickApply() end
    self.onClickResetBound = function() self:onClickReset() end
    self.onClickCancelBound = function() self:onClickCancel() end
    
    return self
end

---Called when GUI element is created
---@param element table The GUI element
function AnimalNamesDialog:onCreate(element)
    DialogElement.onCreate(self, element)
    
    -- Get UI element references
    self.nameInput = element:getDescendantByName("nameInput")
    
    -- Get buttons
    self.applyButton = element:getDescendantByName("applyButton")
    self.resetButton = element:getDescendantByName("resetButton")
    self.cancelButton = element:getDescendantByName("cancelButton")
    
    -- Set button callbacks with proper binding
    if self.applyButton then
        self.applyButton:setCallback("onClickCallback", self.onClickApplyBound)
    end
    
    if self.resetButton then
        self.resetButton:setCallback("onClickCallback", self.onClickResetBound)
    end
    
    if self.cancelButton then
        self.cancelButton:setCallback("onClickCallback", self.onClickCancelBound)
    end
    
    -- Set input callbacks
    if self.nameInput then
        self.nameInput:setCallback("onEnterPressedCallback", function() self:onClickApply() end)
        self.nameInput:setCallback("onEscPressedCallback", function() self:onClickCancel() end)
    end
end

---Called when dialog is opened
function AnimalNamesDialog:onOpen()
    DialogElement.onOpen(self)
    
    -- Focus on text input
    if self.nameInput then
        FocusManager:setFocus(self.nameInput)
        
        -- Select all text for easy editing
        local text = self.nameInput:getText()
        if text and text ~= "" then
            self.nameInput:setSelection(0, string.len(text))
        end
    end
end

---Called when dialog is closed
function AnimalNamesDialog:onClose()
    DialogElement.onClose(self)
    self.animal = nil
end

---Set the animal to name
---@param animal table The animal object
---@param currentName string The current name of the animal
function AnimalNamesDialog:setAnimal(animal, currentName)
    self.animal = animal
    
    if self.nameInput then
        self.nameInput:setText(currentName or "")
    end
end

---Apply button clicked - save the name
function AnimalNamesDialog:onClickApply()
    if not self.target or not self.animal then
        print("AnimalNamesDialog: Cannot apply - missing target or animal")
        return
    end
    
    local newName = ""
    if self.nameInput then
        newName = self.nameInput:getText() or ""
    end
    
    -- Call the mod's setAnimalName function
    if self.target.setAnimalName then
        if self.target:setAnimalName(self.animal, newName) then
            self:close()
        end
    else
        print("AnimalNamesDialog: setAnimalName function not found on target")
    end
end

---Reset button clicked - remove the name
function AnimalNamesDialog:onClickReset()
    if not self.target or not self.animal then
        print("AnimalNamesDialog: Cannot reset - missing target or animal")
        return
    end
    
    -- Call the mod's resetAnimalName function
    if self.target.resetAnimalName then
        if self.target:resetAnimalName(self.animal) then
            self:close()
        end
    else
        print("AnimalNamesDialog: resetAnimalName function not found on target")
    end
end

---Cancel button clicked - close without saving
function AnimalNamesDialog:onClickCancel()
    self:close()
end

---Handle Enter key press
function AnimalNamesDialog:onEnterPressed()
    self:onClickApply()
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
end