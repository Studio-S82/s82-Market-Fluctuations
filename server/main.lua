local DATA = {}
local metaSell = {
    last_time_change = 0,
    itemBuy          = {}
}
local uiUser = nil  

lib.callback.register('s82chotroi:server:requestUI', function(src)
    if uiUser ~= nil and uiUser ~= src then
        if not GetPlayerName(uiUser) then
            uiUser = nil
        else
            Notify(src, 'Hiện tại đã có người đang sử dụng khu thu mua, vui lòng chờ!', 'error')
            return false
        end
    end
    uiUser = src
    return true
end)

lib.callback.register('s82chotroi:server:releaseUI', function(src)
    if uiUser == src then
        uiUser = nil
    end
    return true
end)
AddEventHandler('playerDropped', function()
    if uiUser == source then
        uiUser = nil
    end
end)
local function GetQBXPlayer(src)
    return exports.qbx_core:GetPlayer(src)
end

local function GetPlayerFullName(src)
    local p = GetQBXPlayer(src)
    if not p then return 'Unknown (' .. tostring(src) .. ')' end
    return p.PlayerData.charinfo.firstname .. ' ' .. p.PlayerData.charinfo.lastname
end

local function AddMoneyToPlayer(src, amount, reason)
    local p = GetQBXPlayer(src)
    if not p then return end
    p.Functions.AddMoney('bank', amount, reason)
end

local function Notify(src, msg, ntype)
    TriggerClientEvent('ox_lib:notify', src, {
        title       = 'Chợ Trời',
        description = msg,
        type        = ntype or 'info',
        position    = 'center-left',
        duration    = 5000
    })
end
local function round(num, numDecimalPlaces)
    local mult = 10 ^ (numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end
local function GetDataByItemName(itemName)
    for _, v in pairs(DATA) do
        if v.itemName == itemName then return v end
    end
    return nil
end
local function ChangeItemBuy()
    metaSell.last_time_change = os.time()
    metaSell.itemBuy = {}

    local itemList = {}
    for k in pairs(Config.Items.normal) do
        table.insert(itemList, k)
    end
    local countToPick = math.min(15, #itemList)
    local picked = {}
    local attempts = 0
    local maxAttempts = countToPick * 10  

    while #picked < countToPick and attempts < maxAttempts do
        attempts = attempts + 1
        local item = itemList[math.random(1, #itemList)]
        if not metaSell.itemBuy[item] then
            metaSell.itemBuy[item] = true
            table.insert(picked, item)
        end
    end

    SaveResourceFile(GetCurrentResourceName(), 'cache.json', json.encode(metaSell), -1)

    TriggerClientEvent('ox_lib:notify', -1, {
        title       = 'Chợ Trời',
        description = 'Danh sách vật phẩm thu mua đã được cập nhật',
        type        = 'inform',
        position    = 'center-left',
        duration    = 8000
    })
end
CreateThread(function()
    local file = LoadResourceFile(GetCurrentResourceName(), 'cache.json')
    if file and file ~= '' and file ~= '[]' then
        local ok, decoded = pcall(json.decode, file)
        if ok and type(decoded) == 'table' then
            metaSell.last_time_change = decoded.last_time_change or 0
            metaSell.itemBuy          = decoded.itemBuy or {}
        end
    end

    if metaSell.last_time_change == 0 then
        ChangeItemBuy()
    end
    while true do
        Wait(60 * 1000)
        if os.time() - metaSell.last_time_change >= 60 * 60 * 6 then
            ChangeItemBuy()
        end
    end
end)

local function InitEconomy()
    DATA = {}
    local oxItems = exports.ox_inventory:Items()

    for _, categoryItems in pairs(Config.Items) do
        for itemName, itemData in pairs(categoryItems) do
            local itemShared = oxItems[itemName]
            if not itemShared then
                print(('[s82chotroi] Item không tồn tại trong ox_inventory: %s'):format(itemName))
            else
                local price  = math.random(itemData.Min, itemData.Max)
                local center = round((itemData.Min + itemData.Max) / 2)
                local status = price > center and 'up' or price < center and 'down' or 'equal'

                DATA[#DATA + 1] = {
                    Price          = price,
                    Min            = itemData.Min,
                    Max            = itemData.Max,
                    AmountToChange = itemData.AmountToChange,
                    CurrentAmount  = 0,
                    Label          = itemShared.label,
                    image          = (itemShared.client and itemShared.client.image) or (itemName .. '.png'),
                    Status         = status,
                    itemName       = itemName
                }
            end
        end
    end

    table.sort(DATA, function(a, b) return a.Price > b.Price end)

    if Config.TuDong_ThayDoiGia then
        CreateThread(function()
            while true do
                Wait(Config.ThoiGian_CapNhat * 60000)

                for _, v in pairs(DATA) do
                    local newPrice = math.random(v.Min, v.Max)
                    v.Status = newPrice > v.Price and 'up' or newPrice < v.Price and 'down' or 'equal'
                    v.Price  = newPrice
                end

                table.sort(DATA, function(a, b) return a.Price > b.Price end)
                TriggerClientEvent('s82chotroi:setPrices', -1, DATA)

                TriggerClientEvent('ox_lib:notify', -1, {
                    title       = 'Chợ Trời',
                    description = 'Giá cả thu mua đã được cập nhật',
                    type        = 'inform',
                    position    = 'center-left',
                    duration    = 8000
                })
            end
        end)
    end
end

InitEconomy()

local function UpdatePriceAfterSell(itemEco, soldAmount)
    itemEco.CurrentAmount = itemEco.CurrentAmount + soldAmount
    if itemEco.CurrentAmount < itemEco.AmountToChange then return end

    itemEco.CurrentAmount = 0
    local newPrice = math.random(itemEco.Min, itemEco.Max)
    itemEco.Status = newPrice > itemEco.Price and 'up' or newPrice < itemEco.Price and 'down' or 'equal'
    itemEco.Price  = newPrice

    table.sort(DATA, function(a, b) return a.Price > b.Price end)
    TriggerClientEvent('s82chotroi:update', -1, itemEco.itemName, itemEco)
end
RegisterServerEvent('s82chotroi:cfx:action', function(item, amount)
    local src = source
    amount = tonumber(amount)
    if not amount or amount <= 0 or amount ~= math.floor(amount) then return end
    if uiUser ~= src then
        Notify(src, 'Phiên giao dịch không hợp lệ', 'error')
        return
    end

    local itemEco = GetDataByItemName(item)
    if not itemEco then
        Notify(src, 'Vật phẩm không có trong danh sách thu mua', 'error')
        return
    end

    local count = exports.ox_inventory:GetItemCount(src, item)
    if not count or count < amount then
        Notify(src,
            ('Không đủ %s để bán (Cần: %d, Có: %d)'):format(itemEco.Label or item, amount, count or 0),
            'error'
        )
        return
    end

    if not exports.ox_inventory:RemoveItem(src, item, amount) then
        Notify(src, 'Không thể lấy vật phẩm từ túi đồ', 'error')
        return
    end

    local totalPrice = math.abs(itemEco.Price * amount)
    AddMoneyToPlayer(src, totalPrice, '[CHỢ TRỜI] Bán vật phẩm')

    Notify(src,
        ('Bán thành công x%d %s — Thu về $%s'):format(amount, itemEco.Label or item, totalPrice),
        'success'
    )

    pcall(function()
        TriggerEvent('qb-log:server:CreateLog', 'log_sellitem', '**CHỢ TRỜI**', 'lightgreen',
            ('`\n👤 %s\n📦 %s  x%d\n💰 $%d`'):format(
                GetPlayerFullName(src), itemEco.Label or item, amount, totalPrice
            ), false)
    end)

    pcall(function()
        TriggerClientEvent('alive_quest:action', src, 'sell_' .. item, amount)
    end)

    UpdatePriceAfterSell(itemEco, amount)
end)
RegisterServerEvent('s82chotroi:cfx:action-all', function(item)
    local src = source
    if uiUser ~= src then
        Notify(src, 'Phiên giao dịch không hợp lệ', 'error')
        return
    end

    local itemEco = GetDataByItemName(item)
    if not itemEco then
        Notify(src, 'Vật phẩm không có trong danh sách thu mua', 'error')
        return
    end

    local count = exports.ox_inventory:GetItemCount(src, item)
    if not count or count <= 0 then
        Notify(src, ('Bạn không có %s trong túi đồ'):format(itemEco.Label or item), 'error')
        return
    end

    if not exports.ox_inventory:RemoveItem(src, item, count) then
        Notify(src, 'Không thể lấy vật phẩm từ túi đồ', 'error')
        return
    end

    local totalPrice = math.abs(itemEco.Price * count)
    AddMoneyToPlayer(src, totalPrice, '[CHỢ TRỜI] Bán vật phẩm')

    Notify(src,
        ('Bán thành công x%d %s — Thu về $%s'):format(count, itemEco.Label or item, totalPrice),
        'success'
    )

    pcall(function()
        TriggerEvent('qb-log:server:CreateLog', 'log_sellitem', '**CHỢ TRỜI**', 'orange',
            ('`\n👤 %s\n📦 %s  x%d\n💰 $%d`'):format(
                GetPlayerFullName(src), itemEco.Label or item, count, totalPrice
            ), false)
    end)

    pcall(function()
        TriggerClientEvent('alive_quest:action', src, 'sell_' .. item, count)
    end)

    UpdatePriceAfterSell(itemEco, count)
end)
RegisterServerEvent('s82chotroi:cfx:getPrices')
AddEventHandler('s82chotroi:cfx:getPrices', function()
    TriggerClientEvent('s82chotroi:setPrices', source, DATA, metaSell.itemBuy)
end)
lib.callback.register('s82chotroi:server:getInv', function(src)
    local inventory = {}
    local items = exports.ox_inventory:GetInventoryItems(src)

    if items then
        for _, item in pairs(items) do
            if item and item.name and item.count and item.count > 0 then
                inventory[item.name] = (inventory[item.name] or 0) + item.count
            end
        end
    end

    return inventory
end)
