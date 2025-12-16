<img width="2948" height="497" alt="rsg_framework" src="https://github.com/user-attachments/assets/638791d8-296d-4817-a596-785325c1b83a" />

# 👱 rsg-appearance
**Character creator and clothing system for RedM using RSG Core.**

![Platform](https://img.shields.io/badge/platform-RedM-darkred)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

> Full appearance, character creation, and clothing system for RedM built on RSG Core.  
> Includes gender selection, detailed features, and dynamic clothing support.

---

## 🛠️ Dependencies
- [**rsg-core**](https://github.com/Rexshack-RedM/rsg-core) 🤠
- [**ox_lib**](https://github.com/Rexshack-RedM/ox_lib) ⚙️ *(for notifications and UI)*
- [**rsg-menubase**](https://github.com/Rexshack-RedM/rsg-menubase) 🎨 *(for in-game menus)*
- [**oxmysql**](https://github.com/overextended/oxmysql) 🗄️ *(for player skins storage)*

**Data files:** The `/data` folder includes lists for hair, overlays, features, and clothing variations.  
**Locales:** `locales/en.json`, `locales/pt-br.json` loaded via `lib.locale()`.  
**Images:** UI icons and references are stored in `/img`.

---

## ✨ Features

### 🧍 Character Creation
- Fully interactive **character creator**.
- Select **gender, first name, last name, nationality, birthdate**.
- Adjust all appearance details using menus powered by **rsg-menubase**.
- Real-time preview while creating your character.

### 👕 Clothing System
- Choose and apply clothing dynamically from predefined lists in `data/clothes_list.lua`.
- Save and load outfits.
- Purchase new clothing ,the system calculates price differences automatically.
- Supports male and female components, hair, overlays, and features.

### 💾 Server-Side Persistence
- Automatically saves appearance and clothing to SQL.
- Commands/events handled server-side for security:
  - `rsg-appearance:server:SaveSkin`
  - `rsg-appearance:server:saveOutfit`
- Uses table `playerskins` with columns: `citizenid`, `skin`, `clothes`.

### 💰 Price Calculation
- Automatic cost calculation when changing clothes.
- Deducts in-game cash using RSGCore’s economy system:
  ```lua
  Player.Functions.RemoveMoney('cash', price, 'buy-clothes')
  ```

### 🌍 Localization
- Built-in language support (English, Portuguese-BR).
- Easy to extend with new locale files.

---

## 📸 Preview
*(soon)*

---

## 📂 Installation
1. Place `rsg-appearance` inside your `resources/[rsg]` folder.
2. Ensure `rsg-core`, `ox_lib`, `rsg-menubase`, and `oxmysql` are installed.
3. Import the SQL for player skins if not already present:
   ```sql
   CREATE TABLE IF NOT EXISTS `playerskins` (
       `citizenid` VARCHAR(50) NOT NULL,
       `skin` LONGTEXT NULL DEFAULT NULL,
       `clothes` LONGTEXT NULL DEFAULT NULL,
       PRIMARY KEY (`citizenid`)
   );
   ```
4. Shared Item items.lua:
     ```
  -- ==========================================
  -- ОДЕЖДА - ГОЛОВНЫЕ УБОРЫ
  -- ==========================================
  ['clothing_hats']               = {['name'] = 'clothing_hats',              ['label'] = 'Шляпа',                ['weight'] = 200,   ['type'] = 'item', ['image'] = 'clothing_hats.png',            ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Головной убор'},
  
  -- ==========================================
  -- ОДЕЖДА - ВЕРХНЯЯ ЧАСТЬ ТЕЛА
  -- ==========================================
  ['clothing_shirts_full']        = {['name'] = 'clothing_shirts_full',       ['label'] = 'Рубашка',              ['weight'] = 300,   ['type'] = 'item', ['image'] = 'clothing_shirts_full.png',     ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Рубашка'},
  ['clothing_shirts_band']        = {['name'] = 'clothing_shirts_band',       ['label'] = 'Рубашка с повязкой',   ['weight'] = 300,   ['type'] = 'item', ['image'] = 'clothing_shirts_band.png',     ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Рубашка с нарукавной повязкой'},
  ['clothing_union_suits']        = {['name'] = 'clothing_union_suits',       ['label'] = 'Нижнее бельё',         ['weight'] = 200,   ['type'] = 'item', ['image'] = 'clothing_union_suits.png',     ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Нательное бельё'},
  ['clothing_vests']              = {['name'] = 'clothing_vests',             ['label'] = 'Жилет',                ['weight'] = 300,   ['type'] = 'item', ['image'] = 'clothing_vests.png',           ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Жилет'},
  ['clothing_coats']              = {['name'] = 'clothing_coats',             ['label'] = 'Пальто',               ['weight'] = 800,   ['type'] = 'item', ['image'] = 'clothing_coats.png',           ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Пальто'},
  ['clothing_coats_closed']       = {['name'] = 'clothing_coats_closed',      ['label'] = 'Закрытое пальто',      ['weight'] = 800,   ['type'] = 'item', ['image'] = 'clothing_coats_closed.png',    ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Застёгнутое пальто'},
  ['clothing_cloaks']             = {['name'] = 'clothing_cloaks',            ['label'] = 'Плащ',                 ['weight'] = 600,   ['type'] = 'item', ['image'] = 'clothing_cloaks.png',          ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Плащ'},
  ['clothing_ponchos']            = {['name'] = 'clothing_ponchos',           ['label'] = 'Пончо',                ['weight'] = 500,   ['type'] = 'item', ['image'] = 'clothing_ponchos.png',         ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Пончо'},
  ['clothing_duster']             = {['name'] = 'clothing_duster',            ['label'] = 'Пыльник',              ['weight'] = 700,   ['type'] = 'item', ['image'] = 'clothing_duster.png',          ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Длинное пальто-пыльник'},
  
  -- ==========================================
  -- ОДЕЖДА - НИЖНЯЯ ЧАСТЬ ТЕЛА
  -- ==========================================
  ['clothing_pants']              = {['name'] = 'clothing_pants',             ['label'] = 'Штаны',                ['weight'] = 400,   ['type'] = 'item', ['image'] = 'clothing_pants.png',           ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Штаны'},
  ['clothing_skirts']             = {['name'] = 'clothing_skirts',            ['label'] = 'Юбка',                 ['weight'] = 350,   ['type'] = 'item', ['image'] = 'clothing_skirts.png',          ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Юбка'},
  ['clothing_chaps']              = {['name'] = 'clothing_chaps',             ['label'] = 'Чапсы',                ['weight'] = 400,   ['type'] = 'item', ['image'] = 'clothing_chaps.png',           ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Кожаные накладки на ноги'},
  
  -- ==========================================
  -- ОДЕЖДА - ОБУВЬ
  -- ==========================================
  ['clothing_boots']              = {['name'] = 'clothing_boots',             ['label'] = 'Сапоги',               ['weight'] = 500,   ['type'] = 'item', ['image'] = 'clothing_boots.png',           ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Сапоги'},
  ['clothing_spats']              = {['name'] = 'clothing_spats',             ['label'] = 'Гетры',                ['weight'] = 150,   ['type'] = 'item', ['image'] = 'clothing_spats.png',           ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Гетры на обувь'},
  ['clothing_spurs']              = {['name'] = 'clothing_spurs',             ['label'] = 'Шпоры',                ['weight'] = 100,   ['type'] = 'item', ['image'] = 'clothing_spurs.png',           ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Шпоры для верховой езды'},
  
  -- ==========================================
  -- ОДЕЖДА - РУКИ
  -- ==========================================
  ['clothing_gloves']             = {['name'] = 'clothing_gloves',            ['label'] = 'Перчатки',             ['weight'] = 100,   ['type'] = 'item', ['image'] = 'clothing_gloves.png',          ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Перчатки'},
  ['clothing_gauntlets']          = {['name'] = 'clothing_gauntlets',         ['label'] = 'Наручи',               ['weight'] = 200,   ['type'] = 'item', ['image'] = 'clothing_gauntlets.png',       ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Защитные наручи'},
  ['clothing_rings_rh']           = {['name'] = 'clothing_rings_rh',          ['label'] = 'Кольцо (правая)',      ['weight'] = 20,    ['type'] = 'item', ['image'] = 'clothing_rings_rh.png',        ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Кольцо на правую руку'},
  ['clothing_rings_lh']           = {['name'] = 'clothing_rings_lh',          ['label'] = 'Кольцо (левая)',       ['weight'] = 20,    ['type'] = 'item', ['image'] = 'clothing_rings_lh.png',        ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Кольцо на левую руку'},
  ['clothing_bracelets']          = {['name'] = 'clothing_bracelets',         ['label'] = 'Браслет',              ['weight'] = 30,    ['type'] = 'item', ['image'] = 'clothing_bracelets.png',       ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Браслет'},
  
  -- ==========================================
  -- ОДЕЖДА - ШЕЯ И ЛИЦО
  -- ==========================================
  ['clothing_neckwear']           = {['name'] = 'clothing_neckwear',          ['label'] = 'Шейный платок',        ['weight'] = 100,   ['type'] = 'item', ['image'] = 'clothing_neckwear.png',        ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Платок или галстук'},
  ['clothing_neckties']           = {['name'] = 'clothing_neckties',          ['label'] = 'Галстук',              ['weight'] = 50,    ['type'] = 'item', ['image'] = 'clothing_neckties.png',        ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Галстук'},
  ['clothing_bow_ties']           = {['name'] = 'clothing_bow_ties',          ['label'] = 'Бабочка',              ['weight'] = 30,    ['type'] = 'item', ['image'] = 'clothing_bow_ties.png',        ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Галстук-бабочка'},
  ['clothing_necklaces']          = {['name'] = 'clothing_necklaces',         ['label'] = 'Ожерелье',             ['weight'] = 50,    ['type'] = 'item', ['image'] = 'clothing_necklaces.png',       ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Ожерелье'},
  ['clothing_masks']              = {['name'] = 'clothing_masks',             ['label'] = 'Маска',                ['weight'] = 100,   ['type'] = 'item', ['image'] = 'clothing_masks.png',           ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Маска на лицо'},
  ['clothing_masks_large']        = {['name'] = 'clothing_masks_large',       ['label'] = 'Большая маска',        ['weight'] = 150,   ['type'] = 'item', ['image'] = 'clothing_masks_large.png',     ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Большая маска'},
  ['clothing_bandanas']           = {['name'] = 'clothing_bandanas',          ['label'] = 'Бандана',              ['weight'] = 50,    ['type'] = 'item', ['image'] = 'clothing_bandanas.png',        ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Бандана'},
  ['clothing_eyewear']            = {['name'] = 'clothing_eyewear',           ['label'] = 'Очки',                 ['weight'] = 50,    ['type'] = 'item', ['image'] = 'clothing_eyewear.png',         ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Очки'},
  
  -- ==========================================
  -- ОДЕЖДА - АКСЕССУАРЫ И РЕМНИ
  -- ==========================================
  ['clothing_suspenders']         = {['name'] = 'clothing_suspenders',        ['label'] = 'Подтяжки',             ['weight'] = 150,   ['type'] = 'item', ['image'] = 'clothing_suspenders.png',      ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Подтяжки'},
  ['clothing_belts']              = {['name'] = 'clothing_belts',             ['label'] = 'Ремень',               ['weight'] = 200,   ['type'] = 'item', ['image'] = 'clothing_belts.png',           ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Поясной ремень'},
  ['clothing_belt_buckles']       = {['name'] = 'clothing_belt_buckles',      ['label'] = 'Пряжка ремня',         ['weight'] = 100,   ['type'] = 'item', ['image'] = 'clothing_belt_buckles.png',    ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Пряжка для ремня'},
  ['clothing_gunbelts']           = {['name'] = 'clothing_gunbelts',          ['label'] = 'Патронташ',            ['weight'] = 400,   ['type'] = 'item', ['image'] = 'clothing_gunbelts.png',        ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Пояс с патронами'},
  ['clothing_gunbelt_accs']       = {['name'] = 'clothing_gunbelt_accs',      ['label'] = 'Аксессуар патронташа', ['weight'] = 150,   ['type'] = 'item', ['image'] = 'clothing_gunbelt_accs.png',    ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Дополнение к патронташу'},
  ['clothing_holsters_left']      = {['name'] = 'clothing_holsters_left',     ['label'] = 'Кобура (левая)',       ['weight'] = 200,   ['type'] = 'item', ['image'] = 'clothing_holsters_left.png',   ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Левая кобура'},
  ['clothing_holsters_right']     = {['name'] = 'clothing_holsters_right',    ['label'] = 'Кобура (правая)',      ['weight'] = 200,   ['type'] = 'item', ['image'] = 'clothing_holsters_right.png',  ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Правая кобура'},
  ['clothing_holsters_crossdraw'] = {['name'] = 'clothing_holsters_crossdraw',['label'] = 'Кобура перекрёстная',  ['weight'] = 200,   ['type'] = 'item', ['image'] = 'clothing_holsters_crossdraw.png', ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Перекрёстная кобура'},
  -- ==========================================
  -- ОДЕЖДА - СУМКИ И СНАРЯЖЕНИЕ
  -- ==========================================
  ['clothing_satchels']           = {['name'] = 'clothing_satchels',          ['label'] = 'Сумка',                ['weight'] = 300,   ['type'] = 'item', ['image'] = 'clothing_satchels.png',        ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Наплечная сумка'},
  ['clothing_loadouts']           = {['name'] = 'clothing_loadouts',          ['label'] = 'Снаряжение',           ['weight'] = 500,   ['type'] = 'item', ['image'] = 'clothing_loadouts.png',        ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Комплект снаряжения'},
  ['clothing_armor']              = {['name'] = 'clothing_armor',             ['label'] = 'Броня',                ['weight'] = 1000,  ['type'] = 'item', ['image'] = 'clothing_armor.png',           ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Защитная броня'},
  ['clothing_talisman_wrist']     = {['name'] = 'clothing_talisman_wrist',    ['label'] = 'Талисман на запястье', ['weight'] = 50,    ['type'] = 'item', ['image'] = 'clothing_talisman_wrist.png',  ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Талисман'},
  ['clothing_talisman_belt']      = {['name'] = 'clothing_talisman_belt',     ['label'] = 'Талисман на поясе',    ['weight'] = 50,    ['type'] = 'item', ['image'] = 'clothing_talisman_belt.png',   ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Талисман на ремне'},
  ['clothing_talisman_satchel']   = {['name'] = 'clothing_talisman_satchel',  ['label'] = 'Талисман на сумке',    ['weight'] = 50,    ['type'] = 'item', ['image'] = 'clothing_talisman_satchel.png',['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Талисман на сумке'},
  
  -- ==========================================
  -- ОДЕЖДА - ЗНАЧКИ И УКРАШЕНИЯ
  -- ==========================================
  ['clothing_badges']             = {['name'] = 'clothing_badges',            ['label'] = 'Значок',               ['weight'] = 50,    ['type'] = 'item', ['image'] = 'clothing_badges.png',          ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Значок шерифа или маршала'},
  ['clothing_earrings']           = {['name'] = 'clothing_earrings',          ['label'] = 'Серьги',               ['weight'] = 20,    ['type'] = 'item', ['image'] = 'clothing_earrings.png',        ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Серьги'},
  ['clothing_accessories']        = {['name'] = 'clothing_accessories',       ['label'] = 'Аксессуар',            ['weight'] = 100,   ['type'] = 'item', ['image'] = 'clothing_accessories.png',     ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Декоративный аксессуар'},
  
  -- ==========================================
  -- ОДЕЖДА - СПЕЦИАЛЬНЫЕ (ЖЕНСКИЕ)
  -- ==========================================
  ['clothing_corsets']            = {['name'] = 'clothing_corsets',           ['label'] = 'Корсет',               ['weight'] = 300,   ['type'] = 'item', ['image'] = 'clothing_corsets.png',         ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Корсет'},
  ['clothing_blouses']            = {['name'] = 'clothing_blouses',           ['label'] = 'Блузка',               ['weight'] = 250,   ['type'] = 'item', ['image'] = 'clothing_blouses.png',         ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Женская блузка'},
  ['clothing_dresses']            = {['name'] = 'clothing_dresses',           ['label'] = 'Платье',               ['weight'] = 500,   ['type'] = 'item', ['image'] = 'clothing_dresses.png',         ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Платье'},
  
  -- ==========================================
  -- ОДЕЖДА - ДОПОЛНИТЕЛЬНЫЕ КАТЕГОРИИ RDO
  -- ==========================================
  ['clothing_aprons']             = {['name'] = 'clothing_aprons',            ['label'] = 'Фартук',               ['weight'] = 200,   ['type'] = 'item', ['image'] = 'clothing_aprons.png',          ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Рабочий фартук'},
  ['clothing_sarapes']            = {['name'] = 'clothing_sarapes',           ['label'] = 'Сарапе',               ['weight'] = 400,   ['type'] = 'item', ['image'] = 'clothing_sarapes.png',         ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Мексиканское покрывало'},
  ['clothing_brawler_arms']       = {['name'] = 'clothing_brawler_arms',      ['label'] = 'Бойцовские повязки',   ['weight'] = 100,   ['type'] = 'item', ['image'] = 'clothing_brawler_arms.png',    ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Повязки бойца'},
  ['clothing_sleeves']            = {['name'] = 'clothing_sleeves',           ['label'] = 'Нарукавники',          ['weight'] = 100,   ['type'] = 'item', ['image'] = 'clothing_sleeves.png',         ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Нарукавники'},
  ['clothing_cuffs']              = {['name'] = 'clothing_cuffs',             ['label'] = 'Манжеты',              ['weight'] = 50,    ['type'] = 'item', ['image'] = 'clothing_cuffs.png',           ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['description'] = 'Манжеты рубашки'},['wine']         = {['name'] = 'wine',         ['label'] = 'Вино',          ['weight'] = 750, ['type'] = 'item', ['image'] = 'wine.png',         ['unique'] = false, ['useable'] = true,  ['shouldClose'] = true, ['combinable'] = nil, ['level'] = 0, ['description'] = 'Бутылка красного вина'},

   ```
5. Restart your server and create a new character.

---

## 🧩 Configuration
Edit `config.lua` to adjust menu keybinds, storage options, or other parameters.  
The `/data` folder defines which clothes, hairstyles, and overlays are available.

---

## 💾 Example Server Events
```lua
-- Save full skin + clothing
TriggerServerEvent('rsg-appearance:server:SaveSkin', skinData, clothesData, true)

-- Save outfit only
TriggerServerEvent('rsg-appearance:server:saveOutfit', clothesData, isMale, outfitName)
```

---

## 🧠 Notes
- The script integrates deeply with **RSGCore** player data (`citizenid`, `money`, etc.).  
- Designed to be modular and expandable with new data sets.

---

## 💎 Credits
- Original resource created by: [QRCore-RedM-Re](https://github.com/QRCore-RedM-Re)  
- Modified and adapted for RSG Core by Rexshack Gaming  
- Contributors: community developers and testers  
- License: GPL‑3.0  

