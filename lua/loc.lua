_G.shuffle_play = _G.shuffle_play or {}
local mod_path = ModPath or (shuffle_play and shuffle_play.mod_path) or "mods/Shuffle Play/"
shuffle_play.mod_path = mod_path

local function load_loc_files(loc)
    loc = loc or (managers and managers.localization)
    if not loc then return end

    local lang = 1
    local save_path = SavePath or (shuffle_play and shuffle_play.save_path) or "mods/saves/"
    local save_file_path = save_path
    if not string.find(save_file_path, "shuffle_play%.json$") then
        save_file_path = save_path .. "shuffle_play.json"
    end

    local file = io.open(save_file_path, "r")
    if file then
        local content = file:read("*all")
        if content and content ~= "" then
            local ok, data = pcall(function() return json.decode(content) end)
            if ok and data and data.shuffle_play_language then
                lang = data.shuffle_play_language
            end
        end
        file:close()
    end

    local en_path = mod_path .. "loc/en.json"
    local es_path = mod_path .. "loc/es.json"
    local test_f = io.open(en_path, "r")
    if not test_f then
        en_path = "mods/Shuffle Play/loc/en.json"
        es_path = "mods/Shuffle Play/loc/es.json"
    else
        test_f:close()
    end

    loc:load_localization_file(en_path, false)
    if lang == 2 then
        loc:load_localization_file(es_path, true)
    end
end

Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInit_shuffle_play", function(loc)
    load_loc_files(loc)
end)

if managers and managers.localization then
    load_loc_files(managers.localization)
end
