_G.shuffle_play = _G.shuffle_play or {}
shuffle_play.mod_path = ModPath
shuffle_play.save_path = SavePath .. "shuffle_play.json"

function shuffle_play:save(force)
    local t = os.clock()
    if not force and self._last_save and (t - self._last_save < 0.5) then
        self._save_pending = true
        return
    end
    self._last_save = t
    self._save_pending = false

	local file = io.open(shuffle_play.save_path, "w+")
	if file then
		file:write(json.encode(shuffle_play.save_data or {}))
		file:close()
	end
    
    if shuffle_play.prepare_next_track then
        shuffle_play.next_track = nil
        shuffle_play.prepare_next_track()
    end
end

function shuffle_play:load()
	local file = io.open(shuffle_play.save_path, "r")
	if file then
        local content = file:read("*all")
        if content and content ~= "" then
		    shuffle_play.save_data = json.decode(content)
        end
		file:close()
    end
    shuffle_play.save_data = shuffle_play.save_data or {}
end

function shuffle_play.get_track_name(track_id)
    local title_id = "menu_jukebox_" .. track_id
    if tweak_data.music[track_id] and tweak_data.music[track_id].name_id then
        title_id = tweak_data.music[track_id].name_id
    end
    local track_name = managers.localization:text(title_id)
    if track_name:find("ERROR:") then
        track_name = track_id
    end
    return track_name
end

local function load_shuffle_play_localization(loc)
    loc = loc or (managers and managers.localization)
    if not loc then return end

    local lang = (shuffle_play.save_data and shuffle_play.save_data.shuffle_play_language) or 1
    if not shuffle_play.save_data or not shuffle_play.save_data.shuffle_play_language then
        local file = io.open(shuffle_play.save_path, "r")
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
    end

    local mod_path = shuffle_play.mod_path or ModPath or "mods/Shuffle Play/"
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
    load_shuffle_play_localization(loc)
end)

if managers and managers.localization then
    load_shuffle_play_localization(managers.localization)
end

function MenuCallbackHandler:shuffle_play_track_callback(item)
    local save_key = shuffle_play.track_menu_save_keys[item:name()]
    if save_key then
        shuffle_play.save_data[save_key] = item:value() == "on"
        shuffle_play:save()
    end
end

function MenuCallbackHandler:krismm_show_banner_callback(item)
    shuffle_play.save_data.krismm_show_banner_toggled = item:value() == "on"
    shuffle_play:save()
end

function MenuCallbackHandler:krismm_banner_align_callback(item)
    shuffle_play.save_data.krismm_banner_align = item:value() == "on"
    shuffle_play:save()
    if managers.hud and managers.hud._kris_music_hud then
        managers.hud._kris_music_hud:update_position()
    end
end

function MenuCallbackHandler:krismm_banner_x_callback(item)
    shuffle_play.save_data.krismm_banner_x = item:value()
    shuffle_play:save()
    if managers.hud and managers.hud._kris_music_hud then
        managers.hud._kris_music_hud:update_position()
    end
end

function MenuCallbackHandler:krismm_banner_y_callback(item)
    shuffle_play.save_data.krismm_banner_y = item:value()
    shuffle_play:save()
    if managers.hud and managers.hud._kris_music_hud then
        managers.hud._kris_music_hud:update_position()
    end
end

function MenuCallbackHandler:krismm_reset_x_callback(item)
    shuffle_play.save_data.krismm_banner_x = 0
    shuffle_play:save()
    local menu = managers.menu:active_menu()
    if menu and menu.logic then
        local node = menu.logic:get_node("krismm_hud_menu")
        if node then
            local slider = node:item("krismm_banner_x")
            if slider then
                slider:set_value(0)
            end
        end
    end
    if managers.hud and managers.hud._kris_music_hud then
        managers.hud._kris_music_hud:update_position()
    end
end

function MenuCallbackHandler:krismm_reset_y_callback(item)
    shuffle_play.save_data.krismm_banner_y = 0
    shuffle_play:save()
    local menu = managers.menu:active_menu()
    if menu and menu.logic then
        local node = menu.logic:get_node("krismm_hud_menu")
        if node then
            local slider = node:item("krismm_banner_y")
            if slider then
                slider:set_value(0)
            end
        end
    end
    if managers.hud and managers.hud._kris_music_hud then
        managers.hud._kris_music_hud:update_position()
    end
end

function MenuCallbackHandler:krismm_banner_hue_callback(item)
    shuffle_play.save_data.krismm_banner_hue = item:value()
    shuffle_play:save()
    if managers.hud and managers.hud._kris_music_hud then
        managers.hud._kris_music_hud:update_color()
    end
end

function MenuCallbackHandler:krismm_banner_sat_callback(item)
    shuffle_play.save_data.krismm_banner_sat = item:value()
    shuffle_play:save()
    if managers.hud and managers.hud._kris_music_hud then
        managers.hud._kris_music_hud:update_color()
    end
end

function MenuCallbackHandler:shuffle_play_toggle_all(item)
    local enable = item:name():find("enable") ~= nil
    local is_custom = item:name():find("custom") ~= nil
    local menu_id = is_custom and "shuffle_play_menu_tracks_custom" or "shuffle_play_menu_tracks_base"
    
    local menu = managers.menu:active_menu()
    if not menu or not menu.logic then return end
    
    local node = menu.logic:get_node(menu_id)
    if not node then return end
    
    for _, track_item in ipairs(node:items()) do
        if track_item:type() == "toggle" then
            track_item:set_value(enable and "on" or "off")
            local save_key = shuffle_play.track_menu_save_keys[track_item:name()]
            if save_key then
                shuffle_play.save_data[save_key] = enable
            end
        end
    end
    shuffle_play:save()
    
    if menu.renderer and menu.renderer.refresh_node then
        menu.renderer:refresh_node(node)
    end
end

function MenuCallbackHandler:krismm_queue_track_callback(item)
    local item_name = item:name()
    local track_id = nil
    if string.sub(item_name, 1, 19) == "krismm_queue_track_" then
        track_id = string.sub(item_name, 20)
    end
    if track_id then
        table.insert(shuffle_play.queue, track_id)
        
        local track_name = shuffle_play.get_track_name(track_id)
        
        local msg = managers.localization:text("krismm_queued_msg") .. track_name
        managers.chat:_receive_message(1, "KrisMusicManager", msg, tweak_data.system_chat_color)
        
        if managers.hud and managers.hud.show_kris_music_banner then
            local text_list = {
                managers.localization:to_upper_text("krismm_upcoming_song", {track = track_name})
            }
            managers.hud:show_kris_music_banner(text_list, 10, Color(1, 0.8, 0.2))
        end
        if managers.hud then
            managers.hud:show_hint({text = msg, time = 3})
        elseif BLT and BLT.Notifications then
            BLT.Notifications:add_notification({ title = "KrisMusicManager", text = msg, priority = 1000 })
        end
        if managers.menu_component then
            managers.menu_component:post_event("menu_enter")
        end
        
        if not shuffle_play.next_track or not shuffle_play.next_track_is_queued then
            shuffle_play.prepare_next_track()
        end
    end
end

function MenuCallbackHandler:krismm_skip_track_callback(item)
    if not shuffle_play._last_skip_time then
        shuffle_play._last_skip_time = 0
    end
    
    local t = TimerManager:wall():time()
    if t - shuffle_play._last_skip_time < 0.6 then
        return
    end
    shuffle_play._last_skip_time = t

    if managers.music then
        if managers.hud then
            managers.hud:show_hint({text = managers.localization:text("krismm_skip_track_title"), time = 2})
        end
        if managers.menu_component then
            managers.menu_component:post_event("menu_enter")
        end
        shuffle_play.set_random_track()
    end
end

Hooks:Add("MenuManagerInitialize", "MenuManagerInitialize_shuffle_play", function(menu_manager)
	shuffle_play:load()
    if managers and managers.localization then
        load_shuffle_play_localization(managers.localization)
    end
    
	MenuHelper:LoadFromJsonFile(shuffle_play.mod_path .. "menu/" .. "menu.json", shuffle_play, shuffle_play.save_data)

	MenuCallbackHandler.shuffle_play_language_callback = function(self, item)
		shuffle_play.save_data.shuffle_play_language = tonumber(item:value())
		shuffle_play:save()
	end

	MenuCallbackHandler.shuffle_play_no_repeat_callback = function(self, item)
		shuffle_play.save_data.shuffle_play_no_repeat_toggled = (item:value() == "on")
		shuffle_play:save()
	end

	MenuCallbackHandler.shuffle_play_enable_callback = function(self, item)
		shuffle_play.save_data.shuffle_play_enable_toggled = (item:value() == "on" and true or false)
		shuffle_play:save()
	end

	MenuCallbackHandler.shuffle_play_frequency_callback = function(self, item)
		shuffle_play.save_data.shuffle_play_frequency = item:value()
		shuffle_play:save()
	end
end)

Hooks:Add("MenuManagerSetupCustomMenus", "MenuManagerSetupCustomMenus_shuffle_play_tracks", function(menu_manager, nodes)
    MenuHelper:NewMenu("shuffle_play_menu")
    MenuHelper:NewMenu("shuffle_play_menu_tracks_base")
    MenuHelper:NewMenu("shuffle_play_menu_tracks_custom")
    MenuHelper:NewMenu("krismm_queue_menu")
    MenuHelper:NewMenu("krismm_queue_tracks_base")
    MenuHelper:NewMenu("krismm_queue_tracks_custom")
    MenuHelper:NewMenu("krismm_hud_menu")
end)

Hooks:Add("MenuManagerPopulateCustomMenus", "MenuManagerPopulateCustomMenus_shuffle_play_dynamic", function(menu_manager, nodes)
    local tracks = shuffle_play.get_loaded_tracks()
    log("[KrisMM] Loaded tracks count: " .. tostring(#tracks))
    if #tracks == 0 then
        if tweak_data and tweak_data.music and tweak_data.music.track_list then
            log("[KrisMM] track_list size: " .. tostring(#tweak_data.music.track_list))
        else
            log("[KrisMM] tweak_data.music.track_list is missing!")
        end
    end

    -- Populate Shuffle Play Menu
    MenuHelper:AddToggle({ id="shuffle_play_enable", title="shuffle_play_enable_title", desc="shuffle_play_enable_desc", callback="shuffle_play_enable_callback", value=shuffle_play.save_data.shuffle_play_enable_toggled, menu_id="shuffle_play_menu", localized=true, priority=1000 })
    MenuHelper:AddToggle({ id="shuffle_play_no_repeat", title="shuffle_play_no_repeat_title", desc="shuffle_play_no_repeat_desc", callback="shuffle_play_no_repeat_callback", value=shuffle_play.save_data.shuffle_play_no_repeat_toggled, menu_id="shuffle_play_menu", localized=true, priority=998 })
    MenuHelper:AddMultipleChoice({ id="shuffle_play_language", title="shuffle_play_language_title", desc="shuffle_play_language_desc", callback="shuffle_play_language_callback", items={"shuffle_play_lang_en", "shuffle_play_lang_es"}, value=shuffle_play.save_data.shuffle_play_language or 1, menu_id="krismm_main_menu", localized=true, priority=997 })
    MenuHelper:AddMultipleChoice({ id="shuffle_play_frequency", title="shuffle_play_frequency_title", desc="shuffle_play_frequency_desc", callback="shuffle_play_frequency_callback", items={"shuffle_play_freq_1", "shuffle_play_freq_2", "shuffle_play_freq_3", "shuffle_play_freq_4", "shuffle_play_freq_5", "shuffle_play_freq_6", "shuffle_play_freq_7", "shuffle_play_freq_8", "shuffle_play_freq_9", "shuffle_play_freq_10"}, value=shuffle_play.save_data.shuffle_play_frequency or 1, menu_id="shuffle_play_menu", localized=true, priority=997 })
    
    -- Populate HUD Menu
    MenuHelper:AddToggle({ id="krismm_show_banner", title="krismm_show_banner_title", desc="krismm_show_banner_desc", callback="krismm_show_banner_callback", value=(shuffle_play.save_data.krismm_show_banner_toggled ~= false), menu_id="krismm_hud_menu", localized=true, priority=1000 })
    
    MenuHelper:AddToggle({ id="krismm_banner_align", title="krismm_banner_align_title", desc="krismm_banner_align_desc", callback="krismm_banner_align_callback", value=(shuffle_play.save_data.krismm_banner_align == true), menu_id="krismm_hud_menu", localized=true, priority=999 })
    
    MenuHelper:AddSlider({ id="krismm_banner_hue", title="krismm_banner_hue_title", desc="krismm_banner_hue_desc", callback="krismm_banner_hue_callback", value=shuffle_play.save_data.krismm_banner_hue or 0, min=0, max=360, step=1, show_value=true, menu_id="krismm_hud_menu", localized=true, priority=998 })
    MenuHelper:AddSlider({ id="krismm_banner_sat", title="krismm_banner_sat_title", desc="krismm_banner_sat_desc", callback="krismm_banner_sat_callback", value=shuffle_play.save_data.krismm_banner_sat or 0, min=0, max=100, step=1, show_value=true, menu_id="krismm_hud_menu", localized=true, priority=998 })

    MenuHelper:AddSlider({ id="krismm_banner_x", title="krismm_banner_x_title", desc="krismm_banner_x_desc", callback="krismm_banner_x_callback", value=shuffle_play.save_data.krismm_banner_x or 0, min=-1000, max=1000, step=5, show_value=true, menu_id="krismm_hud_menu", localized=true, priority=996 })
    MenuHelper:AddButton({ id="krismm_reset_x", title="krismm_reset_x_title", desc="krismm_reset_x_desc", callback="krismm_reset_x_callback", menu_id="krismm_hud_menu", localized=true, priority=995 })
    MenuHelper:AddSlider({ id="krismm_banner_y", title="krismm_banner_y_title", desc="krismm_banner_y_desc", callback="krismm_banner_y_callback", value=shuffle_play.save_data.krismm_banner_y or 0, min=-1000, max=1000, step=5, show_value=true, menu_id="krismm_hud_menu", localized=true, priority=994 })
    MenuHelper:AddButton({ id="krismm_reset_y", title="krismm_reset_y_title", desc="krismm_reset_y_desc", callback="krismm_reset_y_callback", menu_id="krismm_hud_menu", localized=true, priority=993 })
    
    MenuHelper:AddButton({ id="shuffle_play_menu_tracks_base_btn", title="shuffle_play_menu_tracks_base_title", desc="shuffle_play_menu_tracks_base_desc", next_node="shuffle_play_menu_tracks_base", menu_id="shuffle_play_menu", localized=true, priority=994 })
    MenuHelper:AddButton({ id="shuffle_play_menu_tracks_custom_btn", title="shuffle_play_menu_tracks_custom_title", desc="shuffle_play_menu_tracks_custom_desc", next_node="shuffle_play_menu_tracks_custom", menu_id="shuffle_play_menu", localized=true, priority=993 })

    -- Populate Queue Menu
    MenuHelper:AddButton({ id="krismm_skip_track", title="krismm_skip_track_title", desc="krismm_skip_track_desc", callback="krismm_skip_track_callback", menu_id="krismm_queue_menu", localized=true, priority=3 })
    MenuHelper:AddButton({ id="krismm_queue_base_btn", title="shuffle_play_menu_tracks_base_title", desc="shuffle_play_menu_tracks_base_desc", next_node="krismm_queue_tracks_base", menu_id="krismm_queue_menu", localized=true, priority=2 })
    MenuHelper:AddButton({ id="krismm_queue_custom_btn", title="shuffle_play_menu_tracks_custom_title", desc="shuffle_play_menu_tracks_custom_desc", next_node="krismm_queue_tracks_custom", menu_id="krismm_queue_menu", localized=true, priority=1 })

    -- Bulk action buttons for Shuffle
    MenuHelper:AddButton({ id="shuffle_play_enable_all_base", title="shuffle_play_enable_all_title", desc="shuffle_play_enable_all_desc", callback="shuffle_play_toggle_all", menu_id="shuffle_play_menu_tracks_base", localized=true, priority=2000 })
    MenuHelper:AddButton({ id="shuffle_play_disable_all_base", title="shuffle_play_disable_all_title", desc="shuffle_play_disable_all_desc", callback="shuffle_play_toggle_all", menu_id="shuffle_play_menu_tracks_base", localized=true, priority=1999 })
    MenuHelper:AddButton({ id="shuffle_play_enable_all_custom", title="shuffle_play_enable_all_title", desc="shuffle_play_enable_all_desc", callback="shuffle_play_toggle_all", menu_id="shuffle_play_menu_tracks_custom", localized=true, priority=2000 })
    MenuHelper:AddButton({ id="shuffle_play_disable_all_custom", title="shuffle_play_disable_all_title", desc="shuffle_play_disable_all_desc", callback="shuffle_play_toggle_all", menu_id="shuffle_play_menu_tracks_custom", localized=true, priority=1999 })

    for i, track in ipairs(tracks) do
        if not shuffle_play.is_track_playable or shuffle_play.is_track_playable(track) then
            local is_custom = false
            if CustomOST and CustomOST.track_manager and CustomOST.track_manager:get_track(track) then is_custom = true end
            if tweak_data.music[track] and tweak_data.music[track].is_custom then is_custom = true end
            if BeardLib and BeardLib.MusicMods and BeardLib.MusicMods[track] then is_custom = true end

        local target_shuffle_menu = is_custom and "shuffle_play_menu_tracks_custom" or "shuffle_play_menu_tracks_base"
        local target_queue_menu = is_custom and "krismm_queue_tracks_custom" or "krismm_queue_tracks_base"
        
        local item_id = "shuffle_play_track_" .. track
        local save_key = item_id .. "_toggled"
        shuffle_play.track_menu_save_keys[item_id] = save_key

        local title_text = shuffle_play.get_track_name(track)
        local desc_text_shuffle = managers.localization:text("shuffle_play_track_desc")
        local desc_text_queue = managers.localization:text("krismm_queue_track_desc")
        
        if shuffle_play.save_data[save_key] == nil then
            shuffle_play.save_data[save_key] = true
        end

        -- Toggle for Shuffle Play
        MenuHelper:AddToggle({
            id = item_id,
            title = title_text,
            desc = desc_text_shuffle,
            callback = "shuffle_play_track_callback",
            value = shuffle_play.save_data[save_key],
            menu_id = target_shuffle_menu,
            localized = false,
            priority = 900 - i
        })
        
        -- Button for Queue
        MenuHelper:AddButton({
            id = "krismm_queue_track_" .. track,
            title = title_text,
            desc = desc_text_queue,
            callback = "krismm_queue_track_callback",
            menu_id = target_queue_menu,
            localized = false,
            priority = 900 - i,
            track_id = track
        })
        end
    end
end)

Hooks:Add("MenuManagerBuildCustomMenus", "MenuManagerBuildCustomMenus_shuffle_play_tracks", function(menu_manager, nodes)
    nodes["shuffle_play_menu"] = MenuHelper:BuildMenu("shuffle_play_menu")
    nodes["shuffle_play_menu_tracks_base"] = MenuHelper:BuildMenu("shuffle_play_menu_tracks_base")
    nodes["shuffle_play_menu_tracks_custom"] = MenuHelper:BuildMenu("shuffle_play_menu_tracks_custom")
    nodes["krismm_queue_menu"] = MenuHelper:BuildMenu("krismm_queue_menu")
    nodes["krismm_queue_tracks_base"] = MenuHelper:BuildMenu("krismm_queue_tracks_base")
    nodes["krismm_queue_tracks_custom"] = MenuHelper:BuildMenu("krismm_queue_tracks_custom")
    
    local hud_menu = MenuHelper:BuildMenu("krismm_hud_menu")
    hud_menu:parameters().hide_bg = true
    nodes["krismm_hud_menu"] = hud_menu
end)

Hooks:Add("MenuUpdate", "MenuUpdate_shuffle_play_save", function(t, dt)
    if shuffle_play._save_pending and shuffle_play._last_save and (os.clock() - shuffle_play._last_save > 0.6) then
        shuffle_play:save(true)
    end
end)








