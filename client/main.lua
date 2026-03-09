local DATA       = {}
local META       = {}
local LOC        = {}
local ACTIVE     = false
local LOCCLOSETO = 0
local NPC        = {}
local POPUP      = false

CreateThread(function()
    while true do
        Wait(0)
        if (ACTIVE or POPUP) and IsDisabledControlJustPressed(0, 200) then
            if ACTIVE then
                CloseMenu()
            elseif POPUP then
                POPUP = false
                SetNuiFocus(false, false)
                SendNUIMessage({ type = 'hide-popup' })
            end
        end
    end
end)

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do
        Wait(300)
    end
    Wait(500)

    TriggerServerEvent('s82chotroi:cfx:getPrices')
    InitEnvironment()
    InitLoop()

    RegisterCommand('thitruong', function()
        if POPUP then return end
        POPUP = true
        SetNuiFocus(true, true)
        SendNUIMessage({ type = 'show-price' })
    end, false)
end)

function InitEnvironment()
    local zoneId  = 0
    local oxItems = exports.ox_inventory:Items()

    local function initData(coords, v)
        zoneId = zoneId + 1
        local itemList = {}
        for item, itemData in pairs(v.Items) do
            local itemShared = oxItems[item]
            if not itemShared then
                print(('[s82chotroi] Item không có trong ox_inventory: %s'):format(item))
            else
                table.insert(itemList, {
                    Min      = itemData.Min,
                    Max      = itemData.Max,
                    Label    = itemShared.label,
                    image    = (itemShared.client and itemShared.client.image) or (item .. '.png'),
                    itemName = item,
                })
            end
        end

        table.insert(LOC, { Coords = coords, Items = itemList })

        local currentZone = zoneId
        exports.ox_target:addSphereZone({
            coords  = vec3(coords.x, coords.y, coords.z),
            radius  = 1.5,
            debug   = false,
            options = {
                {
                    name     = 's82chotroi_npc_' .. currentZone,
                    icon     = 'fas fa-store',
                    label    = 'Nói chuyện',
                    onSelect = function() OpenMenu() end
                }
            }
        })

        if v.Blip.Enable then
            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipSprite(blip, v.Blip.Sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, v.Blip.Scale)
            SetBlipColour(blip, v.Blip.Color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(v.Blip.Label)
            EndTextCommandSetBlipName(blip)
        end

        local modelHash = GetHashKey(v.NPCModel)
        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do Wait(50) end

        local animDict = 'mini@strip_club@idles@bouncer@base'
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do Wait(50) end

        local npc = CreatePed(4, v.NPCHash, coords.x, coords.y, coords.z - 1, v.NPCHeading or 0, false, true)
        SetEntityHeading(npc, coords.w)
        FreezeEntityPosition(npc, true)
        SetEntityInvincible(npc, true)
        SetBlockingOfNonTemporaryEvents(npc, true)
        TaskPlayAnim(npc, animDict, 'base', 8.0, 0.0, -1, 1, 0, false, false, false)
        SetModelAsNoLongerNeeded(modelHash)
        table.insert(NPC, npc)
    end

    for _, v in pairs(Config.Locations) do
        if type(v.Coords) == 'vector4' then
            initData(v.Coords, v)
        elseif type(v.Coords) == 'table' then
            for _, coords in pairs(v.Coords) do
                initData(coords, v)
            end
        end
    end
end

function InitLoop()
    CreateThread(function()
        while true do
            if ACTIVE then
                Wait(500)
            else
                local ped    = PlayerPedId()
                local coords = GetEntityCoords(ped)
                for k, v in pairs(LOC) do
                    local dist = GetDistanceBetweenCoords(coords, v.Coords, true)
                    if dist <= 2.5 then LOCCLOSETO = k; break end
                end
                Wait(250)
            end
        end
    end)
end

function OpenMenu()
    if ACTIVE then return end
    if not LOC[LOCCLOSETO] then return end
    lib.callback('s82chotroi:server:requestUI', false, function(granted)
        if not granted then return end
        ACTIVE = true
        OpenOrRefreshUI()
    end)
end

function OpenOrRefreshUI()
    if not LOC[LOCCLOSETO] then return end
    lib.callback('s82chotroi:server:getInv', false, function(inv)
        SendNUIMessage({
            type      = 'open',
            items     = LOC[LOCCLOSETO].Items,
            inventory = inv or {},
            meta      = META
        })
        SetNuiFocus(true, true)
        LocalPlayer.state:set('invBusy', true, true)
    end)
end

function CloseMenu()
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'close' })
    ACTIVE = false
    POPUP  = false
    LocalPlayer.state:set('invBusy', false, true)
    lib.callback('s82chotroi:server:releaseUI', false, function() end)
end

RegisterNetEvent('s82chotroi:setPrices')
AddEventHandler('s82chotroi:setPrices', function(data, meta)
    DATA = data; META = meta
    SendNUIMessage({ type = 'set-price', data = DATA, meta = meta })
end)

RegisterNetEvent('s82chotroi:update')
AddEventHandler('s82chotroi:update', function(item, data)
    for k, v in pairs(DATA) do
        if v.itemName == item then DATA[k] = data; break end
    end
    SendNUIMessage({ type = 'update-price', item = item, data = data })
end)

RegisterNUICallback('action', function(data, cb)
    cb('ok')
    local amount = tonumber(data.amount)
    if not amount or amount <= 0 then
        lib.notify({ title = 'Chợ Trời', description = 'Số lượng không hợp lệ', type = 'error' })
        return
    end
    TriggerServerEvent('s82chotroi:cfx:action', data.item, amount)
    SetTimeout(500, OpenOrRefreshUI)
end)

RegisterNUICallback('action-all', function(data, cb)
    cb('ok')
    TriggerServerEvent('s82chotroi:cfx:action-all', data.item)
    SetTimeout(500, OpenOrRefreshUI)
end)

RegisterNUICallback('close', function(_, cb)
    cb('ok')
    CloseMenu()
end)

RegisterNUICallback('popup-close', function(_, cb)
    cb('ok')
    POPUP = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'hide-popup' })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if ACTIVE then
        SetNuiFocus(false, false)
        LocalPlayer.state:set('invBusy', false, true)
    end
    for _, ped in pairs(NPC) do
        if DoesEntityExist(ped) then DeletePed(ped) end
    end
end)
