---@diagnostic disable: lowercase-global
local POSTAL_BOSS_COORDS = Config.POSTAL_BOSS_COORDS
local POSTAL_BOSS_HEADING = Config.POSTAL_BOSS_HEADING
local POSTAL_BOSS_HASH = Config.POSTAL_BOSS_HASH
local POSTAL_BOSS_ANIMATION = Config.POSTAL_BOSS_ANIMATION
local POSTAL_VEHICLE_HASH = Config.POSTAL_VEHICLE_HASH
local POSTAL_VEHICLE_SPAWN_COORDS = Config.POSTAL_VEHICLE_SPAWN_COORDS
local POSTAL_GET_PACKAGE = Config.POSTAL_GET_PACKAGE
local POSTAL_DROP_OFF_PACKAGE = Config.POSTAL_DROP_OFF_PACKAGE
local PICK_UP_BLIP = Config.PICK_UP_BLIP
local DROP_OFF_BLIP = Config.DROP_OFF_BLIP
local GO_POSTAL_HQ_BLIP = Config.GO_POSTAL_HQ_BLIP
local MALE_OUTFIT = Config.MALE_OUTFIT
local FEMALE_OUTFIT = Config.FEMALE_OUTFIT
local DROP_OFF_PED_HASH = Config.DROP_OFF_PED_HASH
local SHOW_WHITE_ARROW_MARKER = Config.SHOW_WHITE_ARROW_MARKER
local IS_WHITELISTED_TO_JOB = Config.IS_WHITELISTED_TO_JOB
local WHITELISTED_JOB_TITLE = Config.WHITELISTED_JOB_TITLE

local isPedSpawned = false
local postalBossPed = nil

local postalJobState = {
    isDoingJob = false, -- <boolean>
    dropOffCoords = nil, -- <vec3>
    goPostalVan = nil, -- entity <number>
    isCarryingBox = false, -- <boolean>
    hasBoxInVan = false, -- <boolean>
    deliverToPed = nil, -- entity <number>
    isDeliveringPackage = false, -- <boolean>
    postalBoxZone = nil, -- <number>
    positionSet = {
        startLocation = nil, -- <vec3>
        middleLocation = nil, -- <vec3>
        endLocation = nil, -- <vec3>
    },
    pickupBlip = nil, -- <number> blip
    dropoffBlip = nil, -- <number> blip
    vanZone = nil, -- <number> zona
}

function resetJobState()
    if (postalJobState.isCarryingBox) then
        removeBox()
    end

    if (postalJobState.pickupBlip) then
        RemoveBlip(postalJobState.pickupBlip)
    end

    if (postalJobState.dropoffBlip) then
        RemoveBlip(postalJobState.dropoffBlip)
    end

    if (postalJobState.postalBoxZone) then
        zone = postalJobState.postalBoxZone
        zone:remove()
exports.ox_lib:hideTextUI()
    end

    if (postalJobState.vanZone) then
                zone = postalJobState.vanZone
        zone:remove()
exports.ox_lib:hideTextUI()
    end

    if (postalJobState.goPostalVan) then
        -- Nenhuma lógica de alvo, apenas delete o veículo
        DeleteEntity(postalJobState.goPostalVan)
    end

    postalJobState = {
        isDoingJob = false,
        dropOffCoords = nil,
        goPostalVan = nil,
        isCarryingBox = false,
        hasBoxInVan = false,
        deliverToPed = nil,
        isDeliveringPackage = false,
        positionSet = {
            startLocation = nil,
            middleLocation = nil,
            endLocation = nil,
        },
        pickupBlip = nil,
        dropoffBlip = nil,
        vanZone = nil,
    }
end

function startPostalJob()
    if not isSpawnPointClear(POSTAL_VEHICLE_SPAWN_COORDS, 10.0) then
        NotifyPlayer(t('please_clear_area'), 'error', 7500)
        return
    end

    local playerPed = PlayerPedId()
    NotifyPlayer(t('head_over_to_waypoint'))
    postalJobState.isDoingJob = true
    postalJobState.positionSet.startLocation = GetEntityCoords(playerPed)
    TriggerServerEvent("dream-postal:server:start:job")
    spawnGoPostalVehicle()
    putOnJobOutfit()

    -- pegar coords para buscar pacote
    local randomNumber = math.random(1, #POSTAL_GET_PACKAGE)
    local tempDeliveryCoords = POSTAL_GET_PACKAGE[randomNumber]

    local retval, groundZ = GetGroundZFor_3dCoord(tempDeliveryCoords.x, tempDeliveryCoords.y, tempDeliveryCoords.z, false)
    local deliveryCoords = tempDeliveryCoords
    if retval then
        deliveryCoords = vec3(tempDeliveryCoords.x, tempDeliveryCoords.y, groundZ)
    end

    local deliveryBlip = AddBlipForCoord(deliveryCoords)
    SetBlipSprite(deliveryBlip, PICK_UP_BLIP.sprite)
    SetBlipDisplay(deliveryBlip, PICK_UP_BLIP.display)
    SetBlipScale(deliveryBlip, PICK_UP_BLIP.scale)
    SetBlipColour(deliveryBlip, PICK_UP_BLIP.colour)
    SetBlipAsShortRange(deliveryBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(PICK_UP_BLIP.label)
    EndTextCommandSetBlipName(deliveryBlip)

    postalJobState.pickupBlip = deliveryBlip

    SetNewWaypoint(deliveryCoords.x, deliveryCoords.y)

    postalJobState.postalBoxZone = lib.zones.sphere({
        coords = deliveryCoords,
        size = vec3(1.0, 1.0, 3.0),
        rotation = 45,
        debug = false,
        onEnter = function()
            exports.ox_lib:showTextUI('[E] ' .. t('grab_package'), {icon = 'fas fa-envelope'})
        end,
        onExit = function()
            exports.ox_lib:hideTextUI()
        end,
                    inside = function()
                if IsControlJustReleased(0, 38) then
            pickupMail()
                end
        end,
        distance = 3.0,
    })

    if (SHOW_WHITE_ARROW_MARKER) then
        CreateThread(function()
            while postalJobState.postalBoxZone do
                local playerCoords = GetEntityCoords(playerPed)
                local distanceToMarker = #(playerCoords - deliveryCoords)
                if (distanceToMarker <= 50.0) then
                    DrawMarker(22, deliveryCoords.x, deliveryCoords.y, (deliveryCoords.z + 1.75), 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 1.0, 255, 255, 220, 200, 0, 0, 0, 1)
                    Wait(1)
                else
                    Wait(3000)
                end
            end
        end)
    end
end

function GetRearPositionOfVehicle(vehicle, distance)
    if not DoesEntityExist(vehicle) then return nil end
    local vehCoords = GetEntityCoords(vehicle)
    local heading = GetEntityHeading(vehicle)
    local radHeading = math.rad(heading)

    -- Posição atrás
    local rearX = vehCoords.x - math.sin(radHeading) * distance
    local rearY = vehCoords.y + math.cos(radHeading) * distance

    return vector3(rearX, rearY, vehCoords.z)
end

function pickupMail()
    if (not postalJobState.isDoingJob) then
        NotifyPlayer(t('you_are_not_on_the_job'), 'error')
        return
    end

    NotifyPlayer(t('place_package_in_back_of_van'))

    -- Limpa zonas antigas
    if postalJobState.postalBoxZone then
        postalJobState.postalBoxZone:remove()
        exports.ox_lib:hideTextUI()
        postalJobState.postalBoxZone = nil
    end
    if postalJobState.pickupBlip then
        RemoveBlip(postalJobState.pickupBlip)
        postalJobState.pickupBlip = nil
    end

    postalJobState.positionSet.middleLocation = GetEntityCoords(PlayerPedId())
    carryBox()

    -- Agora setup do blip na van
    if postalJobState.goPostalVan then
        -- Blip seguindo a van
        local blip = AddBlipForEntity(postalJobState.goPostalVan)
        SetBlipSprite(blip, 67) -- ícone de caminhão
        SetBlipColour(blip, 5)
        SetBlipScale(blip, 0.8)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("GoPostal Van")
        EndTextCommandSetBlipName(blip)
        postalJobState.pickupBlip = blip

        -- Start Monitor Thread
        startPackageDeliveryMonitor(postalJobState.goPostalVan)
    end
end

function startPackageDeliveryMonitor(vanEntity)
    if not DoesEntityExist(vanEntity) then return end

    -- Kill thread antiga se tiver
    if postalJobState.monitorThread then
        postalJobState.monitorThread = nil
    end

    postalJobState.monitorThread = true

    CreateThread(function()
        local showingText = false
        while postalJobState.monitorThread do
            if not DoesEntityExist(vanEntity) then
                if showingText then
                    exports.ox_lib:hideTextUI()
                    showingText = false
                end
                break
            end

            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local rearCoords = GetRearPositionOfVehicle(vanEntity, 2.0)

            if rearCoords then
                local distance = #(playerCoords - rearCoords)

                if distance <= 2.5 then
                    if not showingText then
                        showingText = true
                        exports.ox_lib:showTextUI("Pressione [E] para colocar a caixa", {icon = 'fa-solid fa-box'})
                    end
                    if IsControlJustReleased(0, 38) then -- E
                        insertPackageIntoVehicle()
                    end
                else
                    if showingText then
                        showingText = false
                        exports.ox_lib:hideTextUI()
                    end
                end
            end

            Wait(100) -- ESPERA AQUI normal
        end
    end)
end


function insertPackageIntoVehicle()
    removeBox()
    postalJobState.isCarryingBox = false
    postalJobState.hasBoxInVan = true
    postalJobState.isDeliveringPackage = true

    -- Para a monitor thread
    postalJobState.monitorThread = nil
    exports.ox_lib:hideTextUI()

    if postalJobState.pickupBlip then
        RemoveBlip(postalJobState.pickupBlip)
        postalJobState.pickupBlip = nil
    end

    -- Agora segue para destino
    local randomNumber = math.random(1, #POSTAL_DROP_OFF_PACKAGE)
    local deliverPackageToCoords = POSTAL_DROP_OFF_PACKAGE[randomNumber] ---@as vector4

    SetNewWaypoint(deliverPackageToCoords.x, deliverPackageToCoords.y)

    local deliveryCoords = vec3(deliverPackageToCoords.x, deliverPackageToCoords.y, deliverPackageToCoords.z)
    local deliveryHeading = deliverPackageToCoords.w ---@as number

    local dropoffBlip = AddBlipForCoord(deliveryCoords)
    SetBlipSprite(dropoffBlip, 1)
    SetBlipDisplay(dropoffBlip, 4)
    SetBlipScale(dropoffBlip, 0.8)
    SetBlipColour(dropoffBlip, 5)
    SetBlipAsShortRange(dropoffBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName("Entrega GoPostal")
    EndTextCommandSetBlipName(dropoffBlip)

    postalJobState.dropoffBlip = dropoffBlip
    postalJobState.dropOffCoords = deliveryCoords
end

function createRemovePackageFromVanZone()
    local vanEntity = postalJobState.goPostalVan
    local showingText = false

    -- Cria zona dinâmica
    postalJobState.vanZone = lib.zones.sphere({
        coords = vec3(0.0, 0.0, 0.0), -- Dummy
        size = vec3(2.0, 4.0, 2.0),
        rotation = 0,
        debug = false,
        inside = function()
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)

            if not DoesEntityExist(vanEntity) then
                if showingText then
                    showingText = false
                    exports.ox_lib:hideTextUI()
                end
                return
            end

            local rearCoords = GetRearPositionOfVehicle(vanEntity, 2.0)
            if not rearCoords then return end

            local distance = #(playerCoords - rearCoords)

            if distance <= 2.5 then
                if not showingText then
                    showingText = true
                    exports.ox_lib:showTextUI(t('take_out_package'), {icon = 'fa-solid fa-envelope'})
                end

                if IsControlJustReleased(0, 38) then
                    removePackageFromVehicle()
                end
            else
                if showingText then
                    showingText = false
                    exports.ox_lib:hideTextUI()
                end
            end
        end,
        distance = 3.0,
    })
end


function removePackageFromVehicle()
    carryBox()
    postalJobState.hasBoxInVan = false

    if postalJobState.vanZone then
        zone = postalJobState.vanZone
        zone:remove()
exports.ox_lib:hideTextUI()
        postalJobState.vanZone = nil
    end

    createPutPackageInVanZone()
end

function createPutPackageInVanZone()
    local vanEntity = postalJobState.goPostalVan
    local showingText = false

    postalJobState.vanZone = lib.zones.sphere({
        coords = vec3(0.0, 0.0, 0.0), -- Dummy
        size = vec3(2.0, 4.0, 2.0),
        rotation = 0,
        debug = false,
        inside = function()
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)

            if not DoesEntityExist(vanEntity) then
                if showingText then
                    showingText = false
                    exports.ox_lib:hideTextUI()
                end
                return
            end

            local rearCoords = GetRearPositionOfVehicle(vanEntity, 2.0)
            if not rearCoords then return end

            local distance = #(playerCoords - rearCoords)

            if distance <= 2.5 then
                if not showingText then
                    showingText = true
                    exports.ox_lib:showTextUI(t('put_package_in_van'), {icon = 'fa-solid fa-envelope'})
                end

                if IsControlJustReleased(0, 38) then
                    putPackageInVehicle()
                end
            else
                if showingText then
                    showingText = false
                    exports.ox_lib:hideTextUI()
                end
            end
        end,
        distance = 3.0,
    })
end


function putPackageInVehicle()
    removeBox()
    postalJobState.isCarryingBox = false
    postalJobState.hasBoxInVan = true

    if postalJobState.vanZone then
                zone = postalJobState.vanZone
        zone:remove()
exports.ox_lib:hideTextUI()
        postalJobState.vanZone = nil
    end

    createRemovePackageFromVanZone()
end

function spawnGoPostalVehicle()
    RequestModel(POSTAL_VEHICLE_HASH)
    while not HasModelLoaded(POSTAL_VEHICLE_HASH) do Citizen.Wait(0) end
    local vehicle = CreateVehicle(POSTAL_VEHICLE_HASH, POSTAL_VEHICLE_SPAWN_COORDS, true, false)

    GivePlayerVehicleKeys(vehicle)

    local networkId = NetworkGetNetworkIdFromEntity(vehicle)
    SetNetworkIdCanMigrate(networkId, true)

    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetVehRadioStation(vehicle, 'OFF')
    SetVehicleFuelLevel(vehicle, 100.0)
    SetModelAsNoLongerNeeded(POSTAL_VEHICLE_HASH)

    postalJobState.goPostalVan = vehicle
end

function endPostalJob()
    NotifyPlayer(t('you_are_done_with_shift'))
    TriggerServerEvent("dream-postal:server:end:job")

    if (postalJobState.goPostalVan) then
        DeleteEntity(postalJobState.goPostalVan)
    end
    takeOffJobOutfit()
    resetJobState()
end

function spawnPostalBossPed()
    local postalPedHashKey = joaat(POSTAL_BOSS_HASH)
    if not HasModelLoaded(postalPedHashKey) then
        RequestModel(postalPedHashKey)
        Wait(10)
    end
    while not HasModelLoaded(postalPedHashKey) do
        Wait(10)
    end

    postalBossPed = CreatePed(5, postalPedHashKey, POSTAL_BOSS_COORDS, POSTAL_BOSS_HEADING, false, false)
    FreezeEntityPosition(postalBossPed, true)
    SetEntityInvincible(postalBossPed, true)
    SetBlockingOfNonTemporaryEvents(postalBossPed, true)
    SetModelAsNoLongerNeeded(postalPedHashKey)
    TaskStartScenarioInPlace(postalBossPed, POSTAL_BOSS_ANIMATION, 0 ,true)

    -- Cria zona de interação para iniciar/terminar serviço
    lib.zones.sphere({
        coords = POSTAL_BOSS_COORDS,
        size = vec3(1.5, 1.5, 2.5),
        rotation = 0,
        debug = false,
        onEnter = function()
            if not postalJobState.isDoingJob then
                exports.ox_lib:showTextUI('[E] ' .. t('start_postal_job'), {icon = 'fa-solid fa-envelope'})
            else
                exports.ox_lib:showTextUI('[E] ' .. t('end_postal_job'), {icon = 'fa-solid fa-envelope'})
            end
        end,
        onExit = function()
            exports.ox_lib:hideTextUI()
        end,
        inside = function()
                if IsControlJustReleased(0, 38) then
            if not postalJobState.isDoingJob then
                startPostalJob()
            else
                endPostalJob()
            end
            end
        end,
        distance = 2.0,
    })
end

function spawnDeliverToPed(hash, coords, heading)
    local hashKey = joaat(hash)
    if not HasModelLoaded(hashKey) then
        RequestModel(hashKey)
        Wait(10)
    end
    while not HasModelLoaded(hashKey) do
        Wait(10)
    end

    local spawnZ = coords.z
    local retval, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, false)
    if retval then
        spawnZ = groundZ
    end

    local deliverToPed = CreatePed(5, hashKey, coords.x, coords.y, spawnZ, heading, false, false)
    FreezeEntityPosition(deliverToPed, true)
    SetEntityInvincible(deliverToPed, true)
    SetBlockingOfNonTemporaryEvents(deliverToPed, true)
    SetModelAsNoLongerNeeded(hashKey)
    TaskStartScenarioInPlace(deliverToPed, POSTAL_BOSS_ANIMATION, 0 ,true)

    postalJobState.deliverToPed = deliverToPed

    -- Cria zona de entrega do pacote
    lib.zones.sphere({
        coords = coords,
        size = vec3(1.0, 1.0, 2.0),
        rotation = 0,
        debug = false,
        onEnter = function()
            exports.ox_lib:showTextUI('[E] ' .. t('drop_off_package'), {icon = 'fa-solid fa-envelope'})
        end,
        onExit = function()
            exports.ox_lib:hideTextUI()
        end,
        inside = function()
            if IsControlJustReleased(0, 38) then
                deliverPackageToPed()
            end
        end,
        distance = 2.0,
    })

    if (SHOW_WHITE_ARROW_MARKER) then
        CreateThread(function()
            local playerPed = PlayerPedId()
            while postalJobState.isDeliveringPackage do
                local playerCoords = GetEntityCoords(playerPed)
                local distanceToMarker = #(playerCoords - coords)
                if (distanceToMarker <= 50.0) then
                    DrawMarker(22, coords.x, coords.y, (coords.z + 1.50), 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 1.0, 255, 255, 220, 200, 0, 0, 0, 1)
                    Wait(1)
                else
                    Wait(3000)
                end
            end
        end)
    end
end

function deliverPackageToPed()
    -- check if player is clocked in
    if (not postalJobState.isDoingJob) then
        return
    end

    -- check if location of van is within distance
    local dropOffCoords = postalJobState.dropOffCoords
    local vehicleCoords = GetEntityCoords(postalJobState.goPostalVan)
    if #(dropOffCoords - vehicleCoords) > 30.00 then
        return
    end

    if (not postalJobState.isCarryingBox) then
        NotifyPlayer(t('where_is_the_package'), 'error', 7500)
        return
    end

    local playerPed = PlayerPedId()
    NotifyPlayer(t('you_delivered_the_package'), 'success')

    RemoveBlip(postalJobState.dropoffBlip)
    postalJobState.dropoffBlip = nil

    postalJobState.positionSet.endLocation = GetEntityCoords(playerPed)
    removeBox()

    TriggerServerEvent('dream-postal:server:compensateDelivery', postalJobState.positionSet)

    postalJobState.positionSet = {
        startLocation = nil,
        middleLocation = nil,
        endLocation = nil,
    }

    postalJobState.isCarryingBox = false

    -- TODO: add a thread that triggers a random animation from delivery ped before despawning
    postalJobState.isDeliveringPackage = false

    postalJobState.hasBoxInVan = false

    -- grab coords to go to pick up postal delivery
    local randomNumber = math.random(1, #POSTAL_GET_PACKAGE)
    local tempDeliveryCoords = POSTAL_GET_PACKAGE[randomNumber]

    local retval, groundZ = GetGroundZFor_3dCoord(tempDeliveryCoords.x, tempDeliveryCoords.y, tempDeliveryCoords.z, false)
    local deliveryCoords = tempDeliveryCoords
    if retval then
        deliveryCoords = vec3(tempDeliveryCoords.x, tempDeliveryCoords.y, groundZ)
    end

    SetNewWaypoint(deliveryCoords.x, deliveryCoords.y)

    local deliveryBlip = AddBlipForCoord(deliveryCoords)
	SetBlipSprite(deliveryBlip, PICK_UP_BLIP.sprite)
	SetBlipDisplay(deliveryBlip, PICK_UP_BLIP.display)
	SetBlipScale(deliveryBlip, PICK_UP_BLIP.scale)
	SetBlipColour(deliveryBlip, PICK_UP_BLIP.colour)
	SetBlipAsShortRange(deliveryBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(PICK_UP_BLIP.label)
	EndTextCommandSetBlipName(deliveryBlip)

    postalJobState.pickupBlip = deliveryBlip

    postalJobState.positionSet.startLocation = GetEntityCoords(playerPed)

    local parameters = {
        options = {{
            type   = "client",
            action = pickupMail,
            icon   = 'fas fa-envelope',
            label  = t('grab_package'),
        }},
        distance = 3.0,
        rotation = 45,
    }

    postalJobState.postalBoxZone = lib.zones.sphere({
        coords = deliveryCoords,
        size = vec3(1.0, 1.0, 3.0),
        rotation = 45,
        debug = false,
        onEnter = function()
            exports.ox_lib:showTextUI('[E] ' .. t('grab_package'), {icon = 'fas fa-envelope'})
        end,
        onExit = function()
            exports.ox_lib:hideTextUI()
        end,
        inside = function()
            if IsControlJustReleased(0, 38) then
                pickupMail()
            end
        end,
        distance = 3.0,
    })

    if (SHOW_WHITE_ARROW_MARKER) then
        CreateThread(function()
            while postalJobState.postalBoxZone do
                local playerCoords = GetEntityCoords(playerPed)
                local distanceToMarker = #(playerCoords - deliveryCoords)

                if (distanceToMarker <= 50.0) then
                    DrawMarker(22, deliveryCoords.x, deliveryCoords.y, (deliveryCoords.z + 1.75), 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 1.0, 255, 255, 220, 200, 0, 0, 0, 1)
                    Wait(1)
                else
                    Wait(3000)
                end
            end
        end)
    end
end

CreateThread(function()
    local blip = AddBlipForCoord(POSTAL_BOSS_COORDS)
	SetBlipSprite(blip, GO_POSTAL_HQ_BLIP.sprite)
	SetBlipDisplay(blip, GO_POSTAL_HQ_BLIP.display)
	SetBlipScale(blip, GO_POSTAL_HQ_BLIP.scale)
	SetBlipColour(blip, GO_POSTAL_HQ_BLIP.colour)
	SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(GO_POSTAL_HQ_BLIP.label)
	EndTextCommandSetBlipName(blip)
end)

CreateThread(function()
    while true do
        Citizen.Wait(2000)
        local playerCoords = GetEntityCoords(PlayerPedId())
        local distanceFromPed = #(POSTAL_BOSS_COORDS - playerCoords)

        if distanceFromPed < 200 and not isPedSpawned then
            isPedSpawned = true
            spawnPostalBossPed()
        end

        if postalBossPed and distanceFromPed >= 200 and isPedSpawned then
            isPedSpawned = false
            DeletePed(postalBossPed)
        end
    end
end)

RegisterCommand('removebox', function()
    if (not postalJobState.isCarryingBox) then return end
    removeBox()
end)

function removeBox()
    local playerPed = PlayerPedId()
    for _, v in pairs(GetGamePool("CObject")) do
        if IsEntityAttachedToEntity(playerPed, v) then
          SetEntityAsMissionEntity(v, true, true)
          DeleteObject(v)
          DeleteEntity(v)
        end
    end
    ClearPedTasks(playerPed)
end

local boxHash = `hei_prop_heist_box`
function carryBox()
    postalJobState.isCarryingBox = true
    local ped = PlayerPedId()
    local x,y,z = table.unpack(GetEntityCoords(ped))
    local prop = CreateObject(boxHash, x, y, z + 0.2,  true,  true, true)
	AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 60309), 0.025, 0.08, 0.255, -145.0, 290.0, 0.0, true, true, false, true, 1, true)
    LoadDict('anim@heists@box_carry@')

    if not IsEntityPlayingAnim(ped, "anim@heists@box_carry@", "idle", 3 ) then
        TaskPlayAnim(ped, 'anim@heists@box_carry@', "idle", 3.0, -8, -1, 63, 0, false, false, false)
    end

    -- ensure player does not drive while they have box in their hand to stop powergaming.
    CreateThread(function()
        while (postalJobState.isCarryingBox) do
            if IsPedInAnyVehicle(PlayerPedId(), false) then
                NotifyPlayer(t('you_cannot_drive_with_box'), 'error', 3000)
                SetVehicleEngineOn(postalJobState.goPostalVan, false, false, true)
            end
            Wait(3000)
        end
    end)
end

function LoadDict(dict)
    RequestAnimDict(dict)
	while not HasAnimDictLoaded(dict) do
	  	Citizen.Wait(10)
    end
end

local mask, tmask, hand, thand, pants, tpants, backpack, tbackpack, shoes, tshoes
local accessories, taccessories, undershirt, tundershirt, jacket, tjacket
local bodyarmor, tbodyarmor, decal, tdecal, propGlasses, propGlassesTexture

local maleHash = `mp_m_freemode_01`
function putOnJobOutfit()
    local playerPed = PlayerPedId()
    local isMale = IsPedModel(playerPed, maleHash)

    mask = GetPedDrawableVariation(playerPed, 1)
    tmask = GetPedTextureVariation(playerPed, 1)

    hand = GetPedDrawableVariation(playerPed, 3)
    thand = GetPedTextureVariation(playerPed, 3)

    pants = GetPedDrawableVariation(playerPed, 4)
    tpants = GetPedTextureVariation(playerPed, 4)

    backpack = GetPedDrawableVariation(playerPed, 5)
    tbackpack = GetPedTextureVariation(playerPed, 5)

    shoes = GetPedDrawableVariation(playerPed, 6)
    tshoes = GetPedTextureVariation(playerPed, 6)

    accessories = GetPedDrawableVariation(playerPed, 7)
    taccessories = GetPedTextureVariation(playerPed, 7)

    undershirt = GetPedDrawableVariation(playerPed, 8)
    tundershirt = GetPedTextureVariation(playerPed, 8)

    bodyarmor = GetPedDrawableVariation(playerPed, 9)
    tbodyarmor = GetPedTextureVariation(playerPed, 9)

    decal = GetPedDrawableVariation(playerPed, 10)
    tdecal = GetPedTextureVariation(playerPed, 10)

    jacket = GetPedDrawableVariation(playerPed, 11)
    tjacket = GetPedTextureVariation(playerPed, 11)

    propGlasses = GetPedPropIndex(playerPed, 1)
    propGlassesTexture = GetPedPropTextureIndex(playerPed, 1)

    if isMale then
        SetPedComponentVariation(playerPed, 1, MALE_OUTFIT.mask, MALE_OUTFIT.maskTexture)
        SetPedComponentVariation(playerPed, 3, MALE_OUTFIT.hand, MALE_OUTFIT.handTexture)
        SetPedComponentVariation(playerPed, 4, MALE_OUTFIT.pants, MALE_OUTFIT.pantsTexture)
        SetPedComponentVariation(playerPed, 5, MALE_OUTFIT.backpack, MALE_OUTFIT.backpackTexture)
        SetPedComponentVariation(playerPed, 6, MALE_OUTFIT.shoes, MALE_OUTFIT.shoesTexture)
        SetPedComponentVariation(playerPed, 7, MALE_OUTFIT.accessories, MALE_OUTFIT.accessoriesTexture)
        SetPedComponentVariation(playerPed, 8, MALE_OUTFIT.shirt, MALE_OUTFIT.shirtTexture)
        SetPedComponentVariation(playerPed, 9, MALE_OUTFIT.bodyArmor, MALE_OUTFIT.bodyArmorTexture)
        SetPedComponentVariation(playerPed, 10, MALE_OUTFIT.decal, MALE_OUTFIT.decalTexture)
        SetPedComponentVariation(playerPed, 11, MALE_OUTFIT.jacket, MALE_OUTFIT.jacketTexture)
        SetPedPropIndex(playerPed, 1, MALE_OUTFIT.glasses, MALE_OUTFIT.glassesTexture)
    else
        SetPedComponentVariation(playerPed, 1, FEMALE_OUTFIT.mask, FEMALE_OUTFIT.maskTexture)
        SetPedComponentVariation(playerPed, 3, FEMALE_OUTFIT.hand, FEMALE_OUTFIT.handTexture)
        SetPedComponentVariation(playerPed, 4, FEMALE_OUTFIT.pants, FEMALE_OUTFIT.pantsTexture)
        SetPedComponentVariation(playerPed, 5, FEMALE_OUTFIT.backpack, FEMALE_OUTFIT.backpackTexture)
        SetPedComponentVariation(playerPed, 6, FEMALE_OUTFIT.shoes, FEMALE_OUTFIT.shoesTexture)
        SetPedComponentVariation(playerPed, 7, FEMALE_OUTFIT.accessories, FEMALE_OUTFIT.accessoriesTexture)
        SetPedComponentVariation(playerPed, 8, FEMALE_OUTFIT.shirt, FEMALE_OUTFIT.shirtTexture)
        SetPedComponentVariation(playerPed, 9, FEMALE_OUTFIT.bodyArmor, FEMALE_OUTFIT.bodyArmorTexture)
        SetPedComponentVariation(playerPed, 10, FEMALE_OUTFIT.decal, FEMALE_OUTFIT.decalTexture)
        SetPedComponentVariation(playerPed, 11, FEMALE_OUTFIT.jacket, FEMALE_OUTFIT.jacketTexture)
        SetPedPropIndex(playerPed, 1, FEMALE_OUTFIT.glasses, FEMALE_OUTFIT.glassesTexture)
    end
end

function takeOffJobOutfit()
    local playerPed = PlayerPedId()

    SetPedComponentVariation(playerPed, 1, mask, tmask)
    SetPedComponentVariation(playerPed, 3, hand, thand)
    SetPedComponentVariation(playerPed, 4, pants, tpants)
    SetPedComponentVariation(playerPed, 5, backpack, tbackpack)
    SetPedComponentVariation(playerPed, 6, shoes, tshoes)
    SetPedComponentVariation(playerPed, 7, accessories, taccessories)
    SetPedComponentVariation(playerPed, 8, undershirt, tundershirt)
    SetPedComponentVariation(playerPed, 9, bodyarmor, tbodyarmor)
    SetPedComponentVariation(playerPed, 10, decal, tdecal)
    SetPedComponentVariation(playerPed, 11, jacket, tjacket)

    if (propGlasses <= 0) then
        ClearPedProp(playerPed, 1)
    else
        SetPedPropIndex(playerPed, 1, propGlasses, propGlassesTexture)
    end
end

function getVehicles()
	return GetGamePool('CVehicle')
end

function EnumerateEntitiesWithinDistance(entities, isPlayerEntities, coords, maxDistance)
	local nearbyEntities = {}

	if coords then
		coords = vector3(coords.x, coords.y, coords.z)
	else
		coords = GetEntityCoords(PlayerPedId())
	end

	for k, entity in pairs(entities) do
		if #(coords - GetEntityCoords(entity)) <= maxDistance then
			table.insert(nearbyEntities, isPlayerEntities and k or entity)
		end
	end

	return nearbyEntities
end

function getVehiclesInArea(coords, maxDistance)
	return EnumerateEntitiesWithinDistance(getVehicles(), false, coords, maxDistance)
end

function isSpawnPointClear(coords, maxDistance)
	return #getVehiclesInArea(coords, maxDistance) == 0
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if (postalJobState.isDoingJob) then
            NotifyPlayer(t('force_clock_out_script_restart'))
            takeOffJobOutfit()
            if (postalJobState.isCarryingBox) then
                removeBox()
            end
            resetJobState()
        end
    end
end)
