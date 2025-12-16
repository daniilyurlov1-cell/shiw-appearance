local RSGCore = exports['rsg-core']:GetCoreObject()
local playerEquippedClothing = {}

local categoryLabels = {
    ['hats'] = 'Шляпа',
    ['shirts_full'] = 'Рубашка',
    ['shirts_band'] = 'Рубашка с повязкой',
    ['union_suits'] = 'Нижнее бельё',
    ['vests'] = 'Жилет',
    ['coats'] = 'Пальто',
    ['coats_closed'] = 'Закрытое пальто',
    ['cloaks'] = 'Плащ',
    ['ponchos'] = 'Пончо',
    ['duster'] = 'Пыльник',
    ['pants'] = 'Штаны',
    ['skirts'] = 'Юбка',
    ['chaps'] = 'Чапсы',
    ['boots'] = 'Сапоги',
    ['spats'] = 'Гетры',
    ['spurs'] = 'Шпоры',
    ['gloves'] = 'Перчатки',
    ['gauntlets'] = 'Наручи',
    ['rings_rh'] = 'Кольцо (правая)',
    ['rings_lh'] = 'Кольцо (левая)',
    ['bracelets'] = 'Браслет',
    ['neckwear'] = 'Шейный платок',
    ['neckties'] = 'Галстук',
    ['bow_ties'] = 'Бабочка',
    ['necklaces'] = 'Ожерелье',
    ['masks'] = 'Маска',
    ['masks_large'] = 'Большая маска',
    ['bandanas'] = 'Бандана',
    ['eyewear'] = 'Очки',
    ['suspenders'] = 'Подтяжки',
    ['belts'] = 'Ремень',
    ['belt_buckles'] = 'Пряжка ремня',
    ['gunbelts'] = 'Патронташ',
    ['gunbelt_accs'] = 'Аксессуар патронташа',
    ['holsters_left'] = 'Кобура (левая)',
    ['holsters_right'] = 'Кобура (правая)',
    ['holsters_crossdraw'] = 'Кобура перекрёстная',
    ['satchels'] = 'Сумка',
    ['loadouts'] = 'Снаряжение',
    ['armor'] = 'Броня',
    ['talisman_wrist'] = 'Талисман (запястье)',
    ['talisman_belt'] = 'Талисман (пояс)',
    ['talisman_satchel'] = 'Талисман (сумка)',
    ['badges'] = 'Значок',
    ['earrings'] = 'Серьги',
    ['accessories'] = 'Аксессуар',
    ['corsets'] = 'Корсет',
    ['blouses'] = 'Блузка',
    ['dresses'] = 'Платье',
    ['aprons'] = 'Фартук',
    ['sarapes'] = 'Сарапе',
    ['brawler_arms'] = 'Бойцовские повязки',
    ['sleeves'] = 'Нарукавники',
    ['cuffs'] = 'Манжеты'
}

function tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

-- Получить данные из info (поддержка обоих форматов)
function GetClothingData(info)
    if not info then return nil end
    return {
        category = info._c or info._category or info.category,
        hash = info._h or info._hash or info.hash,
        model = info._m or info._model or info.model or 0,
        texture = info._t or info._texture or info.texture or 1,
        isMale = info._g or info._isMale or info.isMale,
        equipped = info._e or info._equipped or info.equipped or false
    }
end

function SetItemEquipped(item, value)
    if not item or not item.info then return end
    -- Определяем какой формат используется
    if item.info._c ~= nil then
        item.info._e = value
    elseif item.info._category ~= nil then
        item.info._equipped = value
    else
        item.info.equipped = value
    end
end

-- ==========================================
-- СИНХРОНИЗАЦИЯ С БАЗОЙ ДАННЫХ
-- ==========================================

function SyncClothesToDatabase(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    local clothesFromInventory = {}
    
    for slot, item in pairs(Player.PlayerData.items) do
        if item and item.info then
            local data = GetClothingData(item.info)
            if data and data.equipped and data.category then
                clothesFromInventory[data.category] = {
                    hash = data.hash,
                    model = data.model,
                    texture = data.texture
                }
            end
        end
    end
    
    MySQL.execute('UPDATE playerskins SET clothes = @clothes WHERE citizenid = @citizenid', {
        ['@citizenid'] = citizenid,
        ['@clothes'] = json.encode(clothesFromInventory),
    })
    
    print('[RSG-Clothing] Synced: ' .. tablelength(clothesFromInventory) .. ' items')
end

RegisterNetEvent('rsg-clothing:server:syncInventoryToDatabase', function()
    SyncClothesToDatabase(source)
end)

-- ==========================================
-- ОСНОВНЫЕ СОБЫТИЯ APPEARANCE
-- ==========================================

RegisterServerEvent('rsg-appearance:server:saveOutfit', function(newClothes, isMale, outfitName)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
        
    local citizenid = Player.PlayerData.citizenid
    local skinData = MySQL.query.await('SELECT clothes FROM playerskins WHERE citizenid = ?', { citizenid })

    local newClothes = newClothes or {}
    local currentClothes = json.decode(skinData[1]?.clothes) or {}
    local price = CalculatePrice(newClothes, currentClothes, isMale)

    if Player.Functions.RemoveMoney('cash', price, 'buy-clothes') then
        MySQL.execute('UPDATE playerskins SET clothes = @clothes WHERE citizenid = @citizenid', {
            ['@citizenid'] = citizenid,
            ['@clothes'] = json.encode(newClothes),
        })
        if outfitName then
            MySQL.query.await('INSERT INTO playeroutfit (citizenid, name, clothes) VALUES (@citizenid, @name, @clothes)', {
                ['@citizenid'] = citizenid,
                ['@name'] = outfitName,
                ['@clothes'] = json.encode(newClothes),
            })
        end
    else
        TriggerClientEvent('ox_lib:notify', src, { title = locale('insufficient_funds.title'), description = locale('insufficient_funds.description'), type = 'error', duration = 5000 })
    end
end)

RegisterNetEvent('rsg-appearance:server:saveUseOutfit', function(clothes)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if clothes ~= nil then
        MySQL.execute('UPDATE playerskins SET clothes = @clothes WHERE citizenid = @citizenid', {
            ['@citizenid'] = Player.PlayerData.citizenid,
            ['@clothes'] = json.encode(clothes),
        })
    end
end)

RegisterServerEvent('rsg-appearance:server:DeleteOutfit')
AddEventHandler('rsg-appearance:server:DeleteOutfit', function(name)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local citizenid = Player.PlayerData.citizenid
    MySQL.Async.fetchAll('DELETE FROM playeroutfit WHERE citizenid = ? AND name = ?', {citizenid, name})
end)

lib.callback.register('rsg-appearance:server:LoadClothes', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    local citizenid = Player.PlayerData.citizenid
    local clothes = {}
    local Result = MySQL.query.await('SELECT clothes FROM playerskins WHERE citizenid = ?', { citizenid })

    if Result[1] ~= nil and Result[1].clothes ~= nil then
        clothes = json.decode(Result[1].clothes)
    end

    return clothes
end)

lib.callback.register('rsg-appearance:server:getOutfits', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    local outfit = {}
    local Result = MySQL.query.await('SELECT * FROM playeroutfit WHERE citizenid=@citizenid', {['@citizenid'] = Player.PlayerData.citizenid})

    for i = 1, #Result do
        Result[i].clothes = json.decode(Result[i].clothes)
        Result[i].name = Result[i].name
        outfit[#outfit+1] = Result[i]
    end

    return outfit
end)

-- ==========================================
-- СОХРАНЕНИЕ ОДЕЖДЫ В ИНВЕНТАРЬ
-- ==========================================

RegisterNetEvent('rsg-clothing:server:saveToInventory', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local category = data.category
    local hash = data.hash
    local isMale = data.isMale
    
    print('[RSG-Clothing] Saving: ' .. category)
    
    -- Проверка на дубликаты
    for slot, item in pairs(Player.PlayerData.items) do
        if item and item.info then
            local itemData = GetClothingData(item.info)
            if itemData and itemData.category == category and itemData.hash == hash then
                print('[RSG-Clothing] DUPLICATE: ' .. category)
                return
            end
        end
    end
    
    local itemName = 'clothing_' .. category
    if not RSGCore.Shared.Items[itemName] then
        itemName = 'clothing_item'
    end
    
    if not RSGCore.Shared.Items[itemName] then
        print('[RSG-Clothing] ERROR: Item not registered!')
        return
    end
    
    -- Минимальные короткие поля (меньше текста в инвентаре)
    local info = {
        _c = category,
        _h = hash,
        _m = data.model or 0,
        _t = data.texture or 1,
        _g = isMale,
        _e = true  -- СРАЗУ НАДЕВАЕМ
    }
    
    local success = Player.Functions.AddItem(itemName, 1, nil, info)
    
    if success then
        -- Добавляем в отслеживание
        if not playerEquippedClothing[src] then
            playerEquippedClothing[src] = {}
        end
        
        -- Находим слот куда добавился предмет
        for slot, item in pairs(Player.PlayerData.items) do
            if item and item.info then
                local itemData = GetClothingData(item.info)
                if itemData and itemData.category == category and itemData.hash == hash then
                    playerEquippedClothing[src][category] = slot
                    break
                end
            end
        end
        
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[itemName], 'add')
        print('[RSG-Clothing] Added & Equipped: ' .. itemName)
    end
end)

-- ==========================================
-- АВТОМАТИЧЕСКОЕ НАДЕВАНИЕ ПОСЛЕ ПОКУПКИ
-- ==========================================

RegisterNetEvent('rsg-clothing:server:equipAfterPurchase', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    if not playerEquippedClothing[src] then
        playerEquippedClothing[src] = {}
    end
    
    local equippedCount = 0
    
    for slot, item in pairs(Player.PlayerData.items) do
        if item and item.name and string.find(item.name, 'clothing') then
            if item.info then
                local data = GetClothingData(item.info)
                if data and data.category and data.equipped then
                    -- Добавляем в отслеживание
                    playerEquippedClothing[src][data.category] = slot
                    
                    -- Отправляем на клиент для надевания
                    TriggerClientEvent('rsg-clothing:client:equipClothing', src, {
                        category = data.category,
                        hash = data.hash,
                        model = data.model,
                        texture = data.texture,
                        isMale = data.isMale,
                        itemSlot = slot
                    })
                    
                    equippedCount = equippedCount + 1
                end
            end
        end
    end
    
    if equippedCount > 0 then
        SyncClothesToDatabase(src)
        print('[RSG-Clothing] Auto-equipped after purchase: ' .. equippedCount)
    end
end)

-- Регистрация useable предметов
CreateThread(function()
    Wait(2000)
    
    RSGCore.Functions.CreateUseableItem('clothing_item', function(source, item)
        ToggleClothingItem(source, item)
    end)
    
    for category, _ in pairs(categoryLabels) do
        local itemName = 'clothing_' .. category
        if RSGCore.Shared.Items[itemName] then
            RSGCore.Functions.CreateUseableItem(itemName, function(source, item)
                ToggleClothingItem(source, item)
            end)
        end
    end
    
    print('[RSG-Clothing] Useable items registered')
end)

-- Переключение одежды
function ToggleClothingItem(source, item)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    if not Player.PlayerData.items[item.slot] then return end
    
    local data = GetClothingData(item.info)
    if not data or not data.category then return end
    
    if not playerEquippedClothing[src] then
        playerEquippedClothing[src] = {}
    end
    
    print('[RSG-Clothing] Toggle: ' .. data.category .. ' | Current: ' .. tostring(data.equipped))
    
    if data.equipped then
        -- СНИМАЕМ
        SetItemEquipped(Player.PlayerData.items[item.slot], false)
        Player.Functions.SetInventory(Player.PlayerData.items)
        
        playerEquippedClothing[src][data.category] = nil
        
        TriggerClientEvent('rsg-clothing:client:removeClothing', src, data.category)
        SyncClothesToDatabase(src)
        
        print('[RSG-Clothing] REMOVED: ' .. data.category)
    else
        -- НАДЕВАЕМ
        
        -- Снимаем старую одежду этой категории
        if playerEquippedClothing[src][data.category] then
            local oldSlot = playerEquippedClothing[src][data.category]
            if Player.PlayerData.items[oldSlot] then
                SetItemEquipped(Player.PlayerData.items[oldSlot], false)
            end
        end
        
        SetItemEquipped(Player.PlayerData.items[item.slot], true)
        Player.Functions.SetInventory(Player.PlayerData.items)
        
        playerEquippedClothing[src][data.category] = item.slot
        
        TriggerClientEvent('rsg-clothing:client:equipClothing', src, {
            category = data.category,
            hash = data.hash,
            model = data.model,
            texture = data.texture,
            isMale = data.isMale,
            itemSlot = item.slot
        })
        
        SyncClothesToDatabase(src)
        
        print('[RSG-Clothing] EQUIPPED: ' .. data.category)
    end
end

-- ==========================================
-- АВТОСНЯТИЕ ПРИ УДАЛЕНИИ ИЗ ИНВЕНТАРЯ
-- ==========================================

function CheckPlayerClothingImmediate(src)
    if not playerEquippedClothing[src] then return end
    
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData or not Player.PlayerData.items then
        playerEquippedClothing[src] = nil
        return
    end
    
    local itemsToRemove = {}
    
    for category, slot in pairs(playerEquippedClothing[src]) do
        local item = Player.PlayerData.items[slot]
        
        if not item then
            table.insert(itemsToRemove, category)
        elseif not item.info then
            table.insert(itemsToRemove, category)
        else
            local data = GetClothingData(item.info)
            if not data or data.category ~= category then
                table.insert(itemsToRemove, category)
            end
        end
    end
    
    if #itemsToRemove > 0 then
        for _, category in ipairs(itemsToRemove) do
            playerEquippedClothing[src][category] = nil
            TriggerClientEvent('rsg-clothing:client:removeClothing', src, category)
            print('[RSG-Clothing] AUTO-REMOVED: ' .. category)
        end
        SyncClothesToDatabase(src)
    end
end

-- Периодическая проверка
CreateThread(function()
    Wait(5000)
    print('[RSG-Clothing] Inventory check started')
    
    while true do
        Wait(500)
        for src, _ in pairs(playerEquippedClothing) do
            CheckPlayerClothingImmediate(src)
        end
    end
end)

-- Обработчик изменения инвентаря
RegisterNetEvent('inventory:server:SetInventoryData', function(fromInventory, toInventory, fromSlot)
    local src = source
    
    if fromInventory == "player" or fromInventory == src then
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then return end
        
        local item = Player.PlayerData.items[fromSlot]
        
        if item and item.name and string.find(item.name, 'clothing') then
            local data = GetClothingData(item.info)
            if data and data.equipped then
                SetItemEquipped(item, false)
                
                if playerEquippedClothing[src] and playerEquippedClothing[src][data.category] == fromSlot then
                    playerEquippedClothing[src][data.category] = nil
                    TriggerClientEvent('rsg-clothing:client:removeClothing', src, data.category)
                    SyncClothesToDatabase(src)
                end
            end
        end
        
        Wait(100)
        CheckPlayerClothingImmediate(src)
    end
end)

RegisterNetEvent('rsg-inventory:server:SaveInventory', function()
    Wait(100)
    CheckPlayerClothingImmediate(source)
end)

-- Сброс флага при подборе
RegisterNetEvent('rsg-inventory:server:addItem', function(itemName, amount, slot)
    local src = source
    
    if itemName and string.find(itemName, 'clothing') then
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then return end
        
        Wait(100)
        
        local item = Player.PlayerData.items[slot]
        if item and item.info then
            local data = GetClothingData(item.info)
            if data and data.equipped then
                SetItemEquipped(item, false)
                Player.Functions.SetInventory(Player.PlayerData.items)
            end
        end
    end
end)

-- ==========================================
-- ПОЛУЧЕНИЕ ОДЕЖДЫ ИЗ ИНВЕНТАРЯ
-- ==========================================

RSGCore.Functions.CreateCallback('rsg-clothing:server:getEquippedClothing', function(source, cb)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then 
        cb({})
        return 
    end
    
    local equippedItems = {}
    
    if not playerEquippedClothing[src] then
        playerEquippedClothing[src] = {}
    end
    
    for slot, item in pairs(Player.PlayerData.items) do
        if item and item.info then
            local data = GetClothingData(item.info)
            if data and data.equipped and data.category then
                equippedItems[data.category] = {
                    hash = data.hash,
                    model = data.model,
                    texture = data.texture,
                    isMale = data.isMale,
                    itemSlot = slot
                }
                playerEquippedClothing[src][data.category] = slot
            end
        end
    end
    
    cb(equippedItems)
end)

-- Очистка при выходе
AddEventHandler('playerDropped', function()
    playerEquippedClothing[source] = nil
end)

-- Команда отладки
RegisterCommand('checkclothes', function(source)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    print('=== CLOTHING DEBUG ===')
    if playerEquippedClothing[src] then
        for cat, slot in pairs(playerEquippedClothing[src]) do
            print('  ' .. cat .. ' -> slot ' .. slot)
        end
    end
    print('======================')
end, false)

print('[RSG-Clothing] Server loaded')