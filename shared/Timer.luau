local Timer = {}
Timer.__index = Timer

function Timer.new(timer_time: number, bindToFinish)
    local self = setmetatable(Timer, {})
    self.remaining_time = timer_time

    function Timer.start()
        coroutine.wrap(function()
            while task.wait(1) do
                self.remaining_time -= 1
                if self.remaining_time <= 0 then
                    break
                end
            end
            
            print("Timer finished!")
            bindToFinish()
        end)()
    end

    function Timer.get_current_time()
        return self.remaining_time
    end

    Timer.start()

    return self
end

return Timer