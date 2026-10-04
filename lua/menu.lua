_G.shuffle_play = _G.shuffle_play or {}
shuffle_play.mod_path = ModPath
shuffle_play.save_path = SavePath .. "shuffle_play.json"

function shuffle_play:save()
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

Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInit_shuffle_play", function(loc)
    local lang = 1
    local file = io.open(shuffle_play.save_path, "r")
    if file then
        local content = file:read("*all")
        if content and content ~= "" then
            local data = json.decode(content)
            if data and data.shuffle_play_language then
                lang = data.shuffle_play_language
            end
        end
        file:close()
    end

    loc:load_localization_file(shuffle_play.mod_path .. "loc/en.json")
    
    if lang == 2 then
        loc:load_localization_file(shuffle_play.mod_path .. "loc/es.json")
    end
end)

function MenuCallbackHandler:shuffle_play_track_callback(item)
    local save_key = shuffle_play.track_menu_save_keys[item:name()]
    if save_key then
        shuffle_play.save_data[save_key] = item:value() == "on"
        shuffle_play:save()
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
        
        local track_name = track_id
        if tweak_data.music[track_id] and tweak_data.music[track_id].name_id then
            track_name = managers.localization:text(tweak_data.music[track_id].name_id)
        end
        
        local msg = managers.localization:text("krismm_queued_msg") .. track_name
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

Hooks:Add("MenuManagerInitialize", "MenuManagerInitialize_shuffle_play", function(menu_manager)
	shuffle_play:load()
    
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
    MenuHelper:AddToggle({ id="shuffle_play_no_repeat", title="shuffle_play_no_repeat_title", desc="shuffle_play_no_repeat_desc", callback="shuffle_play_no_repeat_callback", value=shuffle_play.save_data.shuffle_play_no_repeat_toggled, menu_id="shuffle_play_menu", localized=true, priority=999 })
    MenuHelper:AddMultipleChoice({ id="shuffle_play_language", title="shuffle_play_language_title", desc="shuffle_play_language_desc", callback="shuffle_play_language_callback", items={"shuffle_play_lang_en", "shuffle_play_lang_es"}, value=shuffle_play.save_data.shuffle_play_language or 1, menu_id="krismm_main_menu", localized=true, priority=998 })
    MenuHelper:AddMultipleChoice({ id="shuffle_play_frequency", title="shuffle_play_frequency_title", desc="shuffle_play_frequency_desc", callback="shuffle_play_frequency_callback", items={"shuffle_play_freq_1", "shuffle_play_freq_2", "shuffle_play_freq_3", "shuffle_play_freq_4", "shuffle_play_freq_5", "shuffle_play_freq_6", "shuffle_play_freq_7", "shuffle_play_freq_8", "shuffle_play_freq_9", "shuffle_play_freq_10"}, value=shuffle_play.save_data.shuffle_play_frequency or 1, menu_id="shuffle_play_menu", localized=true, priority=997 })
    MenuHelper:AddButton({ id="shuffle_play_menu_tracks_base_btn", title="shuffle_play_menu_tracks_base_title", desc="shuffle_play_menu_tracks_base_desc", next_node="shuffle_play_menu_tracks_base", menu_id="shuffle_play_menu", localized=true, priority=996 })
    MenuHelper:AddButton({ id="shuffle_play_menu_tracks_custom_btn", title="shuffle_play_menu_tracks_custom_title", desc="shuffle_play_menu_tracks_custom_desc", next_node="shuffle_play_menu_tracks_custom", menu_id="shuffle_play_menu", localized=true, priority=995 })

    -- Populate Queue Menu
    MenuHelper:AddButton({ id="krismm_queue_base_btn", title="shuffle_play_menu_tracks_base_title", desc="shuffle_play_menu_tracks_base_desc", next_node="krismm_queue_tracks_base", menu_id="krismm_queue_menu", localized=true, priority=2 })
    MenuHelper:AddButton({ id="krismm_queue_custom_btn", title="shuffle_play_menu_tracks_custom_title", desc="shuffle_play_menu_tracks_custom_desc", next_node="krismm_queue_tracks_custom", menu_id="krismm_queue_menu", localized=true, priority=1 })

    -- Bulk action buttons for Shuffle
    MenuHelper:AddButton({ id="shuffle_play_enable_all_base", title="shuffle_play_enable_all_title", desc="shuffle_play_enable_all_desc", callback="shuffle_play_toggle_all", menu_id="shuffle_play_menu_tracks_base", localized=true, priority=2000 })
    MenuHelper:AddButton({ id="shuffle_play_disable_all_base", title="shuffle_play_disable_all_title", desc="shuffle_play_disable_all_desc", callback="shuffle_play_toggle_all", menu_id="shuffle_play_menu_tracks_base", localized=true, priority=1999 })
    MenuHelper:AddButton({ id="shuffle_play_enable_all_custom", title="shuffle_play_enable_all_title", desc="shuffle_play_enable_all_desc", callback="shuffle_play_toggle_all", menu_id="shuffle_play_menu_tracks_custom", localized=true, priority=2000 })
    MenuHelper:AddButton({ id="shuffle_play_disable_all_custom", title="shuffle_play_disable_all_title", desc="shuffle_play_disable_all_desc", callback="shuffle_play_toggle_all", menu_id="shuffle_play_menu_tracks_custom", localized=true, priority=1999 })

    for i, track in ipairs(tracks) do
        local is_custom = false
        if CustomOST and CustomOST.track_manager and CustomOST.track_manager:get_track(track) then is_custom = true end
        if tweak_data.music[track] and tweak_data.music[track].is_custom then is_custom = true end
        if BeardLib and BeardLib.MusicMods and BeardLib.MusicMods[track] then is_custom = true end

        local target_shuffle_menu = is_custom and "shuffle_play_menu_tracks_custom" or "shuffle_play_menu_tracks_base"
        local target_queue_menu = is_custom and "krismm_queue_tracks_custom" or "krismm_queue_tracks_base"
        
        local item_id = "shuffle_play_track_" .. track
        local save_key = item_id .. "_toggled"
        shuffle_play.track_menu_save_keys[item_id] = save_key

        local title_id = "menu_jukebox_" .. track
        if tweak_data.music[track] and tweak_data.music[track].name_id then
            title_id = tweak_data.music[track].name_id
        end
        
        if shuffle_play.save_data[save_key] == nil then
            shuffle_play.save_data[save_key] = true
        end

        -- Toggle for Shuffle Play
        MenuHelper:AddToggle({
            id = item_id,
            title = title_id,
            desc = "shuffle_play_track_desc",
            callback = "shuffle_play_track_callback",
            value = shuffle_play.save_data[save_key],
            menu_id = target_shuffle_menu,
            localized = true,
            priority = 900 - i
        })
        
        -- Button for Queue
        MenuHelper:AddButton({
            id = "krismm_queue_track_" .. track,
            title = title_id,
            desc = "krismm_queue_track_desc",
            callback = "krismm_queue_track_callback",
            menu_id = target_queue_menu,
            localized = true,
            priority = 900 - i,
            track_id = track
        })
    end
end)

Hooks:Add("MenuManagerBuildCustomMenus", "MenuManagerBuildCustomMenus_shuffle_play_tracks", function(menu_manager, nodes)
    nodes["shuffle_play_menu"] = MenuHelper:BuildMenu("shuffle_play_menu")
    nodes["shuffle_play_menu_tracks_base"] = MenuHelper:BuildMenu("shuffle_play_menu_tracks_base")
    nodes["shuffle_play_menu_tracks_custom"] = MenuHelper:BuildMenu("shuffle_play_menu_tracks_custom")
    nodes["krismm_queue_menu"] = MenuHelper:BuildMenu("krismm_queue_menu")
    nodes["krismm_queue_tracks_base"] = MenuHelper:BuildMenu("krismm_queue_tracks_base")
    nodes["krismm_queue_tracks_custom"] = MenuHelper:BuildMenu("krismm_queue_tracks_custom")
end)







