_G.shuffle_play = _G.shuffle_play or {}

if GroupAIStateBesiege then
    Hooks:PostHook(GroupAIStateBesiege, "_upd_assault_task", "KrisMM_GroupAI_upd_assault_task", function(self, t)
        if shuffle_play and shuffle_play.check_assault_timing then
            shuffle_play.check_assault_timing(t)
        end
    end)
end
