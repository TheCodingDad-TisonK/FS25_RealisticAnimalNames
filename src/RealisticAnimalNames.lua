-- ============================================================================
-- Realistic Animal Names for FS25
-- ============================================================================
-- Version: 2.0.0.0
-- Author: YourName
-- Description: Add custom names to animals with floating name tags
-- ============================================================================

RealisticAnimalNames = {}

local RealisticAnimalNames_mt = Class(RealisticAnimalNames)

---Initialize the mod
function RealisticAnimalNames.new(mission, modDirectory, modName, i18n, gui, inputManager, messageCenter)
    local self = setmetatable({}, RealisticAnimalNames_mt)

    self.mission = mission
    self.modDirectory = modDirectory
    self.modName = modName
    self.i18n = i18n
    self.gui = gui
    self.inputManager = inputManager
    self.messageCenter = messageCenter

    -- Data storage
    self.animalNames = {}
    self.originalNames = {}
    
    -- Settings (will be loaded from game settings)
    self.showNames = true
    self.nameDistance = 15
    self.nameHeight = 1.8
    self.fontSize = 0.018

    -- UI
    self.dialog = nil
    self.currentAnimal = nil
    
    -- State
    self.isInitialized = false
    self.actionEventId = nil

    return self
end

---Called on mission load
function RealisticAnimalNames:onMissionLoaded(mission)
    if mission:getIsServer() then
        -- Load settings from game settings
        self:loadSettings()
        
        -- Load saved animal names
        self:loadFromSavegame()
        
        -- Register input action
        self:registerInputActions()
        
        -- Create and load GUI
        self:loadGUI()
        
        self.isInitialized = true
        
        -- Welcome notification
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_INFO,
            self.i18n:getText("ran_notification_loaded")
        )
    end
end

---Load settings from game settings system
function RealisticAnimalNames:loadSettings()
    if g_gameSettings then
        self.showNames = g_gameSettings:getValue("showNames")
        self.nameDistance = g_gameSettings:getValue("nameDistance")
        self.nameHeight = g_gameSettings:getValue("nameHeight")
        self.fontSize = g_gameSettings:getValue("fontSize")
    end
end

---Register input actions for FS25
function RealisticAnimalNames:registerInputActions()
    local _, actionEventId = self.inputManager:registerActionEvent(
        InputAction.RAN_OPEN_UI,
        self,
        self.onOpenUIInput,
        false,
        true,
        false,
        true
    )
    
    self.actionEventId = actionEventId
    
    if actionEventId then
        self.inputManager:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
        self.inputManager:setActionEventActive(actionEventId, true)
    end
end

---Load the GUI dialog
function RealisticAnimalNames:loadGUI()
    local xmlFilename = self.modDirectory .. "gui/AnimalNamesDialog.xml"
    
    self.dialog = g_gui:loadGui(
        xmlFilename,
        "AnimalNamesDialog",
        AnimalNamesDialog.new(self)
    )
end

---Input callback - open UI near animal
function RealisticAnimalNames:onOpenUIInput(_, inputValue)
    if inputValue ~= 1 then
        return
    end
    
    if not self.isInitialized then
        return
    end
    
    local animal = self:getClosestAnimal(self.nameDistance)
    
    if animal then
        self:openDialogForAnimal(animal)
    else
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_INFO,
            self.i18n:getText("ran_notification_noAnimal")
        )
    end
end

---Open the naming dialog for a specific animal
function RealisticAnimalNames:openDialogForAnimal(animal)
    if not self.dialog then
        return
    end
    
    self.currentAnimal = animal
    
    local currentName = self.animalNames[animal.id] or ""
    
    self.dialog:setAnimal(animal, currentName)
    g_gui:showDialog("AnimalNamesDialog")
end

---Find the closest animal to the camera
function RealisticAnimalNames:getClosestAnimal(maxDistance)
    if not self.mission.animalSystem then
        return nil
    end
    
    local camera = getCamera()
    if not camera then
        return nil
    end
    
    local camX, camY, camZ = getWorldTranslation(camera)
    local closestAnimal = nil
    local closestDistance = maxDistance
    
    for _, cluster in pairs(self.mission.animalSystem.clusters) do
        if cluster.animals then
            for _, animal in pairs(cluster.animals) do
                if animal and animal.nodeId and entityExists(animal.nodeId) then
                    local x, y, z = getWorldTranslation(animal.nodeId)
                    local distance = MathUtil.vector3Length(camX - x, camY - y, camZ - z)
                    
                    if distance < closestDistance then
                        closestDistance = distance
                        closestAnimal = animal
                    end
                end
            end
        end
    end
    
    return closestAnimal
end

---Set an animal's name
function RealisticAnimalNames:setAnimalName(animal, name)
    if not animal or not animal.id then
        return
    end
    
    -- Store original name if not already stored
    if not self.originalNames[animal.id] then
        self.originalNames[animal.id] = self.animalNames[animal.id]
    end
    
    -- Set new name
    if name and name ~= "" then
        self.animalNames[animal.id] = name
        
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_OK,
            string.format(self.i18n:getText("ran_notification_nameSet"), name)
        )
    else
        self.animalNames[animal.id] = nil
    end
    
    -- Save immediately
    self:saveToSavegame()
end

---Reset an animal's name
function RealisticAnimalNames:resetAnimalName(animal)
    if not animal or not animal.id then
        return
    end
    
    self.animalNames[animal.id] = self.originalNames[animal.id]
    
    g_currentMission:addIngameNotification(
        FSBaseMission.INGAME_NOTIFICATION_OK,
        self.i18n:getText("ran_notification_nameReset")
    )
    
    -- Save immediately
    self:saveToSavegame()
end

---Draw floating names above animals
function RealisticAnimalNames:draw()
    if not self.showNames then
        return
    end
    
    if not self.mission.animalSystem then
        return
    end
    
    local camera = getCamera()
    if not camera then
        return
    end
    
    local camX, camY, camZ = getWorldTranslation(camera)
    
    for _, cluster in pairs(self.mission.animalSystem.clusters) do
        if cluster.animals then
            for _, animal in pairs(cluster.animals) do
                if animal and animal.nodeId and entityExists(animal.nodeId) then
                    local name = self.animalNames[animal.id]
                    
                    if name then
                        local x, y, z = getWorldTranslation(animal.nodeId)
                        local distance = MathUtil.vector3Length(camX - x, camY - y, camZ - z)
                        
                        -- Only draw if within distance
                        if distance <= self.nameDistance then
                            y = y + self.nameHeight
                            self:renderTextAtWorldPosition(name, x, y, z, distance)
                        end
                    end
                end
            end
        end
    end
end

---Render text at world position with distance-based scaling
function RealisticAnimalNames:renderTextAtWorldPosition(text, x, y, z, distance)
    local sx, sy, sz = project(x, y, z)
    
    if sz <= 1 then
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
        setTextBold(true)
        setTextColor(1, 1, 1, 1)
        
        -- Scale font size based on distance
        local scale = 1.0 - (distance / self.nameDistance) * 0.5
        local fontSize = self.fontSize * scale
        
        renderText(sx, sy, fontSize, text)
        
        setTextBold(false)
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
    end
end

---Get savegame file path
function RealisticAnimalNames:getSavegamePath()
    if self.mission.missionInfo and self.mission.missionInfo.savegameDirectory then
        return self.mission.missionInfo.savegameDirectory .. "/realisticAnimalNames.xml"
    end
    return nil
end

---Save animal names to savegame XML
function RealisticAnimalNames:saveToSavegame()
    local filename = self:getSavegamePath()
    if not filename then
        return
    end
    
    local xmlFile = XMLFile.create("animalNamesXML", filename, "animalNames")
    if not xmlFile then
        return
    end
    
    -- Save settings
    xmlFile:setValue("animalNames#showNames", self.showNames)
    xmlFile:setValue("animalNames#nameDistance", self.nameDistance)
    xmlFile:setValue("animalNames#nameHeight", self.nameHeight)
    xmlFile:setValue("animalNames#fontSize", self.fontSize)
    
    -- Save animal names
    local index = 0
    for animalId, name in pairs(self.animalNames) do
        local key = string.format("animalNames.animal(%d)", index)
        xmlFile:setValue(key .. "#id", animalId)
        xmlFile:setValue(key .. "#name", name)
        index = index + 1
    end
    
    xmlFile:save()
    xmlFile:delete()
end

---Load animal names from savegame XML
function RealisticAnimalNames:loadFromSavegame()
    local filename = self:getSavegamePath()
    if not filename or not fileExists(filename) then
        return
    end
    
    local xmlFile = XMLFile.load("animalNamesXML", filename)
    if not xmlFile then
        return
    end
    
    -- Load settings (override defaults if present)
    self.showNames = xmlFile:getValue("animalNames#showNames", self.showNames)
    self.nameDistance = xmlFile:getValue("animalNames#nameDistance", self.nameDistance)
    self.nameHeight = xmlFile:getValue("animalNames#nameHeight", self.nameHeight)
    self.fontSize = xmlFile:getValue("animalNames#fontSize", self.fontSize)
    
    -- Load animal names
    local index = 0
    while true do
        local key = string.format("animalNames.animal(%d)", index)
        
        if not xmlFile:hasProperty(key) then
            break
        end
        
        local animalId = xmlFile:getValue(key .. "#id")
        local name = xmlFile:getValue(key .. "#name")
        
        if animalId and name then
            self.animalNames[animalId] = name
        end
        
        index = index + 1
    end
    
    xmlFile:delete()
end

---Called on mission delete
function RealisticAnimalNames:onMissionDelete()
    -- Save data before deleting
    if self.mission:getIsServer() then
        self:saveToSavegame()
    end
    
    -- Unregister input action
    if self.actionEventId then
        self.inputManager:removeActionEvent(self.actionEventId)
        self.actionEventId = nil
    end
    
    -- Clear data
    self.animalNames = {}
    self.originalNames = {}
    self.currentAnimal = nil
    self.isInitialized = false
end

---Update (called every frame)
function RealisticAnimalNames:update(dt)
    -- Update settings from game settings if they changed
    if g_gameSettings then
        self.showNames = g_gameSettings:getValue("showNames")
        self.nameDistance = g_gameSettings:getValue("nameDistance")
        self.nameHeight = g_gameSettings:getValue("nameHeight")
        self.fontSize = g_gameSettings:getValue("fontSize")
    end
end

-- ============================================================================
-- Dialog Class
-- ============================================================================

AnimalNamesDialog = {}
local AnimalNamesDialog_mt = Class(AnimalNamesDialog, MessageDialog)

function AnimalNamesDialog.new(mod, target)
    local self = MessageDialog.new(target, AnimalNamesDialog_mt)
    
    self.mod = mod
    
    return self
end

function AnimalNamesDialog:onOpen()
    AnimalNamesDialog:superClass().onOpen(self)
    
    -- Focus on text input
    if self.nameInput then
        FocusManager:setFocus(self.nameInput)
    end
end

function AnimalNamesDialog:setAnimal(animal, currentName)
    self.animal = animal
    
    if self.nameInput then
        self.nameInput:setText(currentName or "")
    end
end

function AnimalNamesDialog:onClickApply()
    if not self.animal or not self.nameInput then
        return
    end
    
    local newName = self.nameInput:getText()
    self.mod:setAnimalName(self.animal, newName)
    
    self:close()
end

function AnimalNamesDialog:onClickReset()
    if not self.animal then
        return
    end
    
    self.mod:resetAnimalName(self.animal)
    
    self:close()
end

function AnimalNamesDialog:onClickCancel()
    self:close()
end

-- ============================================================================
-- Global Registration
-- ============================================================================

local modDirectory = g_currentModDirectory
local modName = g_currentModName

local function validateTypes(mod)
    if type(mod.onMissionLoaded) ~= "function" then
        print("Error: mod is invalid")
    end
end

local function load(mission)
    assert(g_realisticAnimalNames == nil)
    
    g_realisticAnimalNames = RealisticAnimalNames.new(
        mission,
        modDirectory,
        modName,
        g_i18n,
        g_gui,
        g_inputBinding,
        mission.messageCenter
    )
    
    validateTypes(g_realisticAnimalNames)
    
    addModEventListener(g_realisticAnimalNames)
end

local function unload()
    if g_realisticAnimalNames then
        removeModEventListener(g_realisticAnimalNames)
        
        if g_realisticAnimalNames.onMissionDelete then
            g_realisticAnimalNames:onMissionDelete()
        end
        
        g_realisticAnimalNames = nil
    end
end

local function init()
    FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, unload)
    Mission00.load = Utils.prependedFunction(Mission00.load, load)
    
    -- Hook into draw function
    FSBaseMission.draw = Utils.appendedFunction(FSBaseMission.draw, function()
        if g_realisticAnimalNames and g_realisticAnimalNames.isInitialized then
            g_realisticAnimalNames:draw()
        end
    end)
    
    -- Hook into update function
    FSBaseMission.update = Utils.appendedFunction(FSBaseMission.update, function(self, dt)
        if g_realisticAnimalNames and g_realisticAnimalNames.isInitialized then
            g_realisticAnimalNames:update(dt)
        end
    end)
end

init()