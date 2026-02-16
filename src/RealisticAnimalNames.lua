-- ============================================================================
-- Realistic Animal Names for FS25 - PROFESSIONAL EDITION v2.2.0.0
-- ============================================================================
-- Author: TisonK
-- Description: Custom animal names with floating tags, multiplayer sync
-- ============================================================================

---@class RealisticAnimalNames
RealisticAnimalNames = {}
RealisticAnimalNames.__index = RealisticAnimalNames

-- Constants
local SAVE_FILE_NAME = "realisticAnimalNames.xml"
local SAVE_DEBOUNCE_INTERVAL = 500 -- ms
local MAX_NAME_LENGTH = 30
local PERFORMANCE_MAX_ANIMALS_PER_FRAME = 50
local NETWORK_TIMEOUT = 5000 -- ms for sync requests

---Initialize the mod
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
    self.animalNames = {}      -- farmId_animalId -> name
    self.nameCache = {}        -- nodeId -> name (fast lookup)
    self.pendingSync = {}       -- Pending sync requests (MP client)
    
    -- Settings with defaults
    self.settings = {
        showNames = true,
        nameDistance = 15,
        nameHeight = 1.8,
        fontSize = 0.018
    }
    
    -- Performance optimization
    self.nearbyAnimals = { cacheTime = 0 }
    self.animalUpdateIndex = 1
    self.lastClusterCount = 0
    
    -- UI State
    self.dialog = nil
    self.currentAnimal = nil
    self.dialogLoaded = false
    
    -- Save management
    self.savePending = false
    self.saveTimer = 0
    
    -- Network
    self.networkEventsRegistered = false
    self.syncRequestTimer = 0
    self.syncRequested = false
    
    -- Initialization state
    self.isInitialized = false
    self.actionEventId = nil
    
    -- Debug mode (disable in production)
    self.debug = false
    
    print("[RAN] Instance created (Server:", self.isServer, "Client:", self.isClient, "MP:", self.isMultiplayer, ")")
    
    return self
end

-- ============================================================================
-- INITIALIZATION & LIFECYCLE
-- ============================================================================

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
    
    -- Register network events
    self:registerNetworkEvents()
    
    -- Request sync from server if we're a client in multiplayer
    if self.isMultiplayer and self.isClient and not self.isServer then
        self:requestSyncFromServer()
    end
    
    self.isInitialized = true
    
    -- Welcome notification (clients only)
    if self.isClient then
        self:showNotification("ran_notification_loaded", FSBaseMission.INGAME_NOTIFICATION_INFO)
    end
    
    self:log("Mission loaded successfully")
end

---Register all event listeners
function RealisticAnimalNames:registerEventListeners()
    if not self.mission then return end
    
    -- Animal removal listener
    if self.mission.animalSystem and self.mission.animalSystem.addRemoveAnimalListener then
        self.mission.animalSystem:addRemoveAnimalListener(function(animal, isAdded)
            if not isAdded then
                self:onAnimalRemoved(animal)
            end
        end)
    end
    
    -- Settings change listener
    if g_gameSettings and g_gameSettings.addSettingsChangeListener then
        g_gameSettings:addSettingsChangeListener(function(name, value)
            if name:find("^ran_") then
                self:onSettingsChanged(name, value)
            end
        end)
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
            false,  -- onDown
            true,   -- onUp
            false,  -- onEvent
            true    -- always
        )
    end)
    
    if success and actionEventId then
        self.actionEventId = actionEventId
        self.inputManager:setActionEventTextVisibility(actionEventId, false)
        self.inputManager:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
        self:log("Input action registered")
    else
        print("[RAN] ERROR: Failed to register input action")
    end
end

---Async GUI loading to prevent frame drops
function RealisticAnimalNames:loadGUIAsync()
    local xmlFilename = self.modDirectory .. "gui/AnimalNamesDialog.xml"
    
    if not fileExists(xmlFilename) then
        print("[RAN] ERROR: GUI file not found: " .. xmlFilename)
        return
    end
    
    -- Defer GUI loading to next frame
    self:scheduleCallback(function()
        local success, dialog = pcall(function()
            return self.gui:loadGui(xmlFilename, "AnimalNamesDialog", self)
        end)
        
        if success and dialog then
            self.dialogLoaded = true
            self:log("GUI loaded")
        else
            print("[RAN] ERROR: Failed to load GUI")
        end
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
            if not success and self.debug then
                print("[RAN] Callback error:", err)
            end
        end
    end
    
    if delayFrames > 0 then
        g_currentMission:addUpdateCallback(execute)
    else
        execute()
    end
end

-- ============================================================================
-- SETTINGS MANAGEMENT
-- ============================================================================

---Load settings from game settings system
function RealisticAnimalNames:loadSettingsFromGame()
    if not g_gameSettings then return end
    
    local showNames = g_gameSettings:getValue("ran_showNames")
    local nameDistance = g_gameSettings:getValue("ran_nameDistance")
    local nameHeight = g_gameSettings:getValue("ran_nameHeight")
    local fontSize = g_gameSettings:getValue("ran_fontSize")
    
    if showNames ~= nil then self.settings.showNames = showNames end
    if nameDistance ~= nil then self.settings.nameDistance = nameDistance end
    if nameHeight ~= nil then self.settings.nameHeight = nameHeight end
    if fontSize ~= nil then self.settings.fontSize = fontSize end
end

---Settings changed callback
function RealisticAnimalNames:onSettingsChanged(name, value)
    local settingMap = {
        ran_showNames = "showNames",
        ran_nameDistance = "nameDistance",
        ran_nameHeight = "nameHeight",
        ran_fontSize = "fontSize"
    }
    
    local key = settingMap[name]
    if key then
        self.settings[key] = value
        self:log("Setting changed:", name, value)
    end
end

-- ============================================================================
-- ANIMAL DETECTION & IDENTIFICATION
-- ============================================================================

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

---Find closest animal using spatial proximity (optimized)
function RealisticAnimalNames:getClosestAnimal(maxDistance)
    if not self.mission.animalSystem or not self.mission.animalSystem.clusters then
        return nil
    end
    
    local camera = getCamera()
    if not camera then return nil end
    
    local camX, camY, camZ = getWorldTranslation(camera)
    local closestAnimal = nil
    local closestDistance = maxDistance
    
    -- Use cache if recent (200ms)
    if self.nearbyAnimals.cacheTime and g_currentTime - self.nearbyAnimals.cacheTime < 200 then
        return self.nearbyAnimals.closest
    end
    
    -- Iterate with performance limit
    local animalsChecked = 0
    local maxCheck = 200
    
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
    -- Use farm ID + animal ID for uniqueness across farms
    local farmId = animal.ownerFarmId or 1
    return string.format("%d_%d", farmId, animal.id)
end

---Get display name for animal (custom or default)
function RealisticAnimalNames:getAnimalDisplayName(animal)
    if not animal then return "" end
    
    local animalId = self:getAnimalId(animal)
    local customName = self.animalNames[animalId]
    
    if customName and customName ~= "" then
        return customName
    end
    
    return self:getDefaultAnimalName(animal)
end

---Get default localized name for animal type
function RealisticAnimalNames:getDefaultAnimalName(animal)
    if not animal or not animal.animalType then
        return "Animal"
    end
    
    -- Try to get localized name
    local typeKey = string.format("animal_%s", animal.animalType)
    local localizedName = self.i18n and self.i18n:getText(typeKey)
    
    if localizedName and localizedName ~= typeKey then
        return localizedName
    end
    
    -- Fallback
    return animal.animalType or "Animal"
end

---Find animal by ID (for MP sync)
function RealisticAnimalNames:findAnimalById(animalId)
    if not self.mission.animalSystem or not self.mission.animalSystem.clusters then
        return nil
    end
    
    -- Parse farm ID and animal ID
    local farmId, id = animalId:match("^(%d+)_(%d+)$")
    if not farmId then
        id = animalId
    end
    
    local targetId = tonumber(id)
    if not targetId then return nil end
    
    for _, cluster in pairs(self.mission.animalSystem.clusters) do
        if cluster.animals then
            for _, animal in pairs(cluster.animals) do
                if animal and animal.id == targetId then
                    return animal
                end
            end
        end
    end
    
    return nil
end

---Clean up when animal is removed
function RealisticAnimalNames:onAnimalRemoved(animal)
    if not animal then return end
    
    local animalId = self:getAnimalId(animal)
    if animalId and self.animalNames[animalId] then
        self.animalNames[animalId] = nil
        self:log("Cleaned up name for removed animal:", animalId)
        
        if self.isServer then
            self:scheduleSave()
        end
    end
    
    if animal.nodeId then
        self.nameCache[animal.nodeId] = nil
    end
end

-- ============================================================================
-- UI DIALOG MANAGEMENT
-- ============================================================================

---Open naming dialog for an animal
function RealisticAnimalNames:openDialogForAnimal(animal)
    if not animal or not self.dialogLoaded then return end
    
    self.currentAnimal = animal
    local animalId = self:getAnimalId(animal)
    local currentName = self.animalNames[animalId] or ""
    
    local success, dialog = pcall(function()
        return self.gui:showDialog("AnimalNamesDialog")
    end)
    
    if success and dialog and dialog.setAnimal then
        dialog:setAnimal(animal, currentName)
    else
        print("[RAN] ERROR: Failed to open dialog")
    end
end

---Set animal name (called from UI)
function RealisticAnimalNames:setAnimalName(animal, name)
    if not animal then return false end
    
    local animalId = self:getAnimalId(animal)
    if not animalId then return false end
    
    name = name and self:sanitizeName(tostring(name)) or ""
    
    if name == "" then
        return self:resetAnimalName(animal)
    end
    
    -- In multiplayer, client sends request to server
    if self.isMultiplayer and not self.isServer then
        self:requestNameChange(animalId, name)
        return true -- Optimistic
    end
    
    -- Store the name
    self.animalNames[animalId] = name
    
    -- Update cache
    if animal.nodeId then
        self.nameCache[animal.nodeId] = name
    end
    
    -- Save (server only)
    if self.isServer then
        self:scheduleSave()
    end
    
    -- Broadcast to clients (server in MP)
    if self.isMultiplayer and self.isServer then
        self:broadcastNameChange(animalId, name)
    end
    
    self:showNotificationWithParam("ran_notification_nameSet", name, FSBaseMission.INGAME_NOTIFICATION_OK)
    return true
end

---Reset animal name to default
function RealisticAnimalNames:resetAnimalName(animal)
    if not animal then return false end
    
    local animalId = self:getAnimalId(animal)
    if not animalId then return false end
    
    -- Client sends request to server
    if self.isMultiplayer and not self.isServer then
        self:requestNameChange(animalId, "")
        return true
    end
    
    -- Remove the name
    self.animalNames[animalId] = nil
    
    if animal.nodeId then
        self.nameCache[animal.nodeId] = nil
    end
    
    if self.isServer then
        self:scheduleSave()
    end
    
    if self.isMultiplayer and self.isServer then
        self:broadcastNameChange(animalId, "")
    end
    
    self:showNotification("ran_notification_nameReset", FSBaseMission.INGAME_NOTIFICATION_OK)
    return true
end

---Sanitize and validate name string (UTF-8 safe)
function RealisticAnimalNames:sanitizeName(name)
    if not name then return "" end
    
    -- Trim whitespace
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    
    -- Remove control characters
    name = name:gsub("[%c]", "")
    
    -- Limit length (UTF-8 safe)
    local len = self:utf8len(name)
    if len > MAX_NAME_LENGTH then
        -- Truncate at character boundary
        local truncated = ""
        local count = 0
        for char in string.gmatch(name, "[%z\1-\127\194-\244][\128-\191]*") do
            if count < MAX_NAME_LENGTH then
                truncated = truncated .. char
                count = count + 1
            else
                break
            end
        end
        name = truncated
    end
    
    return name
end

---UTF-8 string length
function RealisticAnimalNames:utf8len(str)
    if not str then return 0 end
    local len = 0
    for _ in string.gmatch(str, "[%z\1-\127\194-\244][\128-\191]*") do
        len = len + 1
    end
    return len
end

---Clear all animal names
function RealisticAnimalNames:clearAllAnimalNames()
    if not self.isServer then
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
    
    if self.isMultiplayer then
        for animalId, _ in pairs(self.animalNames) do
            self:broadcastNameChange(animalId, "")
        end
    end
end

-- ============================================================================
-- MULTIPLAYER NETWORKING
-- ============================================================================

---Register network events
function RealisticAnimalNames:registerNetworkEvents()
    if self.networkEventsRegistered then return end
    if not g_network then return end
    
    -- Define network event types
    NetworkEventType = NetworkEventType or {}
    NetworkEventType.RAN_REQUEST_NAME_CHANGE = "RAN_REQUEST_NAME_CHANGE"
    NetworkEventType.RAN_NAME_CHANGED = "RAN_NAME_CHANGED"
    NetworkEventType.RAN_REQUEST_SYNC = "RAN_REQUEST_SYNC"
    NetworkEventType.RAN_SYNC_COMPLETE = "RAN_SYNC_COMPLETE"
    
    -- Register events with error handling
    local function registerEvent(name, handler)
        local success, err = pcall(function()
            g_network:addEvent(name, handler)
        end)
        if not success and self.debug then
            print("[RAN] Network event registration failed:", name, err)
        end
        return success
    end
    
    -- Server: handle client requests
    if self.isServer then
        registerEvent(NetworkEventType.RAN_REQUEST_NAME_CHANGE, 
            function(connection, animalId, newName, userId)
                self:onNameChangeRequest(connection, animalId, newName, userId)
            end)
        
        registerEvent(NetworkEventType.RAN_REQUEST_SYNC,
            function(connection, userId)
                self:onSyncRequest(connection, userId)
            end)
    end
    
    -- Client: handle server broadcasts
    if self.isClient then
        registerEvent(NetworkEventType.RAN_NAME_CHANGED,
            function(connection, animalId, newName, serverTime)
                self:onNameChangedFromServer(animalId, newName, serverTime)
            end)
        
        registerEvent(NetworkEventType.RAN_SYNC_COMPLETE,
            function(connection)
                self:onSyncComplete()
            end)
    end
    
    self.networkEventsRegistered = true
    self:log("Network events registered")
end

---Request name change from server (client)
function RealisticAnimalNames:requestNameChange(animalId, name)
    if not self.isMultiplayer or not g_network then return end
    
    local connection = g_network:getServerConnection()
    if connection then
        connection:sendEvent(NetworkEventType.RAN_REQUEST_NAME_CHANGE, 
            animalId, 
            name, 
            g_currentMission.playerUserId
        )
        self:log("Name change request sent:", animalId, name)
    end
end

---Handle name change request (server)
function RealisticAnimalNames:onNameChangeRequest(connection, animalId, newName, userId)
    if not self.isServer then return end
    
    self:log("Name change request from user", userId, "for", animalId)
    
    local animal = self:findAnimalById(animalId)
    if animal then
        if newName == "" then
            self.animalNames[animalId] = nil
        else
            self.animalNames[animalId] = self:sanitizeName(newName)
        end
        
        self:scheduleSave()
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
    
    self:log("Name updated from server:", animalId, newName)
end

---Request full sync from server (client)
function RealisticAnimalNames:requestSyncFromServer()
    if not self.isMultiplayer or not g_network then return end
    
    local connection = g_network:getServerConnection()
    if connection then
        connection:sendEvent(NetworkEventType.RAN_REQUEST_SYNC, g_currentMission.playerUserId)
        self.syncRequested = true
        self.syncRequestTimer = NETWORK_TIMEOUT
        self:log("Requested sync from server")
    end
end

---Handle sync request (server)
function RealisticAnimalNames:onSyncRequest(connection, userId)
    if not self.isServer then return end
    
    self:log("Sending sync to user", userId)
    
    -- Send all names to requesting client
    local count = 0
    for animalId, name in pairs(self.animalNames) do
        connection:sendEvent(NetworkEventType.RAN_NAME_CHANGED, animalId, name, g_currentTime)
        count = count + 1
    end
    
    -- Send completion marker
    connection:sendEvent(NetworkEventType.RAN_SYNC_COMPLETE)
    self:log("Sync complete, sent", count, "names")
end

---Handle sync complete (client)
function RealisticAnimalNames:onSyncComplete()
    self.syncRequested = false
    self:log("Sync from server complete")
end

-- ============================================================================
-- SAVE/LOAD SYSTEM
-- ============================================================================

---Schedule a save operation (debounced)
function RealisticAnimalNames:scheduleSave()
    if not self.isServer then return end
    
    self.savePending = true
    self.saveTimer = SAVE_DEBOUNCE_INTERVAL
end

---Save animal names to savegame
function RealisticAnimalNames:saveToSavegame()
    if not self.isServer then return false end
    
    local filename = self:getSavegameFilePath()
    if not filename then
        print("[RAN] Cannot save - no savegame directory")
        return false
    end
    
    -- Use Giants XML API
    local xmlFile = XMLFile.create("animalNamesXML", filename, "animalNames")
    if not xmlFile then
        print("[RAN] Failed to create XML file")
        return false
    end
    
    -- Save all animal names
    local index = 0
    for animalId, name in pairs(self.animalNames) do
        if name and name ~= "" then
            local key = string.format("animalNames.animal(%d)", index)
            xmlFile:setValue(key .. "#id", animalId)
            xmlFile:setValue(key, name) -- Store name as element value
            index = index + 1
        end
    end
    
    xmlFile:setValue("animalNames#version", "2.2.0.0")
    xmlFile:setValue("animalNames#count", index)
    
    xmlFile:save()
    xmlFile:delete()
    
    self:log("Saved", index, "animal names")
    return true
end

---Load animal names from savegame
function RealisticAnimalNames:loadFromSavegame()
    if not self.isServer then return end
    
    local filename = self:getSavegameFilePath()
    if not filename or not fileExists(filename) then
        self:log("No existing savegame data found")
        return
    end
    
    local xmlFile = XMLFile.load("animalNamesXML", filename)
    if not xmlFile then
        print("[RAN] Failed to load savegame data")
        return
    end
    
    self.animalNames = {}
    
    local index = 0
    while true do
        local key = string.format("animalNames.animal(%d)", index)
        local animalId = xmlFile:getValue(key .. "#id")
        local name = xmlFile:getValue(key)
        
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
    
    self:log("Loaded", index, "animal names (v" .. version .. ")")
end

---Get savegame file path
function RealisticAnimalNames:getSavegameFilePath()
    if self.mission.missionInfo and self.mission.missionInfo.savegameDirectory then
        return self.mission.missionInfo.savegameDirectory .. "/" .. SAVE_FILE_NAME
    end
    return nil
end

-- ============================================================================
-- RENDERING (FLOATING NAMES)
-- ============================================================================

---Draw floating name tags (frame-sliced for performance)
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
    local maxDistSq = maxDistance * maxDistance
    
    -- Set text rendering properties
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
    setTextBold(true)
    
    -- Frame-sliced rendering
    local animalsRendered = 0
    local clusters = self.mission.animalSystem.clusters
    
    -- Reset index if needed
    if self.animalUpdateIndex > #clusters then
        self.animalUpdateIndex = 1
    end
    
    -- Process clusters in slices
    for idx = self.animalUpdateIndex, #clusters do
        if animalsRendered >= PERFORMANCE_MAX_ANIMALS_PER_FRAME then
            self.animalUpdateIndex = idx
            break
        end
        
        local cluster = clusters[idx]
        if cluster and cluster.animals then
            for _, animal in pairs(cluster.animals) do
                if animalsRendered >= PERFORMANCE_MAX_ANIMALS_PER_FRAME then
                    break
                end
                
                if self:isValidAnimal(animal) then
                    -- Get name (use cache for speed)
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
                        local x, y, z = getWorldTranslation(animal.nodeId)
                        
                        -- Quick distance check
                        local dx, dy, dz = camX - x, camY - y, camZ - z
                        local distSq = dx*dx + dy*dy + dz*dz
                        
                        if distSq < maxDistSq then
                            local distance = math.sqrt(distSq)
                            local displayY = y + self.settings.nameHeight
                            
                            -- Alpha fade with distance
                            local alpha = 1.0 - (distance / maxDistance)
                            alpha = math.max(0.3, math.min(1.0, alpha))
                            
                            -- Scale with distance (slightly larger when farther)
                            local scale = self.settings.fontSize * (1.0 + (distance / maxDistance) * 0.5)
                            
                            setTextColor(1, 1, 1, alpha)
                            renderText3D(x, displayY, z, 0, 0, 0, scale, name)
                            
                            animalsRendered = animalsRendered + 1
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

-- ============================================================================
-- UPDATE LOOP
-- ============================================================================

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
    
    -- Handle sync timeout
    if self.syncRequested then
        self.syncRequestTimer = self.syncRequestTimer - dt
        if self.syncRequestTimer <= 0 then
            self.syncRequested = false
            self:log("Sync request timed out")
        end
    end
end

---Called when mission is being deleted
function RealisticAnimalNames:onMissionDelete()
    self:log("Cleaning up...")
    
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
    
    self:log("Cleanup complete")
end

-- ============================================================================
-- UTILITIES
-- ============================================================================

---Show localized notification
function RealisticAnimalNames:showNotification(textKey, notificationType)
    if not self.isClient or not self.i18n then return end
    
    local text = self.i18n:getText(textKey)
    if text and text ~= "" and text ~= textKey then
        g_currentMission:addIngameNotification(notificationType or FSBaseMission.INGAME_NOTIFICATION_INFO, text)
    end
end

---Show notification with parameter
function RealisticAnimalNames:showNotificationWithParam(textKey, param, notificationType)
    if not self.isClient or not self.i18n then return end
    
    local text = self.i18n:getText(textKey)
    if text and text ~= "" and text ~= textKey then
        local formatted = text:format(param)
        g_currentMission:addIngameNotification(notificationType or FSBaseMission.INGAME_NOTIFICATION_INFO, formatted)
    end
end

---Log debug message
function RealisticAnimalNames:log(...)
    if self.debug then
        print("[RAN]", ...)
    end
end

-- ============================================================================
-- API FOR OTHER MODS
-- ============================================================================

---Get animal name by ID
function RealisticAnimalNames:getAnimalName(animalId)
    return self.animalNames[animalId]
end

---Get all animal names
function RealisticAnimalNames:getAllAnimalNames()
    local copy = {}
    for k, v in pairs(self.animalNames) do
        copy[k] = v
    end
    return copy
end

---Get animal name by node ID (for mod integration)
function RealisticAnimalNames:getNameByNodeId(nodeId)
    return self.nameCache[nodeId]
end

-- ============================================================================
-- GLOBAL REGISTRATION (FS25 Standard)
-- ============================================================================

local modInstance = nil

---Register mod with mission
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
    print("[RAN] Registered with mission")
end

---Unregister mod
local function unregisterMod(mission)
    if modInstance then
        removeModEventListener(modInstance)
        if modInstance.onMissionDelete then
            modInstance:onMissionDelete()
        end
        modInstance = nil
        print("[RAN] Unregistered")
    end
end

-- Hook into mission lifecycle
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
            print("[RAN] Draw error:", err)
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
            print("[RAN] Update error:", err)
        end
    end
end

print("[RAN] Mod initialized successfully (v2.2.0.0)")