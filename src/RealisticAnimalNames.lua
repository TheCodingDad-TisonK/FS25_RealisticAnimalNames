-- ============================================================================
-- Realistic Animal Names for FS25 v2.2.0.0
-- ============================================================================
-- Author: TisonK
-- Description: Custom animal names with floating multi-line tags, MP sync
-- ============================================================================

---@class RealisticAnimalNames
RealisticAnimalNames = {}
RealisticAnimalNames.__index = RealisticAnimalNames

-- Constants
local SAVE_FILE_NAME            = "realisticAnimalNames.xml"
local SAVE_DEBOUNCE_INTERVAL    = 500   -- ms; debounce rapid successive saves
local MAX_NAME_LENGTH           = 30
local SETTINGS_REFRESH_INTERVAL = 2000  -- ms; how often to re-read g_gameSettings
local TAG_LINE_SPACING          = 0.32  -- world-space meters between tag lines

-- ============================================================================
-- CONSTRUCTOR
-- ============================================================================

---@param mission      table  Mission instance
---@param modDirectory string Mod folder path
---@param modName      string Mod name
function RealisticAnimalNames:new(mission, modDirectory, modName)
    local self = setmetatable({}, RealisticAnimalNames)

    -- Core references
    self.mission      = mission
    self.modDirectory = modDirectory
    self.modName      = modName
    self.i18n         = g_i18n
    self.gui          = g_gui
    self.inputManager = g_inputBinding

    -- Multiplayer state
    self.isServer      = mission:getIsServer()
    self.isClient      = mission:getIsClient()
    self.isMultiplayer = mission:getIsMultiplayer()

    -- Data storage
    self.animalNames = {}   -- "farmId_animalId" → name string
    self.nameCache   = {}   -- nodeId           → name string (fast draw lookup)

    -- Settings with defaults (overwritten from g_gameSettings in loadSettingsFromGame)
    self.settings = {
        showNames    = true,
        showDetails  = true,    -- show type + age lines under the name
        nameDistance = 15,
        nameHeight   = 1.8,
        fontSize     = 0.018,
    }

    -- UI state
    self.currentAnimal  = nil
    self.dialogLoaded   = false
    self.guiLoadPending = false  -- GUI is loaded on the first update tick

    -- Save management
    self.savePending = false
    self.saveTimer   = 0

    -- Periodic settings refresh (avoids re-reading g_gameSettings every frame)
    self.settingsRefreshTimer = 0

    -- Initial MP sync
    self.syncRequestPending = false
    self.syncRequestTimer   = 0

    -- Input / lifecycle
    self.isInitialized = false
    self.actionEventId = nil

    self.debug = false

    print("[RAN] Instance created (Server:", self.isServer,
          "Client:", self.isClient, "MP:", self.isMultiplayer, ")")
    return self
end

-- ============================================================================
-- INITIALIZATION & LIFECYCLE
-- ============================================================================

---Called after the mission finishes loading
function RealisticAnimalNames:onMissionLoaded(mission)
    self.mission = mission

    -- Server loads persistent name data from savegame XML
    if self.isServer then
        self:loadFromSavegame()
    end

    -- Client registers the keybind and queues GUI load for the next update tick
    if self.isClient then
        self:registerInputActions()
        self.guiLoadPending = true
    end

    -- Both sides read settings from the game-settings system
    self:loadSettingsFromGame()

    -- Subscribe to animal removal so stale entries are cleaned up
    self:registerEventListeners()

    -- Newly joined MP client requests the server's current name table
    if self.isMultiplayer and self.isClient and not self.isServer then
        self.syncRequestPending = true
        self.syncRequestTimer   = 1000  -- 1-second delay so the connection stabilises
    end

    self.isInitialized = true

    if self.isClient then
        self:showNotification("ran_notification_loaded", FSBaseMission.INGAME_NOTIFICATION_INFO)
    end

    self:log("Mission loaded successfully")
end

---Subscribe to engine-level events
function RealisticAnimalNames:registerEventListeners()
    if not self.mission then return end

    if self.mission.animalSystem and self.mission.animalSystem.addRemoveAnimalListener then
        self.mission.animalSystem:addRemoveAnimalListener(function(animal, isAdded)
            if not isAdded then self:onAnimalRemoved(animal) end
        end)
    end
end

---Register the K-key input action (client only)
function RealisticAnimalNames:registerInputActions()
    if not self.inputManager then return end

    local success, actionEventId = pcall(function()
        return self.inputManager:registerActionEvent(
            InputAction.RAN_OPEN_UI,
            self,
            self.onOpenUIInput,
            false, true, false, true
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

---Load the naming dialog XML (called from update on the first tick)
function RealisticAnimalNames:doLoadGUI()
    local xmlFilename = self.modDirectory .. "gui/AnimalNamesDialog.xml"
    if not fileExists(xmlFilename) then
        print("[RAN] ERROR: GUI file not found: " .. xmlFilename)
        return
    end

    local success = pcall(function()
        self.gui:loadGui(xmlFilename, "AnimalNamesDialog", self)
    end)

    if success then
        self.dialogLoaded = true
        self:log("GUI loaded")
    else
        print("[RAN] ERROR: Failed to load GUI")
    end
end

-- ============================================================================
-- SETTINGS
-- ============================================================================

---Read all mod settings from the FS25 game-settings system
function RealisticAnimalNames:loadSettingsFromGame()
    if not g_gameSettings then return end

    local function get(key) return g_gameSettings:getValue(key) end

    local v
    v = get("ran_showNames");    if v ~= nil then self.settings.showNames    = v end
    v = get("ran_showDetails");  if v ~= nil then self.settings.showDetails  = v end
    v = get("ran_nameDistance"); if v ~= nil then self.settings.nameDistance = v end
    v = get("ran_nameHeight");   if v ~= nil then self.settings.nameHeight   = v end
    v = get("ran_fontSize");     if v ~= nil then self.settings.fontSize     = v end
end

-- ============================================================================
-- ANIMAL DETECTION & IDENTIFICATION
-- ============================================================================

---Input callback — fires when the player presses K
function RealisticAnimalNames:onOpenUIInput(_, inputValue)
    if inputValue ~= 1 or not self.isInitialized or not self.dialogLoaded then return end

    local animal = self:getClosestAnimal(self.settings.nameDistance)
    if animal then
        self:openDialogForAnimal(animal)
    elseif self.isClient then
        self:showNotification("ran_notification_noAnimal", FSBaseMission.INGAME_NOTIFICATION_INFO)
    end
end

---Return the nearest animal within maxDistance, with a 200 ms position cache
function RealisticAnimalNames:getClosestAnimal(maxDistance)
    if not self.mission.animalSystem or not self.mission.animalSystem.clusters then
        return nil
    end

    local camera = getCamera()
    if not camera then return nil end

    local camX, camY, camZ = getWorldTranslation(camera)

    -- Return cached result if it is still fresh
    if self.nearbyAnimals
    and self.nearbyAnimals.cacheTime
    and g_currentTime - self.nearbyAnimals.cacheTime < 200 then
        return self.nearbyAnimals.closest
    end

    local closestAnimal   = nil
    local closestDistance = maxDistance
    local checked         = 0

    for _, cluster in pairs(self.mission.animalSystem.clusters) do
        if cluster.animals then
            for _, animal in pairs(cluster.animals) do
                checked = checked + 1
                if checked > 200 then break end
                if self:isValidAnimal(animal) then
                    local x, y, z = getWorldTranslation(animal.nodeId)
                    local d = MathUtil.vector3Length(camX - x, camY - y, camZ - z)
                    if d < closestDistance then
                        closestDistance = d
                        closestAnimal   = animal
                    end
                end
            end
        end
        if checked > 200 then break end
    end

    self.nearbyAnimals = {
        closest   = closestAnimal,
        distance  = closestDistance,
        cacheTime = g_currentTime,
    }
    return closestAnimal
end

---Verify an animal object has the fields we need
function RealisticAnimalNames:isValidAnimal(animal)
    if not animal then return false end
    if not animal.nodeId or not entityExists(animal.nodeId) then return false end
    if not animal.id then return false end
    return true
end

---Build a stable composite key for one animal: "farmId_animalId"
function RealisticAnimalNames:getAnimalId(animal)
    if not animal or not animal.id then return nil end
    local farmId = animal.ownerFarmId or 1
    return string.format("%d_%d", farmId, animal.id)
end

---Return the display name to show (custom name, or localised type fallback)
function RealisticAnimalNames:getAnimalDisplayName(animal)
    if not animal then return "" end
    local id     = self:getAnimalId(animal)
    local custom = self.animalNames[id]
    return (custom and custom ~= "") and custom or self:getDefaultAnimalName(animal)
end

---Localised default type name from g_i18n, or the raw type string
function RealisticAnimalNames:getDefaultAnimalName(animal)
    if not animal or not animal.animalType then return "Animal" end
    local key = string.format("animal_%s", animal.animalType)
    local loc = self.i18n and self.i18n:getText(key)
    if loc and loc ~= key then return loc end
    return animal.animalType or "Animal"
end

---Find an animal object by its composite ID (used to warm the node-ID cache after MP sync)
function RealisticAnimalNames:findAnimalById(animalId)
    if not self.mission.animalSystem or not self.mission.animalSystem.clusters then
        return nil
    end

    local _, rawId = animalId:match("^(%d+)_(%d+)$")
    local targetId = tonumber(rawId)
    if not targetId then return nil end

    for _, cluster in pairs(self.mission.animalSystem.clusters) do
        if cluster.animals then
            for _, animal in pairs(cluster.animals) do
                if animal and animal.id == targetId then return animal end
            end
        end
    end
    return nil
end

---Called by the animal-system listener when an animal is deleted
function RealisticAnimalNames:onAnimalRemoved(animal)
    if not animal then return end
    local id = self:getAnimalId(animal)
    if id and self.animalNames[id] then
        self.animalNames[id] = nil
        if self.isServer then self:scheduleSave() end
        self:log("Cleaned up name for removed animal:", id)
    end
    if animal.nodeId then self.nameCache[animal.nodeId] = nil end
end

-- ============================================================================
-- UI DIALOG
-- ============================================================================

---Open the naming dialog for the given animal
function RealisticAnimalNames:openDialogForAnimal(animal)
    if not animal or not self.dialogLoaded then return end

    self.currentAnimal = animal
    local id          = self:getAnimalId(animal)
    local currentName = self.animalNames[id] or ""

    local success, dialog = pcall(function()
        return self.gui:showDialog("AnimalNamesDialog")
    end)

    if success and dialog and dialog.setAnimal then
        dialog:setAnimal(animal, currentName)
    else
        print("[RAN] ERROR: Failed to open dialog")
    end
end

---Set a custom name — called by the dialog on Apply
function RealisticAnimalNames:setAnimalName(animal, name)
    if not animal then return false end
    local id = self:getAnimalId(animal)
    if not id then return false end

    name = name and self:sanitizeName(tostring(name)) or ""
    if name == "" then return self:resetAnimalName(animal) end

    -- In MP the client sends the request; the server applies and broadcasts
    if self.isMultiplayer and not self.isServer then
        g_client:getServerConnection():sendEvent(RANSetNameEvent.new(id, name))
        return true
    end

    self.animalNames[id] = name
    if animal.nodeId then self.nameCache[animal.nodeId] = name end
    if self.isServer then self:scheduleSave() end
    if self.isMultiplayer and self.isServer then
        g_server:broadcastEvent(RANSyncNameEvent.new(id, name), false)
    end

    self:showNotificationWithParam("ran_notification_nameSet", name,
        FSBaseMission.INGAME_NOTIFICATION_OK)
    return true
end

---Reset an animal back to its default name — called by the dialog on Reset
function RealisticAnimalNames:resetAnimalName(animal)
    if not animal then return false end
    local id = self:getAnimalId(animal)
    if not id then return false end

    if self.isMultiplayer and not self.isServer then
        g_client:getServerConnection():sendEvent(RANSetNameEvent.new(id, ""))
        return true
    end

    self.animalNames[id] = nil
    if animal.nodeId then self.nameCache[animal.nodeId] = nil end
    if self.isServer then self:scheduleSave() end
    if self.isMultiplayer and self.isServer then
        g_server:broadcastEvent(RANSyncNameEvent.new(id, ""), false)
    end

    self:showNotification("ran_notification_nameReset", FSBaseMission.INGAME_NOTIFICATION_OK)
    return true
end

---Clear every custom name (e.g. from a console command)
function RealisticAnimalNames:clearAllAnimalNames()
    if self.isMultiplayer and not self.isServer then
        for id, _ in pairs(self.animalNames) do
            g_client:getServerConnection():sendEvent(RANSetNameEvent.new(id, ""))
        end
        return
    end

    if not self.isServer then return end

    -- Broadcast removals BEFORE clearing the table (table is still populated here)
    if self.isMultiplayer then
        for id, _ in pairs(self.animalNames) do
            g_server:broadcastEvent(RANSyncNameEvent.new(id, ""), false)
        end
    end

    self.animalNames = {}
    self.nameCache   = {}
    self:scheduleSave()
    self:showNotification("ran_notification_allNamesCleared",
        FSBaseMission.INGAME_NOTIFICATION_OK)
end

---Strip control characters, trim whitespace, enforce MAX_NAME_LENGTH (UTF-8 safe)
function RealisticAnimalNames:sanitizeName(name)
    if not name then return "" end
    name = name:gsub("^%s+", ""):gsub("%s+$", ""):gsub("[%c]", "")

    if self:utf8len(name) > MAX_NAME_LENGTH then
        local out, count = "", 0
        for ch in string.gmatch(name, "[%z\1-\127\194-\244][\128-\191]*") do
            if count >= MAX_NAME_LENGTH then break end
            out   = out .. ch
            count = count + 1
        end
        name = out
    end
    return name
end

---UTF-8-aware character count
function RealisticAnimalNames:utf8len(str)
    if not str then return 0 end
    local n = 0
    for _ in string.gmatch(str, "[%z\1-\127\194-\244][\128-\191]*") do n = n + 1 end
    return n
end

-- ============================================================================
-- MULTIPLAYER NETWORKING  (called from RANNetworkEvents.lua event classes)
-- ============================================================================

---Apply a name change on the server (invoked by RANSetNameEvent:run)
function RealisticAnimalNames:applyNameChange(animalId, name)
    if name == "" then
        self.animalNames[animalId] = nil
    else
        self.animalNames[animalId] = self:sanitizeName(name)
    end
    self:scheduleSave()

    -- Warm the draw-cache if the animal is already visible
    local animal = self:findAnimalById(animalId)
    if animal and animal.nodeId then
        self.nameCache[animal.nodeId] = (name ~= "") and name or nil
    end
end

---Receive a synced name update from the server (invoked by RANSyncNameEvent:run)
function RealisticAnimalNames:receiveSyncedName(animalId, name)
    if name == "" then
        self.animalNames[animalId] = nil
    else
        self.animalNames[animalId] = name
    end

    local animal = self:findAnimalById(animalId)
    if animal and animal.nodeId then
        self.nameCache[animal.nodeId] = (name ~= "") and name or nil
    end

    self:log("Synced name from server:", animalId, name ~= "" and name or "(cleared)")
end

---Broadcast all current names to every connected client (invoked by RANRequestSyncEvent:run)
function RealisticAnimalNames:sendFullSyncToAll()
    if not self.isServer then return end
    local count = 0
    for id, name in pairs(self.animalNames) do
        if name and name ~= "" then
            g_server:broadcastEvent(RANSyncNameEvent.new(id, name), false)
            count = count + 1
        end
    end
    self:log("Full sync sent:", count, "names")
end

-- ============================================================================
-- SAVE / LOAD
-- ============================================================================

---Schedule a debounced save (server only)
function RealisticAnimalNames:scheduleSave()
    if not self.isServer then return end
    self.savePending = true
    self.saveTimer   = SAVE_DEBOUNCE_INTERVAL
end

---Write all custom names to the savegame XML file
function RealisticAnimalNames:saveToSavegame()
    if not self.isServer then return false end
    local filename = self:getSavegameFilePath()
    if not filename then
        print("[RAN] Cannot save — no savegame directory")
        return false
    end

    local xmlFile = XMLFile.create("animalNamesXML", filename, "animalNames")
    if not xmlFile then
        print("[RAN] Failed to create XML file")
        return false
    end

    local index = 0
    for id, name in pairs(self.animalNames) do
        if name and name ~= "" then
            local key = string.format("animalNames.animal(%d)", index)
            xmlFile:setValue(key .. "#id", id)
            xmlFile:setValue(key, name)
            index = index + 1
        end
    end

    xmlFile:setValue("animalNames#version", "2.2.0.0")
    xmlFile:setValue("animalNames#count",   index)
    xmlFile:save()
    xmlFile:delete()

    self:log("Saved", index, "names")
    return true
end

---Read custom names from the savegame XML file
function RealisticAnimalNames:loadFromSavegame()
    if not self.isServer then return end
    local filename = self:getSavegameFilePath()
    if not filename or not fileExists(filename) then
        self:log("No existing save data")
        return
    end

    local xmlFile = XMLFile.load("animalNamesXML", filename)
    if not xmlFile then
        print("[RAN] Failed to load save data")
        return
    end

    self.animalNames = {}
    local index = 0
    while true do
        local key  = string.format("animalNames.animal(%d)", index)
        local id   = xmlFile:getValue(key .. "#id")
        local name = xmlFile:getValue(key)
        if not id then break end
        if name and name ~= "" then self.animalNames[id] = name end
        index = index + 1
    end

    local ver = xmlFile:getValue("animalNames#version") or "1.0"
    xmlFile:delete()
    self:log("Loaded", index, "names (v" .. ver .. ")")
end

---Absolute path for the savegame data file
function RealisticAnimalNames:getSavegameFilePath()
    if self.mission.missionInfo and self.mission.missionInfo.savegameDirectory then
        return self.mission.missionInfo.savegameDirectory .. "/" .. SAVE_FILE_NAME
    end
    return nil
end

-- ============================================================================
-- RENDERING — FLOATING NAME TAGS
-- ============================================================================

---Draw floating multi-line name tags above named animals each frame
function RealisticAnimalNames:draw()
    if not self.isInitialized or not self.settings.showNames then return end
    if not self.mission.animalSystem or not self.mission.animalSystem.clusters then return end

    local camera = getCamera()
    if not camera then return end

    local camX, camY, camZ = getWorldTranslation(camera)
    local maxDist   = self.settings.nameDistance
    local maxDistSq = maxDist * maxDist

    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
    setTextBold(true)

    for _, cluster in pairs(self.mission.animalSystem.clusters) do
        if cluster.animals then
            -- Compute cluster-level metadata once — same for every animal in this cluster
            local typeName = nil
            local ageText  = nil
            if self.settings.showDetails then
                typeName = self:getAnimalTypeName(cluster)
                local age = cluster.getAge and cluster:getAge()
                if age then ageText = self:formatAnimalAge(age) end
            end

            for _, animal in pairs(cluster.animals) do
                if self:isValidAnimal(animal) then
                    -- Look up name: try fast node cache first, then the main table
                    local name = self.nameCache[animal.nodeId]
                    if not name then
                        local id = self:getAnimalId(animal)
                        name = self.animalNames[id]
                        -- Warm the cache for next frame
                        if name and animal.nodeId then
                            self.nameCache[animal.nodeId] = name
                        end
                    end

                    if name and name ~= "" then
                        local x, y, z = getWorldTranslation(animal.nodeId)
                        local dx = camX - x
                        local dy = camY - y
                        local dz = camZ - z
                        local distSq = dx*dx + dy*dy + dz*dz

                        if distSq < maxDistSq then
                            local dist = math.sqrt(distSq)
                            local baseY = y + self.settings.nameHeight

                            -- Alpha fades from 1.0 (close) to 0.3 (at max distance)
                            local alpha = math.max(0.3, 1.0 - dist / maxDist)

                            -- Scale grows slightly with distance so distant tags remain legible
                            local scale    = self.settings.fontSize * (1.0 + (dist / maxDist) * 0.5)
                            local subScale = scale * 0.78

                            local hasExtra = self.settings.showDetails and (typeName or ageText)

                            if hasExtra then
                                -- Three-line layout centred around baseY:
                                --   name  (baseY + spacing)
                                --   type  (baseY)
                                --   age   (baseY - spacing)
                                setTextColor(1, 1, 1, alpha)
                                renderText3D(x, baseY + TAG_LINE_SPACING, z, 0, 0, 0, scale, name)

                                if typeName then
                                    setTextColor(0.85, 0.85, 0.85, alpha * 0.85)
                                    renderText3D(x, baseY, z, 0, 0, 0, subScale, typeName)
                                end

                                if ageText then
                                    -- If there is no type line, age sits at baseY instead of below it
                                    local ageY = typeName and (baseY - TAG_LINE_SPACING) or baseY
                                    setTextColor(0.7, 0.85, 1.0, alpha * 0.75)
                                    renderText3D(x, ageY, z, 0, 0, 0, subScale, ageText)
                                end
                            else
                                -- Single-line: just the name centred at baseY
                                setTextColor(1, 1, 1, alpha)
                                renderText3D(x, baseY, z, 0, 0, 0, scale, name)
                            end
                        end
                    end
                end
            end
        end
    end

    -- Always reset render state so other systems are not affected
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
    setTextBold(false)
    setTextColor(1, 1, 1, 1)
end

-- ============================================================================
-- DISPLAY HELPERS
-- ============================================================================

---Get a human-readable, localised type name for an animal cluster.
---Tries the FS25 animal-system visual store first (gives age-accurate labels like
---"Calf" vs "Cow"), then falls back to capitalising the raw animalType string.
---@param  cluster table  AnimalCluster object
---@return string|nil
function RealisticAnimalNames:getAnimalTypeName(cluster)
    if not cluster then return nil end

    -- Preferred: ask the animal system for the visual at the current age
    if cluster.getSubTypeIndex and cluster.getAge and self.mission.animalSystem then
        local ok, visual = pcall(function()
            return self.mission.animalSystem:getVisualByAge(
                cluster:getSubTypeIndex(), cluster:getAge())
        end)
        if ok and visual and visual.store then
            local n = visual.store.name
            if n and n ~= "" then return n end
        end
    end

    -- Fallback: capitalise the raw type string stored on the cluster
    local t = cluster.animalType
    if type(t) == "string" and t ~= "" then
        return t:sub(1, 1):upper() .. t:sub(2):lower()
    end

    return nil
end

---Format an age value into a short, localised string.
---FS25 age is in whole months.
---@param  age number
---@return string|nil
function RealisticAnimalNames:formatAnimalAge(age)
    if not age or age < 0 then return nil end

    if age < 1 then
        return self.i18n:getText("ran_age_newborn") or "Newborn"
    elseif age < 12 then
        local fmt = self.i18n:getText("ran_age_months_fmt") or "%d mo"
        return string.format(fmt, math.floor(age))
    else
        local fmt = self.i18n:getText("ran_age_years_fmt") or "%d yr"
        return string.format(fmt, math.floor(age / 12))
    end
end

-- ============================================================================
-- UPDATE
-- ============================================================================

---Per-frame update, driven by the FSBaseMission.update hook below
function RealisticAnimalNames:update(dt)
    if not self.isInitialized then return end

    -- Deferred one-shot GUI load (avoids loading during onMissionLoaded)
    if self.guiLoadPending then
        self:doLoadGUI()
        self.guiLoadPending = false
    end

    -- Periodic settings refresh — avoids reading g_gameSettings every frame
    self.settingsRefreshTimer = self.settingsRefreshTimer - dt
    if self.settingsRefreshTimer <= 0 then
        self:loadSettingsFromGame()
        self.settingsRefreshTimer = SETTINGS_REFRESH_INTERVAL
    end

    -- Debounced save
    if self.savePending then
        self.saveTimer = self.saveTimer - dt
        if self.saveTimer <= 0 then
            self:saveToSavegame()
            self.savePending = false
        end
    end

    -- Delayed sync request for newly joined MP clients
    if self.syncRequestPending then
        self.syncRequestTimer = self.syncRequestTimer - dt
        if self.syncRequestTimer <= 0 then
            if g_client then
                g_client:getServerConnection():sendEvent(RANRequestSyncEvent.new())
            end
            self.syncRequestPending = false
            self:log("Sync request sent to server")
        end
    end
end

---Called just before the mission is torn down
function RealisticAnimalNames:onMissionDelete()
    self:log("Cleaning up...")

    -- Flush any pending save before teardown
    if self.isServer and self.savePending then
        self:saveToSavegame()
    end

    -- Deregister the keybind
    if self.actionEventId and self.inputManager then
        pcall(function()
            self.inputManager:removeActionEvent(self.actionEventId)
        end)
        self.actionEventId = nil
    end

    self.animalNames   = {}
    self.nameCache     = {}
    self.currentAnimal = nil
    self.isInitialized = false
    self.dialogLoaded  = false

    self:log("Cleanup complete")
end

-- ============================================================================
-- UTILITIES
-- ============================================================================

function RealisticAnimalNames:showNotification(textKey, notifType)
    if not self.isClient or not self.i18n then return end
    local text = self.i18n:getText(textKey)
    if text and text ~= "" and text ~= textKey then
        g_currentMission:addIngameNotification(
            notifType or FSBaseMission.INGAME_NOTIFICATION_INFO, text)
    end
end

function RealisticAnimalNames:showNotificationWithParam(textKey, param, notifType)
    if not self.isClient or not self.i18n then return end
    local text = self.i18n:getText(textKey)
    if text and text ~= "" and text ~= textKey then
        g_currentMission:addIngameNotification(
            notifType or FSBaseMission.INGAME_NOTIFICATION_INFO,
            text:format(param))
    end
end

function RealisticAnimalNames:log(...)
    if self.debug then print("[RAN]", ...) end
end

-- ============================================================================
-- API FOR OTHER MODS
-- ============================================================================

---Get the custom name for an animal by composite ID ("farmId_animalId")
function RealisticAnimalNames:getAnimalName(animalId)
    return self.animalNames[animalId]
end

---Return a shallow copy of the entire name table
function RealisticAnimalNames:getAllAnimalNames()
    local copy = {}
    for k, v in pairs(self.animalNames) do copy[k] = v end
    return copy
end

---Fast lookup by scene node ID (most efficient path for other mods)
function RealisticAnimalNames:getNameByNodeId(nodeId)
    return self.nameCache[nodeId]
end

-- ============================================================================
-- GLOBAL REGISTRATION  (FS25 lifecycle hooks)
-- ============================================================================

local modInstance = nil

local function registerMod(mission)
    if modInstance then
        removeModEventListener(modInstance)
        if modInstance.onMissionDelete then modInstance:onMissionDelete() end
        modInstance = nil
    end

    modInstance = RealisticAnimalNames:new(
        mission, g_currentModDirectory, g_currentModName)

    -- Expose globally so network event classes can call back into the mod
    g_realisticAnimalNames = modInstance

    addModEventListener(modInstance)
    print("[RAN] Registered with mission")
end

local function unregisterMod()
    if modInstance then
        removeModEventListener(modInstance)
        if modInstance.onMissionDelete then modInstance:onMissionDelete() end
        modInstance = nil
        g_realisticAnimalNames = nil
    end
    print("[RAN] Unregistered")
end

FSBaseMission.onMissionLoaded = Utils.appendedFunction(
    FSBaseMission.onMissionLoaded,
    function(mission) registerMod(mission) end)

FSBaseMission.delete = Utils.appendedFunction(
    FSBaseMission.delete,
    function() unregisterMod() end)

-- Draw hook
local _origDraw = FSBaseMission.draw
FSBaseMission.draw = function(self, ...)
    if _origDraw then _origDraw(self, ...) end
    if modInstance and modInstance.isInitialized then
        local ok, err = pcall(function() modInstance:draw() end)
        if not ok then print("[RAN] Draw error:", err) end
    end
end

-- Update hook
local _origUpdate = FSBaseMission.update
FSBaseMission.update = function(self, dt, ...)
    if _origUpdate then _origUpdate(self, dt, ...) end
    if modInstance and modInstance.isInitialized then
        local ok, err = pcall(function() modInstance:update(dt) end)
        if not ok then print("[RAN] Update error:", err) end
    end
end

print("[RAN] Mod initialized (v2.2.0.0)")
