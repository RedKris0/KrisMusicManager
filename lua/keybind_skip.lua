if not _G.shuffle_play then return end

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
    shuffle_play.set_random_track()
end
