-- ============================================================================
-- Animal Names Dialog - GUI Controller
-- ============================================================================

AnimalNamesDialog = {}
local AnimalNamesDialog_mt = Class(AnimalNamesDialog, DialogElement)

function AnimalNamesDialog.new(target)
    local self = DialogElement.new(target, AnimalNamesDialog_mt)
    
    self.animal = nil
    self.nameInput = nil
    
    return self
end

function AnimalNamesDialog:onCreate(element)
    DialogElement.onCreate(self, element)
    
    -- Get UI element references
    self.nameInput = element:getDescendantByName("nameInput")
    
    -- Set up callbacks
    if self.nameInput then
        self.nameInput.onEnterPressedCallback = self.onClickApply
        self.nameInput.onEscPressedCallback = self.onClickCancel
    end
    
    -- Get buttons
    self.applyButton = element:getDescendantByName("applyButton")
    self.resetButton = element:getDescendantByName("resetButton")
    self.cancelButton = element:getDescendantByName("cancelButton")
    
    -- Set button callbacks
    if self.applyButton then
        self.applyButton.onClickCallback = self.onClickApply
    end
    
    if self.resetButton then
        self.resetButton.onClickCallback = self.onClickReset
    end
    
    if self.cancelButton then
        self.cancelButton.onClickCallback = self.onClickCancel
    end
end

function AnimalNamesDialog:onOpen()
    DialogElement.onOpen(self)
    
    -- Focus on text input
    if self.nameInput then
        FocusManager:setFocus(self.nameInput)
        
        -- Select all text for easy editing
        local text = self.nameInput:getText()
        if text then
            self.nameInput:setSelection(0, string.len(text))
        end
    end
end

function AnimalNamesDialog:onClose()
    DialogElement.onClose(self)
    self.animal = nil
end

function AnimalNamesDialog:setAnimal(animal, currentName)
    self.animal = animal
    
    if self.nameInput then
        self.nameInput:setText(currentName or "")
    end
end

function AnimalNamesDialog:onClickApply()
    if not self.target or not self.animal then
        return
    end
    
    local newName = self.nameInput:getText()
    if self.target.setAnimalName then
        if self.target:setAnimalName(self.animal, newName) then
            self:close()
        end
    end
end

function AnimalNamesDialog:onClickReset()
    if not self.target or not self.animal then
        return
    end
    
    if self.target.resetAnimalName then
        if self.target:resetAnimalName(self.animal) then
            self:close()
        end
    end
end

function AnimalNamesDialog:onClickCancel()
    self:close()
end

function AnimalNamesDialog:onEnterPressed()
    self:onClickApply()
end

function AnimalNamesDialog:onEscPressed()
    self:onClickCancel()
end

function AnimalNamesDialog:onGuiSetupFinished()
    DialogElement.onGuiSetupFinished(self)
    
    -- Center dialog
    self:centerDialog()
end

function AnimalNamesDialog:centerDialog()
    local screenWidth, screenHeight = getScreenMode()
    local dialogWidth, dialogHeight = self.size.width, self.size.height
    
    self:setPosition((screenWidth - dialogWidth) / 2, (screenHeight - dialogHeight) / 2)
end