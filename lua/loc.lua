_G.shuffle_play = _G.shuffle_play or {}
local mod_path = ModPath or (shuffle_play and shuffle_play.mod_path) or "mods/Kris Music Manager/"
if not string.find(mod_path, "[/\\]$") then
    mod_path = mod_path .. "/"
end
shuffle_play.mod_path = mod_path

local function load_loc_files(loc)
    loc = loc or (managers and managers.localization)
    if not loc then return end

    local lang = (shuffle_play.save_data and shuffle_play.save_data.shuffle_play_language)
    if not lang then
        local save_path = SavePath or (shuffle_play and shuffle_play.save_path) or "mods/saves/"
        local save_file_path = save_path
        if not string.find(save_file_path, "shuffle_play%.json$") then
            if not string.find(save_file_path, "[/\\]$") then
                save_file_path = save_file_path .. "/"
            end
            save_file_path = save_file_path .. "shuffle_play.json"
        end

        local file = io.open(save_file_path, "r")
        if file then
            local content = file:read("*all")
            file:close()
            if content and content ~= "" then
                if string.find(content, '"shuffle_play_language"%s*:%s*2') then
                    lang = 2
                elseif string.find(content, '"shuffle_play_language"%s*:%s*1') then
                    lang = 1
                elseif type(json) == "table" and json.decode then
                    local ok, data = pcall(function() return json.decode(content) end)
                    if ok and data and data.shuffle_play_language then
                        lang = tonumber(data.shuffle_play_language)
                    end
                end
            end
        end
    end

    if not lang or lang == 0 then
        if SystemInfo and SystemInfo.language then
            local sys_lang = SystemInfo:language()
            if sys_lang == Idstring("spanish") or sys_lang == Idstring("es") then
                lang = 2
            else
                lang = 1
            end
        else
            lang = 1
        end
    end

    local en_path = mod_path .. "loc/en.json"
    local es_path = mod_path .. "loc/es.json"
    local test_f = io.open(en_path, "r")
    if not test_f then
        en_path = "mods/Kris Music Manager/loc/en.json"
        es_path = "mods/Kris Music Manager/loc/es.json"
    else
        test_f:close()
    end

    if lang == 2 then
        loc:load_localization_file(en_path, false)
        loc:load_localization_file(es_path, true)
    else
        loc:load_localization_file(es_path, false)
        loc:load_localization_file(en_path, true)
    end
end

shuffle_play.load_localization = load_loc_files

Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInit_shuffle_play", function(loc)
    load_loc_files(loc)
end)

if managers and managers.localization then
    load_loc_files(managers.localization)
end