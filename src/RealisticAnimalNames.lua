-- ============================================================================
-- Realistic Animal Names for FS25 - PROFESSIONAL EDITION
-- ============================================================================
-- Version: 2.1.0.0
-- Author: TisonK
-- Description: Add custom names to animals with floating name tags
-- ============================================================================
-- COMPLETE REWRITE: Fixed architecture, performance, and multiplayer
-- ============================================================================

---@class RealisticAnimalNames
RealisticAnimalNames = {}
RealisticAnimalNames.__index = RealisticAnimalNames

-- Constants
local SAVE_FILE_NAME = "realisticAnimalNames.xml"
local ANIMATION_UPDATE_INTERVAL = 250 -- ms between distance recalculations
local SAVE_DEBOUNCE_INTERVAL = 500 -- ms between saves
local MAX_NAME_LENGTH = 30
local PERFORMANCE_MAX_ANIMALS_PER_FRAME = 50

---Initialize the mod - Called by FS25
---@param mission table Mission instance
---@param modDirectory string Mod folder path
---@param modName string Mod name
function RealisticAnimalNames:new(mission, modDirectory, modName)
    local self = setmetatable({}, RealisticAnimalNames)
    
    -- Core references
    self.mission = mission
    self.modDirectory = modDirectory
    self.modName = modName
    self.i18n = g_i18n
    self.gui = g_gui
    self.inputManager = g_inputBinding
    
    -- Multiplayer state
    self.isServer = mission:getIsServer()
    self.isClient = mission:getIsClient()
    self.isMultiplayer = mission:getIsMultiplayer()
    
    -- Data storage
    self.animalNames = {}      -- id -> name
    self.nameCache = {}        -- nodeId -> name (for fast lookup)
    
    -- Settings cache
    self.settings = {
        showNames = true,
        nameDistance = 15,
        nameHeight = 1.8,
        fontSize = 0.018
    }
    
    -- Performance optimization
    self.lastDistanceUpdate = 0
    self.nearbyAnimals = {}    -- Cached nearby animals
    self.animalPositions = {}  -- Cached positions
    self.animalUpdateIndex = 0
    
    -- UI State
    self.dialog = nil
    self.currentAnimal = nil
    self.dialogLoaded = false
    
    -- Save management
    self.savePending = false
    self.saveTimer = 0
    
    -- Network
    self.networkEventsRegistered = false
    
    -- Event listeners
    self.eventListeners = {}
    
    -- Initialization state
    self.isInitialized = false
    self.actionEventId = nil
    
    print("[RealisticAnimalNames] Instance created (Server:", self.isServer, "Client:", self.isClient, "MP:", self.isMultiplayer, ")")
    
    return self
end

---Register all event listeners
function RealisticAnimalNames:registerEventListeners()
    if not self.mission then return end
    
    -- Animal system events
    if self.mission.animalSystem then
        -- Listen for animal removal to clean up names
        if self.mission.animalSystem.addRemoveAnimalListener then
            self.mission.animalSystem:addRemoveAnimalListener(function(animal, isAdded)
                if not isAdded then
                    self:onAnimalRemoved(animal)
                end
            end)
        end
    end
    
    -- Settings change listener
    if g_gameSettings and g_gameSettings.addSettingsChangeListener then
        g_gameSettings:addSettingsChangeListener(function(name, value)
            if name:find("^ran_") then
                self:onSettingsChanged(name, value)
            end
        end)
    end
    
    -- Network listeners (if multiplayer)
    if self.isMultiplayer and self.isServer then
        self:registerNetworkEvents()
    end
end

---Register multiplayer network events
function RealisticAnimalNames:registerNetworkEvents()
    if self.networkEventsRegistered then return end
    
    if g_network and g_network:getServerConnection() then
        -- Client requests name change
        g_network:addEvent(NetworkEventType.RAN_REQUEST_NAME_CHANGE, 
            function(connection, animalId, newName, userId)
                self:onNameChangeRequest(connection, animalId, newName, userId)
            end)
        
        -- Server broadcasts name change
        g_network:addEvent(NetworkEventType.RAN_NAME_CHANGED,
            function(connection, animalId, newName, serverTime)
                self:onNameChangedFromServer(animalId, newName, serverTime)
            end)
        
        -- Request initial sync
        g_network:addEvent(NetworkEventType.RAN_REQUEST_SYNC,
            function(connection, userId)
                self:onSyncRequest(connection, userId)
            end)
        
        self.networkEventsRegistered = true
        print("[RealisticAnimalNames] Network events registered")
    end
end

---Called on mission load
function RealisticAnimalNames:onMissionLoaded(mission)
    self.mission = mission
    
    -- Only server loads/saves data in multiplayer
    if self.isServer then
        self:loadFromSavegame()
    end
    
    -- Register input and load GUI on all clients
    if self.isClient then
        self:registerInputActions()
        self:loadGUIAsync()
    end
    
    -- Load settings (both server and client)
    self:loadSettingsFromGame()
    
    -- Register all event listeners
    self:registerEventListeners()
    
    -- Request sync from server if we're a client in multiplayer
    if self.isMultiplayer and self.isClient and not self.isServer then
        self:requestSyncFromServer()
    end
    
    self.isInitialized = true
    
    -- Welcome notification (clients only)
    if self.isClient then
        self:showNotification("ran_notification_loaded", FSBaseMission.INGAME_NOTIFICATION_INFO)
    end
    
    print("[RealisticAnimalNames] Mission loaded successfully")
end

---Async GUI loading to prevent frame drops
function RealisticAnimalNames:loadGUIAsync()
    local xmlFilename = self.modDirectory .. "gui/AnimalNamesDialog.xml"
    
    if not fileExists(xmlFilename) then
        print("[RealisticAnimalNames] ERROR: GUI file not found: " .. xmlFilename)
        return
    end
    
    -- Defer GUI loading to next frame
    self:scheduleCallback(function()
        self.gui:loadGui(xmlFilename, "AnimalNamesDialog", self)
        self.dialogLoaded = true
        print("[RealisticAnimalNames] GUI loaded")
    end, 1)
end

---Schedule a callback for next frame or delayed execution
function RealisticAnimalNames:scheduleCallback(func, delayFrames)
    delayFrames = delayFrames or 0
    
    local function execute()
        if delayFrames > 0 then
            delayFrames = delayFrames - 1
            g_currentMission:addUpdateCallback(execute)
        else
            local success, err = pcall(func)
            if not success then
                print("[RealisticAnimalNames] Callback error:", err)
            end
        end
    end
    
    if delayFrames > 0 then
        g_currentMission:addUpdateCallback(execute)
    else
        execute()
    end
end

---Load settings from game settings system
function RealisticAnimalNames:loadSettingsFromGame()
    if not g_gameSettings then return end
    
    local showNames = g_gameSettings:getValue("showNames")
    local nameDistance = g_gameSettings:getValue("nameDistance")
    local nameHeight = g_gameSettings:getValue("nameHeight")
    local fontSize = g_gameSettings:getValue("fontSize")
    
    if showNames ~= nil then self.settings.showNames = showNames end
    if nameDistance ~= nil then self.settings.nameDistance = nameDistance end
    if nameHeight ~= nil then self.settings.nameHeight = nameHeight end
    if fontSize ~= nil then self.settings.fontSize = fontSize end
end

---Settings changed callback
function RealisticAnimalNames:onSettingsChanged(name, value)
    local settingMap = {
        showNames = "showNames",
        nameDistance = "nameDistance",
        nameHeight = "nameHeight",
        fontSize = "fontSize"
    }
    
    for settingName, key in pairs(settingMap) do
        if name == settingName then
            self.settings[key] = value
            break
        end
    end
end

---Register input actions for FS25
function RealisticAnimalNames:registerInputActions()
    if not self.inputManager then return end
    
    local success, actionEventId = pcall(function()
        return self.inputManager:registerActionEvent(
            InputAction.RAN_OPEN_UI,
            self,
            self.onOpenUIInput,
            false,
            true,
            false,
            true
        )
    end)
    
    if success and actionEventId then
        self.actionEventId = actionEventId
        self.inputManager:setActionEventTextVisibility(actionEventId, false)
        self.inputManager:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
        print("[RealisticAnimalNames] Input action registered")
    else
        print("[RealisticAnimalNames] Failed to register input action")
    end
end

---Input callback - open UI near animal
function RealisticAnimalNames:onOpenUIInput(_, inputValue)
    if inputValue ~= 1 or not self.isInitialized or not self.dialogLoaded then
        return
    end
    
    local animal = self:getClosestAnimal(self.settings.nameDistance)
    
    if animal then
        self:openDialogForAnimal(animal)
    elseif self.isClient then
        self:showNotification("ran_notification_noAnimal", FSBaseMission.INGAME_NOTIFICATION_INFO)
    end
end

---PERFORMANCE OPTIMIZATION: Find closest animal using spatial proximity
function RealisticAnimalNames:getClosestAnimal(maxDistance)
    if not self.mission.animalSystem then return nil end
    
    local camera = getCamera()
    if not camera then return nil end
    
    local camX, camY, camZ = getWorldTranslation(camera)
    local closestAnimal = nil
    local closestDistance = maxDistance
    
    -- OPTIMIZATION: Early exit if no clusters
    if not self.mission.animalSystem.clusters then
        return nil
    end
    
    -- Use cache if available and recent
    if self.nearbyAnimals.cacheTime and g_currentTime - self.nearbyAnimals.cacheTime < 200 then
        return self.nearbyAnimals.closest
    end
    
    -- Iterate with performance limit
    local animalsChecked = 0
    local maxCheck = 200 -- Don't check more than 200 animals per call
    
    for _, cluster in pairs(self.mission.animalSystem.clusters) do
        if cluster.animals then
            for _, animal in pairs(cluster.animals) do
                animalsChecked = animalsChecked + 1
                if animalsChecked > maxCheck then break end
                
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
        if animalsChecked > maxCheck then break end
    end
    
    -- Cache the result
    self.nearbyAnimals = {
        closest = closestAnimal,
        distance = closestDistance,
        cacheTime = g_currentTime
    }
    
    return closestAnimal
end

---Check if animal is valid for naming
function RealisticAnimalNames:isValidAnimal(animal)
    if not animal then return false end
    if not animal.nodeId or not entityExists(animal.nodeId) then return false end
    if not animal.id then return false end
    return true
end

---Generate stable, network-safe animal ID
function RealisticAnimalNames:getAnimalId(animal)
    if not animal or not animal.id then return nil end
    
    -- In FS25, animals have stable IDs within a session
    -- For multiplayer, we need to ensure ID is consistent across clients
    if self.isMultiplayer then
        -- Use a combination of animal ID and farm ID for uniqueness
        local farmId = animal.ownerFarmId or 1
        return string.format("%d_%d", farmId, animal.id)
    else
        return tostring(animal.id)
    end
end

---Get display name for animal (returns custom name or default localized name)
function RealisticAnimalNames:getAnimalDisplayName(animal)
    if not animal then return "" end
    
    local animalId = self:getAnimalId(animal)
    local customName = self.animalNames[animalId]
    
    if customName and customName ~= "" then
        return customName
    end
    
    -- Return default animal type name if no custom name
    return self:getDefaultAnimalName(animal)
end

---Get default localized name for animal type
function RealisticAnimalNames:getDefaultAnimalName(animal)
    if not animal or not animal.animalType then
        return "Animal"
    end
    
    -- Try to get localized name
    local typeKey = string.format("animal_%s", animal.animalType)
    local localizedName = self.i18n:getText(typeKey)
    
    if localizedName and localizedName ~= typeKey then
        return localizedName
    end
    
    -- Fallback
    return animal.animalType or "Animal"
end

---Open the naming dialog for an animal
function RealisticAnimalNames:openDialogForAnimal(animal)
    if not animal or not self.dialogLoaded then return end
    
    self.currentAnimal = animal
    local animalId = self:getAnimalId(animal)
    local currentName = self.animalNames[animalId] or ""
    
    -- Show dialog with error handling
    local success, dialog = pcall(function()
        return self.gui:showDialog("AnimalNamesDialog")
    end)
    
    if success and dialog and dialog.setAnimal then
        dialog:setAnimal(animal, currentName)
    else
        print("[RealisticAnimalNames] Failed to open dialog")
    end
end

---Set an animal's name (called from UI)
function RealisticAnimalNames:setAnimalName(animal, name)
    if not animal then return false end
    
    local animalId = self:getAnimalId(animal)
    if not animalId then return false end
    
    -- Validate and sanitize name
    name = name and self:sanitizeName(tostring(name)) or ""
    
    if name == "" then
        return self:resetAnimalName(animal)
    end
    
    -- In multiplayer, send request to server
    if self.isMultiplayer and not self.isServer then
        self:requestNameChange(animalId, name)
        return true -- Optimistic update
    end
    
    -- Store the name
    self.animalNames[animalId] = name
    
    -- Update cache
    if animal.nodeId then
        self.nameCache[animal.nodeId] = name
    end
    
    -- Save to file (server only)
    if self.isServer then
        self:scheduleSave()
    end
    
    -- Broadcast to clients (if server in MP)
    if self.isMultiplayer and self.isServer then
        self:broadcastNameChange(animalId, name)
    end
    
    -- Show notification
    local notificationText = string.format(self.i18n:getText("ran_notification_nameSet"), name)
    g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK, notificationText)
    
    return true
end

---Sanitize and validate name string
function RealisticAnimalNames:sanitizeName(name)
    if not name then return "" end
    
    -- Trim whitespace
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    
    -- Remove any control characters
    name = name:gsub("[%c]", "")
    
    -- Limit length (UTF-8 safe)
    local byteLen = #name
    if byteLen > MAX_NAME_LENGTH * 3 then -- Worst case UTF-8
        -- Simple truncation at byte limit
        name = name:sub(1, MAX_NAME_LENGTH * 2)
        -- Ensure we don't cut a multibyte character
        while #name > 0 and name:byte(#name) >= 0x80 do
            name = name:sub(1, #name - 1)
        end
    end
    
    return name
end

---Reset an animal's name
function RealisticAnimalNames:resetAnimalName(animal)
    if not animal then return false end
    
    local animalId = self:getAnimalId(animal)
    if not animalId then return false end
    
    -- In multiplayer, send request to server
    if self.isMultiplayer and not self.isServer then
        self:requestNameChange(animalId, "")
        return true
    end
    
    -- Remove the name
    self.animalNames[animalId] = nil
    
    -- Update cache
    if animal.nodeId then
        self.nameCache[animal.nodeId] = nil
    end
    
    -- Save to file (server only)
    if self.isServer then
        self:scheduleSave()
    end
    
    -- Broadcast to clients (if server in MP)
    if self.isMultiplayer and self.isServer then
        self:broadcastNameChange(animalId, "")
    end
    
    -- Show notification
    self:showNotification("ran_notification_nameReset", FSBaseMission.INGAME_NOTIFICATION_OK)
    
    return true
end

---Request name change from server (MP client)
function RealisticAnimalNames:requestNameChange(animalId, name)
    if not self.isMultiplayer or not g_network then return end
    
    local connection = g_network:getServerConnection()
    if connection then
        connection:sendEvent(NetworkEventType.RAN_REQUEST_NAME_CHANGE, 
            animalId, 
            name, 
            g_currentMission.playerUserId
        )
        print("[RealisticAnimalNames] Name change request sent:", animalId, name)
    end
end

---Handle name change request (server)
function RealisticAnimalNames:onNameChangeRequest(connection, animalId, newName, userId)
    if not self.isServer then return end
    
    -- Validate request (optional: check permissions)
    print("[RealisticAnimalNames] Name change request from user", userId, "for", animalId)
    
    -- Apply the change
    local animal = self:findAnimalById(animalId)
    if animal then
        if newName == "" then
            self.animalNames[animalId] = nil
        else
            self.animalNames[animalId] = self:sanitizeName(newName)
        end
        
        -- Save to file
        self:scheduleSave()
        
        -- Broadcast to all clients
        self:broadcastNameChange(animalId, newName)
    end
end

---Broadcast name change to all clients (server)
function RealisticAnimalNames:broadcastNameChange(animalId, name)
    if not self.isMultiplayer or not g_network then return end
    
    g_network:sendEventToAll(NetworkEventType.RAN_NAME_CHANGED, 
        animalId, 
        name, 
        g_currentTime
    )
end

---Handle name change from server (client)
function RealisticAnimalNames:onNameChangedFromServer(animalId, newName, serverTime)
    if self.isServer then return end -- Already applied
    
    if newName == "" then
        self.animalNames[animalId] = nil
    else
        self.animalNames[animalId] = newName
    end
    
    print("[RealisticAnimalNames] Name updated from server:", animalId, newName)
end

---Request full sync from server (client)
function RealisticAnimalNames:requestSyncFromServer()
    if not self.isMultiplayer or not g_network then return end
    
    local connection = g_network:getServerConnection()
    if connection then
        connection:sendEvent(NetworkEventType.RAN_REQUEST_SYNC, g_currentMission.playerUserId)
        print("[RealisticAnimalNames] Requested sync from server")
    end
end

---Handle sync request (server)
function RealisticAnimalNames:onSyncRequest(connection, userId)
    if not self.isServer then return end
    
    print("[RealisticAnimalNames] Sending sync to user", userId)
    
    -- Send all names to the requesting client
    for animalId, name in pairs(self.animalNames) do
        connection:sendEvent(NetworkEventType.RAN_NAME_CHANGED, animalId, name, g_currentTime)
    end
end

---Find animal by ID (for MP sync)
function RealisticAnimalNames:findAnimalById(animalId)
    if not self.mission.animalSystem then return nil end
    
    -- Parse farm ID and animal ID
    local farmId, id = animalId:match("^(%d+)_(%d+)$")
    if not farmId then
        id = animalId
    end
    
    for _, cluster in pairs(self.mission.animalSystem.clusters) do
        if cluster.animals then
            for _, animal in pairs(cluster.animals) do
                if animal and animal.id == tonumber(id) then
                    return animal
                end
            end
        end
    end
    
    return nil
end

---Clean up name when animal is removed/sold
function RealisticAnimalNames:onAnimalRemoved(animal)
    if not animal then return end
    
    local animalId = self:getAnimalId(animal)
    if animalId and self.animalNames[animalId] then
        self.animalNames[animalId] = nil
        print("[RealisticAnimalNames] Cleaned up name for removed animal:", animalId)
        
        -- Save changes
        if self.isServer then
            self:scheduleSave()
        end
    end
    
    -- Clean cache
    if animal.nodeId then
        self.nameCache[animal.nodeId] = nil
    end
end

---Schedule a save operation (debounced)
function RealisticAnimalNames:scheduleSave()
    if not self.isServer then return end
    
    self.savePending = true
    self.saveTimer = SAVE_DEBOUNCE_INTERVAL
end

---Save animal names to savegame
function RealisticAnimalNames:saveToSavegame()
    if not self.isServer then return end
    
    local filename = self:getSavegameFilePath()
    if not filename then
        print("[RealisticAnimalNames] Cannot save - no savegame directory")
        return false
    end
    
    -- Use pcall to prevent crashes
    local success, xmlFile = pcall(function()
        return XMLFile.create("animalNamesXML", filename, "animalNames")
    end)
    
    if not success or not xmlFile then
        print("[RealisticAnimalNames] Failed to create XML file")
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
    
    -- Save version info
    xmlFile:setValue("animalNames#version", "2.1.0.0")
    xmlFile:setValue("animalNames#count", index)
    
    xmlFile:save()
    xmlFile:delete()
    
    print(string.format("[RealisticAnimalNames] Saved %d animal names", index))
    return true
end

---Get savegame file path
function RealisticAnimalNames:getSavegameFilePath()
    if self.mission.missionInfo and self.mission.missionInfo.savegameDirectory then
        return self.mission.missionInfo.savegameDirectory .. "/" .. SAVE_FILE_NAME
    end
    return nil
end

---Load animal names from savegame
function RealisticAnimalNames:loadFromSavegame()
    if not self.isServer then return end
    
    local filename = self:getSavegameFilePath()
    if not filename or not fileExists(filename) then
        print("[RealisticAnimalNames] No existing savegame data found")
        return
    end
    
    local xmlFile = XMLFile.load("animalNamesXML", filename)
    if not xmlFile then
        print("[RealisticAnimalNames] Failed to load savegame data")
        return
    end
    
    -- Clear existing data
    self.animalNames = {}
    
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
    
    local version = xmlFile:getValue("animalNames#version") or "1.0.0"
    xmlFile:delete()
    
    print(string.format("[RealisticAnimalNames] Loaded %d animal names (v%s)", index, version))
end

---PERFORMANCE OPTIMIZATION: Draw floating name tags
function RealisticAnimalNames:draw()
    if not self.isInitialized or not self.settings.showNames then
        return
    end
    
    if not self.mission.animalSystem or not self.mission.animalSystem.clusters then
        return
    end
    
    local camera = getCamera()
    if not camera then return end
    
    local camX, camY, camZ = getWorldTranslation(camera)
    local maxDistance = self.settings.nameDistance
    
    -- Set text rendering properties once
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
    setTextBold(true)
    
    -- PERFORMANCE: Only render a subset of animals per frame
    -- Spread rendering across frames to avoid FPS drops
    local animalsRendered = 0
    local startIndex = self.animalUpdateIndex
    
    -- Iterate through clusters with frame-slicing
    for idx = startIndex, #self.mission.animalSystem.clusters do
        if animalsRendered >= PERFORMANCE_MAX_ANIMALS_PER_FRAME then
            self.animalUpdateIndex = idx
            break
        end
        
        local cluster = self.mission.animalSystem.clusters[idx]
        if cluster and cluster.animals then
            for _, animal in pairs(cluster.animals) do
                if animalsRendered >= PERFORMANCE_MAX_ANIMALS_PER_FRAME then
                    break
                end
                
                if self:isValidAnimal(animal) then
                    -- Fast path: use cache if available
                    local name
                    if animal.nodeId and self.nameCache[animal.nodeId] then
                        name = self.nameCache[animal.nodeId]
                    else
                        local animalId = self:getAnimalId(animal)
                        name = self.animalNames[animalId]
                        if animal.nodeId and name then
                            self.nameCache[animal.nodeId] = name
                        end
                    end
                    
                    if name and name ~= "" then
                        -- Get animal position
                        local x, y, z = getWorldTranslation(animal.nodeId)
                        
                        -- OPTIMIZATION: Quick distance check (no sqrt)
                        local dx, dy, dz = camX - x, camY - y, camZ - z
                        local distSq = dx*dx + dy*dy + dz*dz
                        local maxDistSq = maxDistance * maxDistance
                        
                        if distSq < maxDistSq then
                            local distance = math.sqrt(distSq)
                            
                            -- Calculate display position
                            local displayY = y + self.settings.nameHeight
                            
                            -- Alpha based on distance
                            local alpha = 1.0 - (distance / maxDistance)
                            alpha = math.max(0.3, math.min(1.0, alpha))
                            
                            -- Scale based on distance (slightly larger when farther)
                            local scale = self.settings.fontSize * (1.0 + (distance / maxDistance) * 0.5)
                            
                            -- Render
                            setTextColor(1, 1, 1, alpha)
                            renderText3D(x, displayY, z, 0, 0, 0, scale, name)
                            
                            animalsRendered = animalsRendered + 1
                        end
                    end
                end
            end
        end
    end
    
    -- Reset update index for next frame
    if self.animalUpdateIndex >= #self.mission.animalSystem.clusters then
        self.animalUpdateIndex = 1
    end
    
    -- Reset text properties
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
    setTextBold(false)
    setTextColor(1, 1, 1, 1)
end

---Update (called every frame)
function RealisticAnimalNames:update(dt)
    if not self.isInitialized then return end
    
    -- Periodic settings refresh
    self:loadSettingsFromGame()
    
    -- Handle debounced save
    if self.savePending then
        self.saveTimer = self.saveTimer - dt
        if self.saveTimer <= 0 then
            self:saveToSavegame()
            self.savePending = false
        end
    end
end

---Called when mission is being deleted
function RealisticAnimalNames:onMissionDelete()
    print("[RealisticAnimalNames] Cleaning up...")
    
    -- Final save
    if self.isServer and self.savePending then
        self:saveToSavegame()
    end
    
    -- Unregister input action
    if self.actionEventId and self.inputManager then
        pcall(function()
            self.inputManager:removeActionEvent(self.actionEventId)
        end)
        self.actionEventId = nil
    end
    
    -- Clear data
    self.animalNames = {}
    self.nameCache = {}
    self.currentAnimal = nil
    self.isInitialized = false
    self.dialogLoaded = false
    
    print("[RealisticAnimalNames] Cleanup complete")
end

---Show a localized notification
function RealisticAnimalNames:showNotification(textKey, notificationType)
    if not self.isClient then return end
    
    local text = self.i18n:getText(textKey)
    if text and text ~= "" and text ~= textKey then
        g_currentMission:addIngameNotification(notificationType or FSBaseMission.INGAME_NOTIFICATION_INFO, text)
    end
end

---Get animal name by ID (API for other mods)
function RealisticAnimalNames:getAnimalName(animalId)
    return self.animalNames[animalId]
end

---Get all animal names (API for other mods)
function RealisticAnimalNames:getAllAnimalNames()
    local copy = {}
    for k, v in pairs(self.animalNames) do
        copy[k] = v
    end
    return copy
end

---Clear all animal names
function RealisticAnimalNames:clearAllAnimalNames()
    if not self.isServer then
        -- Client: request server to clear all
        if self.isMultiplayer then
            -- Request each name to be cleared
            for animalId, _ in pairs(self.animalNames) do
                self:requestNameChange(animalId, "")
            end
        end
        return
    end
    
    self.animalNames = {}
    self.nameCache = {}
    
    self:scheduleSave()
    self:showNotification("ran_notification_allNamesCleared", FSBaseMission.INGAME_NOTIFICATION_OK)
    
    -- Broadcast to clients
    if self.isMultiplayer then
        for animalId, _ in pairs(self.animalNames) do
            self:broadcastNameChange(animalId, "")
        end
    end
end

-- ============================================================================
-- Network Event Definitions
-- ============================================================================

NetworkEventType = NetworkEventType or {}
NetworkEventType.RAN_REQUEST_NAME_CHANGE = "RAN_REQUEST_NAME_CHANGE"
NetworkEventType.RAN_NAME_CHANGED = "RAN_NAME_CHANGED"
NetworkEventType.RAN_REQUEST_SYNC = "RAN_REQUEST_SYNC"

-- ============================================================================
-- Global Registration
-- ============================================================================

---FS25 Mod System Integration
---This is the standard way FS25 loads mods

local modInstance = nil

---@param mission table Mission instance
local function registerMod(mission)
    if modInstance then
        removeModEventListener(modInstance)
        if modInstance.onMissionDelete then
            modInstance:onMissionDelete()
        end
        modInstance = nil
    end
    
    modInstance = RealisticAnimalNames:new(
        mission,
        g_currentModDirectory,
        g_currentModName
    )
    
    addModEventListener(modInstance)
    print("[RealisticAnimalNames] Registered with mission")
end

---@param mission table Mission instance
local function unregisterMod(mission)
    if modInstance then
        removeModEventListener(modInstance)
        if modInstance.onMissionDelete then
            modInstance:onMissionDelete()
        end
        modInstance = nil
        print("[RealisticAnimalNames] Unregistered")
    end
end

-- Hook into mission lifecycle using standard FS25 pattern
FSBaseMission.onMissionLoaded = Utils.appendedFunction(FSBaseMission.onMissionLoaded, function(mission)
    registerMod(mission)
end)

FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, function(mission)
    unregisterMod(mission)
end)

-- Add draw hook
local originalDraw = FSBaseMission.draw
FSBaseMission.draw = function(self, ...)
    if originalDraw then
        originalDraw(self, ...)
    end
    
    if modInstance and modInstance.isInitialized then
        local success, err = pcall(function()
            modInstance:draw()
        end)
        if not success then
            print("[RealisticAnimalNames] Draw error:", err)
        end
    end
end

-- Add update hook
local originalUpdate = FSBaseMission.update
FSBaseMission.update = function(self, dt, ...)
    if originalUpdate then
        originalUpdate(self, dt, ...)
    end
    
    if modInstance and modInstance.isInitialized then
        local success, err = pcall(function()
            modInstance:update(dt)
        end)
        if not success then
            print("[RealisticAnimalNames] Update error:", err)
        end
    end
end

print("[RealisticAnimalNames] Mod initialized successfully")