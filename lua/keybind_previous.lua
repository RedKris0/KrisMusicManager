if not _G.shuffle_play then return end

if not shuffle_play._last_prev_time then
    shuffle_play._last_prev_time = 0
end

local t = TimerManager:wall():time()
if t - shuffle_play._last_prev_time < 0.6 then
    return
end
shuffle_play._last_prev_time = t

if managers.music and shuffle_play.play_previous_track then
    shuffle_play.play_previous_track()
end
