FRAMEWORK = nil
FRAMEWORK = exports["es_extended"]:getSharedObject()

function NotifyPlayer(message, type, duration)
    duration = duration or 5000
    lib.notify({
        title = 'GoPostal',
        description = message,
        type = type,
        duration = duration,
    })

end

RegisterNetEvent('dream-postal:client:notifyPlayer', function(message, type, duration)
    NotifyPlayer(message, type, duration)
end)

---@param vehicle number
function GivePlayerVehicleKeys(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle)
    TriggerEvent('vehiclekeys:client:SetOwner', plate)
end

local postalBoxHash = `prop_postbox_01a`

---@param searchRadius number
---@return vector3 | nil
function getNearestPostalBox(searchRadius)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local nearestPostalBox = GetClosestObjectOfType(playerCoords, searchRadius, postalBoxHash)
    if (nearestPostalBox == 0) then return nil end

    return GetEntityCoords(nearestPostalBox)
end
