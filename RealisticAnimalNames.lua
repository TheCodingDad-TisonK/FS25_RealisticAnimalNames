-- =========================================================
-- Realistic Animal Names v1.1.0.0 (FS25)
-- =========================================================
-- Author: YourName
-- Adds custom names to animals with floating tags.
-- Per-savegame storage, custom GUI, keybind interaction.
-- =========================================================

RealisticAnimalNames = {}
RealisticAnimalNames.MOD_NAME = g_currentModName

-- Runtime state
RealisticAnimalNames.animalNames   = {}
RealisticAnimalNames.originalNames = {}
RealisticAnimalNames.showNames     = true
RealisticAnimalNames.gui           = nil
RealisticAnimalNames.isInitialized = false
RealisticAnimalNames.actionEventId = nil

------------------------------------------------------------
-- FS25 MAP LOAD
------------------------------------------------------------
function RealisticAnimalNames:loadMap()
    -- Load GUI
    self.gui = RealisticAnimalNamesGui.new()
    self.gui:load()

    -- Register input action (FS25 style)
    local _, eventId = g_inputBinding:registerActionEvent(
        "RAN_OPEN_UI",
        self,
        self.onOpenUiPressed,
        false,
        true,
        false,
        true
    )
    self.actionEventId = eventId

    -- Welcome notification
    g_currentMission:addIngameNotification(
        FSBaseMission.INGAME_NOTIFICATION_OK,
        "Realistic Animal Names loaded!\nPress K near an animal to rename it."
    )

    self.isInitialized = true
end

------------------------------------------------------------
-- INPUT CALLBACK
------------------------------------------------------------
function RealisticAnimalNames:onOpenUiPressed()
    if not self.isInitialized then return end

    local animal = self:getClosestAnimal(5)
    if animal ~= nil then
        g_gui:showGui("RealisticAnimalNamesScreen")
        self.gui:openForAnimal(animal)
    end
end

------------------------------------------------------------
-- DRAW FLOATING NAMES
------------------------------------------------------------
function RealisticAnimalNames:draw()
    if not self.showNames then return end
    if g_currentMission == nil or g_currentMission.animalSystem == nil then return end

    for _, cluster in pairs(g_currentMission.animalSystem.clusters) do
        for _, animal in pairs(cluster.animals) do
            if animal ~= nil and animal.nodeId ~= nil then
                local name = self.animalNames[animal.id]
                if name ~= nil then
                    local x, y, z = getWorldTranslation(animal.nodeId)
                    y = y + 1.8
                    renderTextAtWorldPosition(name, x, y, z)
                end
            end
        end
    end
end

------------------------------------------------------------
-- WORLD TEXT HELPER
------------------------------------------------------------
function renderTextAtWorldPosition(text, x, y, z)
    local sx, sy, visible = getScreenCoordinatesFromWorldPosition(x, y, z)
    if visible then
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        setTextColor(1, 1, 1, 1)
        renderText(sx, sy, 0.018, text)
        setTextBold(false)
    end
end

------------------------------------------------------------
-- FIND NEAREST ANIMAL (FS25)
------------------------------------------------------------
function RealisticAnimalNames:getClosestAnimal(radius)
    if g_currentMission == nil or g_currentMission.animalSystem == nil then return nil end

    local px, py, pz = getCameraPosition()
    local closest, minDist = nil, radius

    for _, cluster in pairs(g_currentMission.animalSystem.clusters) do
        for _, animal in pairs(cluster.animals) do
            if animal.nodeId ~= nil then
                local x, y, z = getWorldTranslation(animal.nodeId)
                local dist = MathUtil.vector3Length(px - x, py - y, pz - z)
                if dist < minDist then
                    minDist = dist
                    closest = animal
                end
            end
        end
    end

    return closest
end

------------------------------------------------------------
-- NAME MANAGEMENT
------------------------------------------------------------
function RealisticAnimalNames:setAnimalName(animal, name)
    if animal ~= nil and animal.id ~= nil then
        if self.originalNames[animal.id] == nil then
            self.originalNames[animal.id] = self.animalNames[animal.id]
        end
        self.animalNames[animal.id] = name
    end
end

function RealisticAnimalNames:resetAnimalName(animal)
    if animal ~= nil and animal.id ~= nil then
        self.animalNames[animal.id] = self.originalNames[animal.id]
    end
end

------------------------------------------------------------
-- SAVEGAME XML PATH
------------------------------------------------------------
function RealisticAnimalNames:getSavegamePath()
    if g_currentMission ~= nil and g_currentMission.missionInfo ~= nil then
        return g_currentMission.missionInfo.savegameDirectory ..
               "/" .. self.MOD_NAME .. ".xml"
    end
    return nil
end

------------------------------------------------------------
-- SAVE
------------------------------------------------------------
function RealisticAnimalNames:saveToSavegame()
    local path = self:getSavegamePath()
    if path == nil then return end

    local xml = XMLFile.create("RAN_Save", path, "RealisticAnimalNames")
    if xml == nil then return end

    xml:setBool("RealisticAnimalNames.showNames", self.showNames)

    local i = 0
    for id, name in pairs(self.animalNames) do
        local key = string.format("RealisticAnimalNames.animals.animal(%d)", i)
        xml:setInt(key .. "#id", id)
        xml:setString(key .. "#name", name)
        i = i + 1
    end

    xml:save()
    xml:delete()
end

------------------------------------------------------------
-- LOAD
------------------------------------------------------------
function RealisticAnimalNames:loadFromSavegame()
    local path = self:getSavegamePath()
    if path == nil or not fileExists(path) then return end

    local xml = XMLFile.load("RAN_Save", path)
    if xml == nil then return end

    self.showNames = xml:getBool("RealisticAnimalNames.showNames", true)

    local i = 0
    while true do
        local key = string.format("RealisticAnimalNames.animals.animal(%d)", i)
        if not xml:hasProperty(key) then break end

        local id   = xml:getInt(key .. "#id")
        local name = xml:getString(key .. "#name")

        if id ~= nil and name ~= nil then
            self.animalNames[id] = name
        end

        i = i + 1
    end

    xml:delete()
end

------------------------------------------------------------
-- FS25 HOOKS
------------------------------------------------------------
Mission00.load = Utils.appendedFunction(Mission00.load, function()
    RealisticAnimalNames:loadMap()
    RealisticAnimalNames:loadFromSavegame()
end)

FSBaseMission.draw = Utils.appendedFunction(FSBaseMission.draw, function()
    RealisticAnimalNames:draw()
end)

FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, function()
    RealisticAnimalNames:saveToSavegame()
end)
