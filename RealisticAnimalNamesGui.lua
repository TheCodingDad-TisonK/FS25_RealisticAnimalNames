-- =========================================================
-- Realistic Animal Names GUI (FS25)
-- =========================================================

RealisticAnimalNamesGui = {}
local RealisticAnimalNamesGui_mt = Class(RealisticAnimalNamesGui)

function RealisticAnimalNamesGui.new()
    local self = setmetatable({}, RealisticAnimalNamesGui_mt)
    self.screen = nil
    self.currentAnimal = nil
    return self
end

------------------------------------------------------------
-- LOAD & REGISTER GUI (FS25 REQUIRED)
------------------------------------------------------------
function RealisticAnimalNamesGui:load()
    local xmlPath = Utils.getFilename("RealisticAnimalNamesGui.xml", g_currentModDirectory)

    if not fileExists(xmlPath) then
        Logging.error("[RealisticAnimalNames] GUI XML not found: " .. xmlPath)
        return
    end

    g_gui:loadGui(
        xmlPath,
        "RealisticAnimalNamesScreen",
        self
    )

    self.screen = g_gui:getScreen("RealisticAnimalNamesScreen")

    if self.screen == nil then
        Logging.error("[RealisticAnimalNames] Failed to register GUI screen")
        return
    end

    -- Cache elements
    self.nameInput   = self.screen:getDescendantByName("animalNameInput")
    self.applyButton = self.screen:getDescendantByName("applyButton")
    self.resetButton = self.screen:getDescendantByName("resetButton")
    self.toggleNames = self.screen:getDescendantByName("toggleShowNames")

    -- Bind callbacks
    self.applyButton.onClickCallback = function()
        self:onApply()
    end

    self.resetButton.onClickCallback = function()
        self:onReset()
    end

    self.toggleNames.onClickCallback = function(_, isChecked)
        RealisticAnimalNames.showNames = isChecked
    end
end

------------------------------------------------------------
-- OPEN GUI FOR ANIMAL
------------------------------------------------------------
function RealisticAnimalNamesGui:openForAnimal(animal)
    self.currentAnimal = animal

    local name = RealisticAnimalNames.animalNames[animal.id] or ""
    self.nameInput:setText(name)
    self.toggleNames:setIsChecked(RealisticAnimalNames.showNames)

    g_gui:showGui("RealisticAnimalNamesScreen")
end

------------------------------------------------------------
-- APPLY
------------------------------------------------------------
function RealisticAnimalNamesGui:onApply()
    if self.currentAnimal == nil then return end

    local newName = self.nameInput:getText()
    RealisticAnimalNames:setAnimalName(self.currentAnimal, newName)

    g_gui:closeGui()
end

------------------------------------------------------------
-- RESET
------------------------------------------------------------
function RealisticAnimalNamesGui:onReset()
    if self.currentAnimal == nil then return end

    RealisticAnimalNames:resetAnimalName(self.currentAnimal)
    self.nameInput:setText(
        RealisticAnimalNames.animalNames[self.currentAnimal.id] or ""
    )

    g_gui:closeGui()
end
