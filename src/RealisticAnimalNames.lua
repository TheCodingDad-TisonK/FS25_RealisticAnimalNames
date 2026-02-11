-- ============================================================================
-- Realistic Animal Names for FS25 - COMPLETE VERSION
-- ============================================================================
-- Version: 2.1.0.0
-- Author: TisonK
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
    
    -- Settings cache
    self.settings = {
        showNames = true,
        nameDistance = 15,
        nameHeight = 1.8,
        fontSize = 0.018
    }

    -- UI
    self.dialog = nil
    self.currentAnimal = nil
    
    -- State
    self.isInitialized = false
    self.actionEventId = nil
    self.isMultiplayer = false

    return self
end

---Called on mission load
function RealisticAnimalNames:onMissionLoaded(mission)
    if mission:getIsServer() or mission:getIsClient() then
        -- Check if multiplayer
        self.isMultiplayer = mission:getIsMultiplayer()
        
        -- Load saved animal names
        self:loadFromSavegame()
        
        -- Only register input and UI on client side
        if mission:getIsClient() then
            self:registerInputActions()
            self:loadGUI()
            
            -- Welcome notification
            self:showNotification("ran_notification_loaded", FSBaseMission.INGAME_NOTIFICATION_INFO)
        end
        
        self.isInitialized = true
        
        -- Load settings from game settings
        self:loadSettingsFromGame()
    end
end

---Load settings from game settings system
function RealisticAnimalNames:loadSettingsFromGame()
    if g_gameSettings then
        local showNames = g_gameSettings:getValue("showNames")
        local nameDistance = g_gameSettings:getValue("nameDistance")
        local nameHeight = g_gameSettings:getValue("nameHeight")
        local fontSize = g_gameSettings:getValue("fontSize")
        
        if showNames ~= nil then
            self.settings.showNames = showNames
        end
        if nameDistance ~= nil then
            self.settings.nameDistance = nameDistance
        end
        if nameHeight ~= nil then
            self.settings.nameHeight = nameHeight
        end
        if fontSize ~= nil then
            self.settings.fontSize = fontSize
        end
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
        self.inputManager:setActionEventTextVisibility(actionEventId, false)
        self.inputManager:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
    end
end

---Load the GUI dialog
function RealisticAnimalNames:loadGUI()
    local xmlFilename = self.modDirectory .. "gui/AnimalNamesDialog.xml"
    
    if fileExists(xmlFilename) then
        -- Load the GUI using the proper FS25 API
        self.gui:loadGui(xmlFilename, "AnimalNamesDialog", self)
        
        print("Realistic Animal Names: GUI loaded from " .. xmlFilename)
    else
        print("Error: GUI file not found: " .. xmlFilename)
    end
end

---Input callback - open UI near animal
function RealisticAnimalNames:onOpenUIInput(_, inputValue)
    if inputValue ~= 1 then
        return
    end
    
    if not self.isInitialized then
        return
    end
    
    local animal = self:getClosestAnimal(self.settings.nameDistance)
    
    if animal then
        self:openDialogForAnimal(animal)
    else
        self:showNotification("ran_notification_noAnimal", FSBaseMission.INGAME_NOTIFICATION_INFO)
    end
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
    
    -- Iterate through all animal clusters
    for _, cluster in pairs(self.mission.animalSystem.clusters) do
        if cluster.animals then
            for _, animal in pairs(cluster.animals) do
                if self:isValidAnimal(animal) then
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

---Check if animal is valid for naming
function RealisticAnimalNames:isValidAnimal(animal)
    return animal ~= nil 
        and animal.nodeId ~= nil 
        and entityExists(animal.nodeId)
        and animal.id ~= nil
end

---Get unique animal ID
function RealisticAnimalNames:getAnimalId(animal)
    if not animal or not animal.id then
        return nil
    end
    return tostring(animal.id)
end

---Open the naming dialog for an animal
function RealisticAnimalNames:openDialogForAnimal(animal)
    if not animal then
        return
    end
    
    self.currentAnimal = animal
    local animalId = self:getAnimalId(animal)
    local currentName = self.animalNames[animalId] or ""
    
    -- Get or create dialog
    local dialog = self.gui:showDialog("AnimalNamesDialog")
    
    if dialog and dialog.setAnimal then
        dialog:setAnimal(animal, currentName)
    end
end

---Set an animal's name
function RealisticAnimalNames:setAnimalName(animal, name)
    if not animal then
        return false
    end
    
    local animalId = self:getAnimalId(animal)
    if not animalId then
        return false
    end
    
    -- Validate and sanitize name
    name = name and tostring(name):trim() or ""
    
    if name == "" then
        -- Empty name = reset
        return self:resetAnimalName(animal)
    end
    
    -- Limit name length
    if string.len(name) > 30 then
        name = string.sub(name, 1, 30)
    end
    
    -- Store the name
    self.animalNames[animalId] = name
    
    -- Save to file
    self:saveToSavegame()
    
    -- Show notification
    local notificationText = string.format(self.i18n:getText("ran_notification_nameSet"), name)
    g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK, notificationText)
    
    return true
end

---Reset an animal's name
function RealisticAnimalNames:resetAnimalName(animal)
    if not animal then
        return false
    end
    
    local animalId = self:getAnimalId(animal)
    if not animalId then
        return false
    end
    
    -- Remove the name
    self.animalNames[animalId] = nil
    
    -- Save to file
    self:saveToSavegame()
    
    -- Show notification
    self:showNotification("ran_notification_nameReset", FSBaseMission.INGAME_NOTIFICATION_OK)
    
    return true
end

---Show a localized notification
function RealisticAnimalNames:showNotification(textKey, notificationType)
    local text = self.i18n:getText(textKey)
    g_currentMission:addIngameNotification(notificationType or FSBaseMission.INGAME_NOTIFICATION_INFO, text)
end

---Get savegame file path
function RealisticAnimalNames:getSavegameFilePath()
    if self.mission.missionInfo and self.mission.missionInfo.savegameDirectory then
        return self.mission.missionInfo.savegameDirectory .. "/realisticAnimalNames.xml"
    end
    return nil
end

---Load animal names from savegame
function RealisticAnimalNames:loadFromSavegame()
    local filename = self:getSavegameFilePath()
    if not filename or not fileExists(filename) then
        print("Realistic Animal Names: No existing savegame data found")
        return
    end
    
    local xmlFile = XMLFile.load("animalNamesXML", filename)
    if not xmlFile then
        print("Realistic Animal Names: Failed to load savegame data")
        return
    end
    
    -- Load animal names
    local index = 0
    while true do
        local key = string.format("animalNames.animal(%d)", index)
        local animalId = xmlFile:getValue(key .. "#id")
        local name = xmlFile:getValue(key .. "#name")
        
        if not animalId then
            break
        end
        
        if name and name ~= "" then
            self.animalNames[animalId] = name
        end
        
        index = index + 1
    end
    
    xmlFile:delete()
    
    print(string.format("Realistic Animal Names: Loaded %d animal names", index))
end

---Save animal names to savegame
function RealisticAnimalNames:saveToSavegame()
    local filename = self:getSavegameFilePath()
    if not filename then
        print("Realistic Animal Names: Cannot save - no savegame directory")
        return false
    end
    
    local xmlFile = XMLFile.create("animalNamesXML", filename, "animalNames")
    if not xmlFile then
        print("Realistic Animal Names: Failed to create XML file")
        return false
    end
    
    -- Save all animal names
    local index = 0
    for animalId, name in pairs(self.animalNames) do
        if name and name ~= "" then
            local key = string.format("animalNames.animal(%d)", index)
            xmlFile:setValue(key .. "#id", animalId)
            xmlFile:setValue(key .. "#name", name)
            index = index + 1
        end
    end
    
    xmlFile:save()
    xmlFile:delete()
    
    return true
end

---Draw floating name tags
function RealisticAnimalNames:draw()
    if not self.isInitialized or not self.settings.showNames then
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
    local maxDistance = self.settings.nameDistance
    
    -- Set text rendering properties
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
    setTextBold(true)
    
    -- Draw name for each named animal
    for _, cluster in pairs(self.mission.animalSystem.clusters) do
        if cluster.animals then
            for _, animal in pairs(cluster.animals) do
                if self:isValidAnimal(animal) then
                    local animalId = self:getAnimalId(animal)
                    local name = self.animalNames[animalId]
                    
                    if name and name ~= "" then
                        -- Get animal position
                        local x, y, z = getWorldTranslation(animal.nodeId)
                        local distance = MathUtil.vector3Length(camX - x, camY - y, camZ - z)
                        
                        -- Only draw if within range
                        if distance < maxDistance then
                            -- Calculate display position (above animal)
                            local displayY = y + self.settings.nameHeight
                            
                            -- Calculate alpha based on distance
                            local alpha = 1.0 - (distance / maxDistance)
                            alpha = math.max(0.3, math.min(1.0, alpha))
                            
                            -- Calculate scale based on distance
                            local scale = self.settings.fontSize * (1.0 + (distance / maxDistance) * 0.5)
                            
                            -- Render the name
                            setTextColor(1, 1, 1, alpha)
                            renderText3D(x, displayY, z, 0, 0, 0, scale, name)
                        end
                    end
                end
            end
        end
    end
    
    -- Reset text properties
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
    setTextBold(false)
    setTextColor(1, 1, 1, 1)
end

---Update (called every frame)
function RealisticAnimalNames:update(dt)
    if not self.isInitialized then
        return
    end
    
    -- Periodically sync settings from game settings
    -- (in case user changes them in settings menu)
    self:loadSettingsFromGame()
end

---Called when mission is being deleted
function RealisticAnimalNames:onMissionDelete()
    -- Unregister input action
    if self.actionEventId and self.inputManager then
        self.inputManager:removeActionEvent(self.actionEventId)
        self.actionEventId = nil
    end
    
    -- Clear data
    self.animalNames = {}
    self.originalNames = {}
    self.currentAnimal = nil
    self.isInitialized = false
    self.isMultiplayer = false
end

---Get animal name by ID
function RealisticAnimalNames:getAnimalName(animalId)
    return self.animalNames[animalId]
end

---Get all animal names
function RealisticAnimalNames:getAllAnimalNames()
    return self.animalNames
end

---Clear all animal names
function RealisticAnimalNames:clearAllAnimalNames()
    self.animalNames = {}
    self:saveToSavegame()
    self:showNotification("ran_notification_allNamesCleared", FSBaseMission.INGAME_NOTIFICATION_OK)
end

-- ============================================================================
-- Global Initialization
-- ============================================================================

g_realisticAnimalNames = nil

local modDirectory = g_currentModDirectory
local modName = g_currentModName

local function load(mission)
    if g_realisticAnimalNames then
        -- Cleanup existing instance
        removeModEventListener(g_realisticAnimalNames)
        if g_realisticAnimalNames.onMissionDelete then
            g_realisticAnimalNames:onMissionDelete()
        end
        g_realisticAnimalNames = nil
    end
    
    -- Create new instance
    g_realisticAnimalNames = RealisticAnimalNames.new(
        mission,
        modDirectory,
        modName,
        g_i18n,
        g_gui,
        g_inputBinding,
        mission.messageCenter
    )
    
    -- Register as mod event listener
    addModEventListener(g_realisticAnimalNames)
    
    print("Realistic Animal Names: Mod loaded successfully")
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
    -- Hook into mission lifecycle
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
    
    print("Realistic Animal Names: Initialization complete")
end

-- Initialize the mod
init()