-- ============================================================================
-- FS25 Realistic Animal Names — Network Events
-- ============================================================================
-- Standard FS25 Event pattern: emptyNew / new / readStream / writeStream / run
-- All three classes are globally accessible so event callbacks can find them.
-- g_realisticAnimalNames must be set before any event can run.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- RANSetNameEvent
-- Direction : client  →  server
-- Purpose   : request a name change (set or clear) for one animal
-- ---------------------------------------------------------------------------
RANSetNameEvent    = {}
local RANSetNameEvent_mt = Class(RANSetNameEvent, Event)

function RANSetNameEvent.emptyNew()
    return Event.new(RANSetNameEvent_mt)
end

function RANSetNameEvent.new(animalId, name)
    local self  = RANSetNameEvent.emptyNew()
    self.animalId = animalId
    self.name     = name
    return self
end

function RANSetNameEvent:readStream(streamId, connection)
    self.animalId = streamReadString(streamId)
    self.name     = streamReadString(streamId)
    self:run(connection)
end

function RANSetNameEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.animalId)
    streamWriteString(streamId, self.name)
end

-- Runs on the server when received from a client.
function RANSetNameEvent:run(connection)
    if not connection:getIsServer() and g_realisticAnimalNames ~= nil then
        g_realisticAnimalNames:applyNameChange(self.animalId, self.name)
        g_server:broadcastEvent(RANSyncNameEvent.new(self.animalId, self.name), false)
    end
end

-- ---------------------------------------------------------------------------
-- RANSyncNameEvent
-- Direction : server  →  all clients
-- Purpose   : push one animal name to every connected client
-- ---------------------------------------------------------------------------
RANSyncNameEvent    = {}
local RANSyncNameEvent_mt = Class(RANSyncNameEvent, Event)

function RANSyncNameEvent.emptyNew()
    return Event.new(RANSyncNameEvent_mt)
end

function RANSyncNameEvent.new(animalId, name)
    local self  = RANSyncNameEvent.emptyNew()
    self.animalId = animalId
    self.name     = name
    return self
end

function RANSyncNameEvent:readStream(streamId, connection)
    self.animalId = streamReadString(streamId)
    self.name     = streamReadString(streamId)
    self:run(connection)
end

function RANSyncNameEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.animalId)
    streamWriteString(streamId, self.name)
end

-- Runs on each client when received from the server.
function RANSyncNameEvent:run(connection)
    if connection:getIsServer() and g_realisticAnimalNames ~= nil then
        g_realisticAnimalNames:receiveSyncedName(self.animalId, self.name)
    end
end

-- ---------------------------------------------------------------------------
-- RANRequestSyncEvent
-- Direction : client  →  server
-- Purpose   : newly joined client requests the full current name table
-- ---------------------------------------------------------------------------
RANRequestSyncEvent    = {}
local RANRequestSyncEvent_mt = Class(RANRequestSyncEvent, Event)

function RANRequestSyncEvent.emptyNew()
    return Event.new(RANRequestSyncEvent_mt)
end

function RANRequestSyncEvent.new()
    return RANRequestSyncEvent.emptyNew()
end

function RANRequestSyncEvent:readStream(streamId, connection)
    self:run(connection)
end

function RANRequestSyncEvent:writeStream(streamId, connection)
    -- No payload needed
end

-- Runs on the server — broadcast all current names back to all clients.
function RANRequestSyncEvent:run(connection)
    if not connection:getIsServer() and g_realisticAnimalNames ~= nil then
        g_realisticAnimalNames:sendFullSyncToAll()
    end
end
