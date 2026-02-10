-- ============================================================================
-- Realistic Animal Names for FS25 - ENHANCED VERSION
-- ============================================================================
-- Version: 2.1.0.0
-- Author: YourName
-- Description: Add custom names to animals with floating name tags
-- ============================================================================

RealisticAnimalNames = {}
g_realisticAnimalNames = nil

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
    self.perSavegameSettings = {}
    
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
    self.lastSettingsCheck = 0
    self.activeSavegame = nil
    self.isMultiplayer = false

    return self
end

---Called on mission load
function RealisticAnimalNames:onMissionLoaded(mission)
    if mission:getIsServer() or mission:getIsClient() then
        -- Check if multiplayer
        self.isMultiplayer = mission:getIsMultiplayer()
        
        -- Get current savegame ID
        self.activeSavegame = self:getSavegameId()
        
        -- Load per-savegame settings
        self:loadPerSavegameSettings()
        
        -- Load saved animal names
        self:loadFromSavegame()
        
        -- Only register input on client side
        if mission:getIsClient() then
            self:registerInputActions()
            self:loadGUI()
            
            -- Welcome notification (only for clients)
            self:showNotification("ran_notification_loaded", FSBaseMission.INGAME_NOTIFICATION_INFO)
        end
        
        self.isInitialized = true
        
        -- Register for settings changes
        self:registerSettingsListener()
    end
end

---Register for settings changes
function RealisticAnimalNames:registerSettingsListener()
    if self.messageCenter then
        self.messageCenter:subscribe(MessageType.SETTING_CHANGED, self.onSettingChanged, self)
    end
end

---Handle settings changes
function RealisticAnimalNames:onSettingChanged(message)
    local settingName = message.settingName
    local value = message.value
    
    -- Update cached settings
    if settingName == "showNames" then
        self.settings.showNames = value
    elseif settingName == "nameDistance" then
        self.settings.nameDistance = value
    elseif settingName == "nameHeight" then
        self.settings.nameHeight = value
    elseif settingName == "fontSize" then
        self.settings.fontSize = value
    end
    
    -- Save to per-savegame settings
    self.perSavegameSettings[settingName] = value
    self:savePerSavegameSettings()
end

---Load per-savegame settings
function RealisticAnimalNames:loadPerSavegameSettings()
    local filename = self:getSavegamePath("settings.xml")
    if not filename or not fileExists(filename) then
        return
    end
    
    local xmlFile = XMLFile.load("settingsXML", filename)
    if not xmlFile then
        return
    end
    
    xmlFile:iterate("settings.setting", function(index, key)
        local name = xmlFile:getValue(key .. "#name")
        local value = xmlFile:getValue(key .. "#value")
        if name and value ~= nil then
            self.perSavegameSettings[name] = value
            
            -- Apply to current settings
            if self.settings[name] ~= nil then
                self.settings[name] = value
            end
        end
    end)
    
    xmlFile:delete()
end

---Save per-savegame settings
function RealisticAnimalNames:savePerSavegameSettings()
    local filename = self:getSavegamePath("settings.xml")
    if not filename then
        return
    end
    
    local xmlFile = XMLFile.create("settingsXML", filename, "settings")
    if not xmlFile then
        return
    end
    
    local index = 0
    for name, value in pairs(self.perSavegameSettings) do
        local key = string.format("settings.setting(%d)", index)
        xmlFile:setValue(key .. "#name", name)
        xmlFile:setValue(key .. "#value", value)
        index = index + 1
    end
    
    xmlFile:save()
    xmlFile:delete()
end

---Get savegame ID
function RealisticAnimalNames:getSavegameId()
    if self.mission.missionInfo and self.mission.missionInfo.savegameDirectory then
        local dir = self.mission.missionInfo.savegameDirectory
        local id = string.match(dir, "savegame(%d+)")
        return tonumber(id) or 0
    end
    return 0
end

---Get savegame file path
function RealisticAnimalNames:getSavegamePath(filename)
    if self.mission.missionInfo and self.mission.missionInfo.savegameDirectory then
        local path = self.mission.missionInfo.savegameDirectory .. "/"
        if filename then
            path = path .. filename
        end
        return path
    end
    return nil
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
        self.inputManager:setActionEventActive(actionEventId, true)
    end
end

---Load the GUI dialog
function RealisticAnimalNames:loadGUI()
    local xmlFilename = self.modDirectory .. "gui/AnimalNamesDialog.xml"
    
    if fileExists(xmlFilename) then
        self.dialog = g_gui:loadGui(
            xmlFilename,
            "AnimalNamesDialog",
            AnimalNamesDialog.new(self)
        )
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

---Find the closest animal to the camera with type filtering
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

---Validate if animal is valid for naming
function RealisticAnimalNames:isValidAnimal(animal)
    if not animal or not animal.nodeId then
        return false
    end
    
    if not entityExists(animal.nodeId) then
        return false
    end
    
    -- Check if animal is alive (not a carcass)
    if animal.isDead then
        return false
    end
    
    return true
end

---Get list of all nearby animals
function RealisticAnimalNames:getNearbyAnimals(maxDistance, limit)
    local animals = {}
    local camera = getCamera()
    
    if not camera or not self.mission.animalSystem then
        return animals
    end
    
    local camX, camY, camZ = getWorldTranslation(camera)
    local count = 0
    
    for _, cluster in pairs(self.mission.animalSystem.clusters) do
        if cluster.animals then
            for _, animal in pairs(cluster.animals) do
                if self:isValidAnimal(animal) then
                    local x, y, z = getWorldTranslation(animal.nodeId)
                    local distance = MathUtil.vector3Length(camX - x, camY - y, camZ - z)
                    
                    if distance <= maxDistance then
                        table.insert(animals, {
                            animal = animal,
                            distance = distance
                        })
                        count = count + 1
                        
                        if limit and count >= limit then
                            return animals
                        end
                    end
                end
            end
        end
    end
    
    -- Sort by distance
    table.sort(animals, function(a, b)
        return a.distance < b.distance
    end)
    
    return animals
end

---Open the naming dialog for a specific animal
function RealisticAnimalNames:openDialogForAnimal(animal)
    if not self.dialog then
        self:loadGUI()
        if not self.dialog then
            print("Error: Could not load dialog")
            return
        end
    end
    
    self.currentAnimal = animal
    
    local currentName = self.animalNames[animal.id] or ""
    
    self.dialog:setAnimal(animal, currentName)
    g_gui:showDialog("AnimalNamesDialog")
end

---Set an animal's name
function RealisticAnimalNames:setAnimalName(animal, name)
    if not animal or not animal.id then
        return false
    end
    
    -- Validate name
    name = self:validateAnimalName(name)
    if not name then
        return false
    end
    
    -- Store original name if not already stored
    if not self.originalNames[animal.id] then
        self.originalNames[animal.id] = self.animalNames[animal.id] or ""
    end
    
    -- Set new name
    self.animalNames[animal.id] = name
    
    -- Show notification
    self:showNotification("ran_notification_nameSet", FSBaseMission.INGAME_NOTIFICATION_OK, name)
    
    -- Save immediately
    self:saveToSavegame()
    
    return true
end

---Validate animal name
function RealisticAnimalNames:validateAnimalName(name)
    if not name or name == "" then
        return nil  -- Empty name is valid (resets to default)
    end
    
    -- Trim whitespace
    name = string.gsub(name, "^%s*(.-)%s*$", "%1")
    
    -- Check length
    if #name > 30 then
        name = string.sub(name, 1, 30)
    end
    
    -- Remove potentially harmful characters
    name = string.gsub(name, "[<>\"&]", "")
    
    return name
end

---Reset an animal's name
function RealisticAnimalNames:resetAnimalName(animal)
    if not animal or not animal.id then
        return false
    end
    
    local originalName = self.originalNames[animal.id]
    self.animalNames[animal.id] = originalName
    
    self:showNotification("ran_notification_nameReset", FSBaseMission.INGAME_NOTIFICATION_OK)
    
    -- Save immediately
    self:saveToSavegame()
    
    return true
end

---Show notification
function RealisticAnimalNames:showNotification(translationKey, notificationType, ...)
    if not g_currentMission then
        return
    end
    
    local text = self.i18n:getText(translationKey)
    if ... then
        text = string.format(text, ...)
    end
    
    g_currentMission:addIngameNotification(notificationType, text)
end

---Draw floating names above animals
function RealisticAnimalNames:draw()
    if not self.settings.showNames then
        return
    end

    if not self.mission.animalSystem or not self.mission.animalSystem.clusters then
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
                if self:isValidAnimal(animal) then
                    local name = self.animalNames[animal.id]

                    if name then
                        local x, y, z = getWorldTranslation(animal.nodeId)
                        local distance = MathUtil.vector3Length(camX - x, camY - y, camZ - z)

                        if distance <= self.settings.nameDistance then
                            y = y + self.settings.nameHeight
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
        
        -- Calculate alpha based on distance
        local alpha = 1.0
        if distance > self.settings.nameDistance * 0.8 then
            alpha = 1.0 - ((distance - self.settings.nameDistance * 0.8) / (self.settings.nameDistance * 0.2))
        end
        
        setTextColor(1, 1, 1, alpha)
        
        -- Scale font size based on distance
        local scale = 1.0 - (distance / self.settings.nameDistance) * 0.5
        local fontSize = self.settings.fontSize * scale
        
        renderText(sx, sy, fontSize, text)
        
        setTextBold(false)
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
    end
end

---Save animal names to savegame XML
function RealisticAnimalNames:saveToSavegame()
    local filename = self:getSavegamePath("animalNames.xml")
    if not filename then
        return
    end
    
    local xmlFile = XMLFile.create("animalNamesXML", filename, "animalNames")
    if not xmlFile then
        return
    end
    
    -- Save settings
    xmlFile:setValue("animalNames#showNames", self.settings.showNames)
    xmlFile:setValue("animalNames#nameDistance", self.settings.nameDistance)
    xmlFile:setValue("animalNames#nameHeight", self.settings.nameHeight)
    xmlFile:setValue("animalNames#fontSize", self.settings.fontSize)
    
    -- Save animal names
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
    
    -- Save per-savegame settings
    self:savePerSavegameSettings()
end

---Load animal names from savegame XML
function RealisticAnimalNames:loadFromSavegame()
    local filename = self:getSavegamePath("animalNames.xml")
    if not filename or not fileExists(filename) then
        return
    end
    
    local xmlFile = XMLFile.load("animalNamesXML", filename)
    if not xmlFile then
        return
    end
    
    -- Load settings (use as fallback)
    self.settings.showNames = xmlFile:getValue("animalNames#showNames", self.settings.showNames)
    self.settings.nameDistance = xmlFile:getValue("animalNames#nameDistance", self.settings.nameDistance)
    self.settings.nameHeight = xmlFile:getValue("animalNames#nameHeight", self.settings.nameHeight)
    self.settings.fontSize = xmlFile:getValue("animalNames#fontSize", self.settings.fontSize)
    
    -- Load animal names
    local index = 0
    while true do
        local key = string.format("animalNames.animal(%d)", index)
        
        if not xmlFile:hasProperty(key) then
            break
        end
        
        local animalId = xmlFile:getValue(key .. "#id")
        local name = xmlFile:getValue(key .. "#name")
        
        if animalId and name and name ~= "" then
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
        self.inputManager:removeActionEvents(self)
        self.actionEventId = nil
    end
    
    -- Unsubscribe from messages
    if self.messageCenter then
        self.messageCenter:unsubscribeAll(self)
    end
    
    -- Clear data
    self.animalNames = {}
    self.originalNames = {}
    self.currentAnimal = nil
    self.isInitialized = false
    self.activeSavegame = nil
    self.isMultiplayer = false
end

---Update (called every frame)
function RealisticAnimalNames:update(dt)
    if not self.isInitialized then
        return
    end
    
    -- Update settings from game settings periodically
    self.lastSettingsCheck = self.lastSettingsCheck + dt
    if self.lastSettingsCheck > 0.5 then  -- Check every 0.5 seconds
        self:updateSettingsFromGame()
        self.lastSettingsCheck = 0
    end
end

---Update settings from game settings
function RealisticAnimalNames:updateSettingsFromGame()
    if g_gameSettings then
        local newShowNames = g_gameSettings:getValue("showNames")
        local newNameDistance = g_gameSettings:getValue("nameDistance")
        local newNameHeight = g_gameSettings:getValue("nameHeight")
        local newFontSize = g_gameSettings:getValue("fontSize")
        
        -- Check if settings changed
        if newShowNames ~= nil and newShowNames ~= self.settings.showNames then
            self.settings.showNames = newShowNames
            self.perSavegameSettings.showNames = newShowNames
        end
        
        if newNameDistance ~= nil and newNameDistance ~= self.settings.nameDistance then
            self.settings.nameDistance = newNameDistance
            self.perSavegameSettings.nameDistance = newNameDistance
        end
        
        if newNameHeight ~= nil and newNameHeight ~= self.settings.nameHeight then
            self.settings.nameHeight = newNameHeight
            self.perSavegameSettings.nameHeight = newNameHeight
        end
        
        if newFontSize ~= nil and newFontSize ~= self.settings.fontSize then
            self.settings.fontSize = newFontSize
            self.perSavegameSettings.fontSize = newFontSize
        end
    end
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
-- Dialog Class (Enhanced)
-- ============================================================================

AnimalNamesDialog = {}
local AnimalNamesDialog_mt = Class(AnimalNamesDialog, DialogElement)

function AnimalNamesDialog.new(mod)
    local self = DialogElement.new(nil, AnimalNamesDialog_mt)
    
    self.mod = mod
    self.animal = nil
    self.nameInput = nil
    
    return self
end

function AnimalNamesDialog:onCreate(element)
    DialogElement.onCreate(self, element)
    
    -- Get references to UI elements
    self.nameInput = element:getDescendantByName("nameInput")
    
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
    if not self.mod or not self.animal then
        return
    end
    
    local newName = self.nameInput:getText()
    if self.mod.setAnimalName then
        if self.mod:setAnimalName(self.animal, newName) then
            self:close()
        end
    end
end

function AnimalNamesDialog:onClickReset()
    if not self.mod or not self.animal then
        return
    end
    
    if self.mod.resetAnimalName then
        if self.mod:resetAnimalName(self.animal) then
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

-- ============================================================================
-- Global Registration
-- ============================================================================

local modDirectory = g_currentModDirectory
local modName = g_currentModName

local function validateTypes(mod)
    if type(mod.onMissionLoaded) ~= "function" then
        print("Error: mod is invalid - missing onMissionLoaded function")
        return false
    end
    
    if type(mod.onMissionDelete) ~= "function" then
        print("Error: mod is invalid - missing onMissionDelete function")
        return false
    end
    
    return true
end

local function load(mission)
    if g_realisticAnimalNames then
        -- Unload existing instance
        removeModEventListener(g_realisticAnimalNames)
        if g_realisticAnimalNames.onMissionDelete then
            g_realisticAnimalNames:onMissionDelete()
        end
        g_realisticAnimalNames = nil
    end
    
    g_realisticAnimalNames = RealisticAnimalNames.new(
        mission,
        modDirectory,
        modName,
        g_i18n,
        g_gui,
        g_inputBinding,
        mission.messageCenter
    )
    
    if not validateTypes(g_realisticAnimalNames) then
        g_realisticAnimalNames = nil
        return
    end
    
    addModEventListener(g_realisticAnimalNames)
    
    print("Realistic Animal Names mod loaded")
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
    
    print("Realistic Animal Names mod initialized")
end

-- Initialize on mod load
init()