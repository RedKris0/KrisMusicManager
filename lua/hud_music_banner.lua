if not KrisMusicHUD then
    KrisMusicHUD = KrisMusicHUD or class()

    local texture_path = "guis/textures/mods/Kmm/headphones"
    local ids_texture = Idstring("texture")
    local ids_headphones = Idstring(texture_path)

    local function ensure_headphones_texture()
        if DB and DB.create_entry and not DB:has(ids_texture, ids_headphones) then
            local mod_dir = ModPath or (shuffle_play and shuffle_play.mod_path) or "mods/Kris Music Manager/"
            local full_path = mod_dir .. "assets/" .. texture_path .. ".png"
            if SystemFS and SystemFS.exists and SystemFS:exists(full_path) then
                DB:create_entry(ids_texture, ids_headphones, full_path)
                log("[KrisMusicManager] Loaded headphones texture via DB:create_entry: " .. full_path)
            elseif io.file_is_readable and io.file_is_readable(full_path) then
                DB:create_entry(ids_texture, ids_headphones, full_path)
                log("[KrisMusicManager] Loaded headphones texture via io: " .. full_path)
            end
        end
    end
    ensure_headphones_texture()

    local function fix_corners(box)
        if not alive(box) then return end
        local lt = box:child("left_top")
        local lb = box:child("left_bottom")
        local rt = box:child("right_top")
        local rb = box:child("right_bottom")
        if alive(lt) then lt:set_left(0); lt:set_top(0) end
        if alive(lb) then lb:set_left(0); lb:set_bottom(box:h()) end
        if alive(rt) then rt:set_right(box:w()); rt:set_top(0) end
        if alive(rb) then rb:set_right(box:w()); rb:set_bottom(box:h()) end
    end

    local function set_box_color(box, color)
        if not alive(box) or not color then return end
        for _, child_name in ipairs({"left_top", "left_bottom", "right_top", "right_bottom", "left", "right", "top", "bottom"}) do
            local child = box:child(child_name)
            if alive(child) and child.set_color then
                child:set_color(color)
            end
        end
    end

    function KrisMusicHUD:init(hud)
        log("[KrisMusicManager] Initializing KrisMusicHUD...")
        ensure_headphones_texture()

        self._hud_panel = hud.panel

        self._bg_box_size = 300
        self._box_h = 38
        self._icon_box_size = 38
        self._icon_size = 24
        self._color = Color(1, 1, 1)
        
        local h = (shuffle_play and shuffle_play.save_data and shuffle_play.save_data.krismm_banner_hue) or 0
        local s = ((shuffle_play and shuffle_play.save_data and shuffle_play.save_data.krismm_banner_sat) or 0) / 100
        local r, g, b = shuffle_play.hsv_to_rgb(h, s, 1)
        self._color = Color(1, r, g, b)
        
        local total_w = self._icon_box_size + 4 + self._bg_box_size
        self._panel = self._hud_panel:panel({
            name = "kris_music_panel",
            w = total_w,
            h = self._box_h,
            valign = "top",
            visible = false,
            layer = 100
        })

        -- Icon box with its own matching HUD corners
        self._icon_box = HUDBGBox_create(self._panel, {
            w = self._icon_box_size,
            h = self._box_h,
            x = 0,
            y = 0
        }, {
            color = self._color,
            blend_mode = "add"
        })

        -- Headphone icon centered inside icon box
        self._icon = self._icon_box:bitmap({
            name = "icon",
            texture = texture_path,
            h = self._icon_size,
            w = self._icon_size,
            layer = 2,
            blend_mode = "add",
            color = self._color
        })
        self._icon:set_center(self._icon_box:w() / 2, self._icon_box:h() / 2)

        -- Text background box
        self._bg_box = HUDBGBox_create(self._panel, {
            w = self._bg_box_size,
            h = self._box_h,
            x = 0,
            y = 0
        }, {
            color = self._color,
            blend_mode = "add"
        })

        -- Inner panel for scrolling text (with padding from corners)
        self._bg_box:panel({
            name = "text_panel",
            w = self._bg_box_size - 16,
            h = self._box_h,
            x = 8,
            y = 0
        })

        fix_corners(self._icon_box)
        fix_corners(self._bg_box)

        self._active = false
        self._is_open = false
        self:update_position()
    end

    function KrisMusicHUD:hide()
        if alive(self._panel) then
            self._panel:set_visible(false)
        end
    end

    function KrisMusicHUD:show(text_list, override_color)
        if shuffle_play and shuffle_play.save_data and shuffle_play.save_data.krismm_show_banner_toggled == false then
            self:hide()
            return
        end

        local color = self._color
        if type(override_color) == "userdata" then
            color = override_color
            self._is_upcoming = true
        else
            self._is_upcoming = false
        end

        if type(color) ~= "userdata" then
            color = self._color or Color(1, 1, 1)
        end
        self._current_text_list = text_list
        self._current_color = color

        if alive(self._icon) then
            self._icon:set_color(color)
        end
        if alive(self._icon_box) then
            set_box_color(self._icon_box, color)
            fix_corners(self._icon_box)
        end
        if alive(self._bg_box) then
            set_box_color(self._bg_box, color)
            fix_corners(self._bg_box)
        end

        self._active = true
        if alive(self._panel) then
            self._panel:set_visible(true)
        end
        self:update_position()

        if not self._is_open then
            self._is_open = true

            local text_panel = self._bg_box:child("text_panel")
            if text_panel then
                text_panel:stop()
                text_panel:clear()
                text_panel:set_size(self._bg_box_size - 16, self._box_h)
                text_panel:set_x(8)
            else
                self._bg_box:panel({
                    name = "text_panel",
                    w = self._bg_box_size - 16,
                    h = self._box_h,
                    x = 8,
                    y = 0
                })
            end

            if alive(self._icon) then
                self._icon:stop()
                self._icon:animate(callback(self, self, "_show_icon"))
            end

            self._bg_box:stop()
            local align_right = (shuffle_play and shuffle_play.save_data and shuffle_play.save_data.krismm_banner_align == true)
            if align_right then
                self._bg_box:animate(callback(nil, _G, "HUDBGBox_animate_open_left"), 0.75, self._bg_box_size, function()
                    fix_corners(self._bg_box)
                end)
            else
                self._bg_box:animate(callback(nil, _G, "HUDBGBox_animate_open_right"), 0.75, self._bg_box_size, function()
                    fix_corners(self._bg_box)
                end)
            end

            local box_text_panel = self._bg_box:child("text_panel")
            if box_text_panel then
                box_text_panel:stop()
                box_text_panel:animate(callback(self, self, "_animate_text"))
            end
        else
            if alive(self._bg_box) and self._bg_box:child("text_panel") then
                self._force_text_refresh = true
            end
        end
    end

    function KrisMusicHUD:_show_icon(icon)
        local total_t = 2
        local t = total_t
        while t > 0 do
            local dt = coroutine.yield()
            t = t - dt
            local alpha = math.round(math.abs((math.sin(t * 360 * 3))))
            if alive(icon) then
                icon:set_alpha(alpha)
            end
        end
        if alive(icon) then
            icon:set_alpha(1)
        end
    end

    function KrisMusicHUD:_animate_text(text_panel)
        local texts = {}
        local current_string_idx = 1
        local uid = 1
        local padding = 10
        local speed = 90

        local function safe_upper(str)
            if not str or type(str) ~= "string" then return "" end
            if utf8 and utf8.to_upper then
                return utf8.to_upper(str)
            end
            return string.upper(str)
        end

        local function get_align_right()
            return (shuffle_play and shuffle_play.save_data and shuffle_play.save_data.krismm_banner_align == true)
        end

        local function create_new_text(tp, txt_table)
            local text_list = self._current_text_list or {""}
            local text_string = text_list[current_string_idx] or ""

            current_string_idx = current_string_idx % #text_list + 1
            local uppercase = (shuffle_play and shuffle_play.save_data and shuffle_play.save_data.krismm_banner_uppercase ~= false)
            if uppercase and text_string and text_string ~= "" then
                text_string = safe_upper(text_string)
            end

            local text = tp:text({
                vertical = "center",
                align = "center",
                blend_mode = "add",
                layer = 2,
                text = text_string,
                color = self._current_color,
                font_size = tweak_data.hud_corner.assault_size,
                font = tweak_data.hud_corner.assault_font
            })
            local _, _, w, h = text:text_rect()
            text:set_size(w, h)

            local align_right = get_align_right()
            local entry = {
                id = uid,
                x = align_right and (self._bg_box_size + w * 0.5 + padding * 2) or (-w * 0.5 - padding * 2),
                text = text,
                color = self._current_color
            }
            uid = uid + 1
            table.insert(txt_table, entry)
            return entry
        end

        while alive(text_panel) do
            local dt = coroutine.yield()
            local align_right = get_align_right()

            if self._force_text_refresh then
                self._force_text_refresh = false
                for i = #texts, 1, -1 do
                    if alive(texts[i].text) then
                        text_panel:remove(texts[i].text)
                    end
                end
                texts = {}
                current_string_idx = 1
            end

            local last_text = texts[#texts]
            if last_text and alive(last_text.text) then
                if align_right then
                    if last_text.x + last_text.text:w() * 0.5 + padding < self._bg_box_size then
                        create_new_text(text_panel, texts)
                    end
                else
                    if last_text.x - last_text.text:w() * 0.5 - padding > 0 then
                        create_new_text(text_panel, texts)
                    end
                end
            else
                create_new_text(text_panel, texts)
            end

            for i = #texts, 1, -1 do
                local data = texts[i]
                if alive(data.text) then
                    if data.color ~= self._current_color then
                        data.text:set_color(self._current_color)
                        data.color = self._current_color
                    end

                    if align_right then
                        data.x = data.x - dt * speed
                    else
                        data.x = data.x + dt * speed
                    end
                    data.text:set_center_x(data.x)
                    data.text:set_center_y(math.floor(text_panel:h() * 0.5))

                    if align_right then
                        if data.x + data.text:w() * 0.5 < 0 then
                            text_panel:remove(data.text)
                            table.remove(texts, i)
                        end
                    else
                        if data.x - data.text:w() * 0.5 > self._bg_box_size then
                            text_panel:remove(data.text)
                            table.remove(texts, i)
                        end
                    end
                end
            end
        end

        self._is_open = false
        self._active = false
    end

    function KrisMusicHUD:update_position()
        if not self._panel or not self._hud_panel then return end
        local x_offset = (shuffle_play and shuffle_play.save_data and shuffle_play.save_data.krismm_banner_x) or 0
        local y_offset = (shuffle_play and shuffle_play.save_data and shuffle_play.save_data.krismm_banner_y) or 0
        local align_right = (shuffle_play and shuffle_play.save_data and shuffle_play.save_data.krismm_banner_align == true)

        local parent_w = self._hud_panel:w()

        self._panel:set_top(220 + y_offset)

        if align_right then
            self._panel:set_right(parent_w + x_offset)
            self._icon_box:set_right(self._panel:w())
            self._icon_box:set_top(0)
            self._bg_box:set_right(self._icon_box:left() - 4)
            self._bg_box:set_top(0)
        else
            self._panel:set_left(x_offset)
            self._icon_box:set_left(0)
            self._icon_box:set_top(0)
            self._bg_box:set_left(self._icon_box:right() + 4)
            self._bg_box:set_top(0)
        end

        self._icon:set_center(self._icon_box:w() / 2, self._icon_box:h() / 2)
        fix_corners(self._icon_box)
        fix_corners(self._bg_box)

        self._force_text_refresh = true
    end

    function KrisMusicHUD:update_color()
        local h = (shuffle_play and shuffle_play.save_data and shuffle_play.save_data.krismm_banner_hue) or 0
        local s = ((shuffle_play and shuffle_play.save_data and shuffle_play.save_data.krismm_banner_sat) or 0) / 100
        local r, g, b = shuffle_play.hsv_to_rgb(h, s, 1)
        local new_color = Color(1, r, g, b)

        self._color = new_color
        if not self._is_upcoming then
            self._current_color = new_color

            if alive(self._icon) then
                self._icon:set_color(new_color)
            end
            if alive(self._icon_box) then
                set_box_color(self._icon_box, new_color)
                fix_corners(self._icon_box)
            end
            if alive(self._bg_box) then
                set_box_color(self._bg_box, new_color)
                fix_corners(self._bg_box)
            end
        end
    end
end

Hooks:PostHook(HUDManager, "_setup_player_info_hud_pd2", "KrisMusicHUD_setup", function(self)
    log("[KrisMusicManager] Hook: setup_player_info_hud_pd2 triggered.")
    local hud = managers.hud:script(PlayerBase.PLAYER_INFO_HUD_PD2)
    if hud then
        log("[KrisMusicManager] Found HUD script, creating KrisMusicHUD.")
        self._kris_music_hud = KrisMusicHUD:new(hud)

        -- If a banner was requested before HUD was ready, show it now
        if self._cached_music_banner then
            self:show_kris_music_banner(self._cached_music_banner.text_list, self._cached_music_banner.color)
            self._cached_music_banner = nil
        else
            local cur_track = (shuffle_play and shuffle_play.prep_fixed_track) or (shuffle_play and shuffle_play.get_current_track and shuffle_play.get_current_track()) or (Global.music_manager and Global.music_manager.current_track)
            if cur_track and shuffle_play and shuffle_play.get_track_name then
                local track_name = shuffle_play.get_track_name(cur_track)
                if track_name and track_name ~= "" then
                    local text = managers.localization:text("krismm_now_playing", {track = track_name})
                    self:show_kris_music_banner({text})
                end
            end
        end
    else
        log("[KrisMusicManager] Error: Could not find hud script for PLAYER_INFO_HUD_PD2.")
    end

    if shuffle_play then
        shuffle_play.heist_started = nil
        shuffle_play.wave_counter = 0
        shuffle_play._upcoming_banner_shown = nil
        shuffle_play.last_stage = nil
        if not shuffle_play.next_track then
            shuffle_play.prepare_next_track()
        end
    end
end)

function HUDManager:show_kris_music_banner(text_list, arg2, arg3)
    local color = nil
    if type(arg2) == "userdata" then
        color = arg2
    elseif type(arg3) == "userdata" then
        color = arg3
    end

    if not self._kris_music_hud then
        self._cached_music_banner = { text_list = text_list, color = color }
        return
    end

    if shuffle_play and shuffle_play.save_data and shuffle_play.save_data.krismm_show_banner_toggled == false then
        self._kris_music_hud:hide()
        return
    end

    self._kris_music_hud:show(text_list, color)
end

Hooks:PostHook(HUDManager, "update", "KrisMM_HUDManager_update_assault", function(self, t, dt)
    if shuffle_play and shuffle_play.check_assault_timing then
        if not shuffle_play._next_hud_check_t or t > shuffle_play._next_hud_check_t then
            shuffle_play._next_hud_check_t = t + 0.25
            shuffle_play.check_assault_timing(t)
        end
    end
end)