local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TimeUtil = {}

-- Any timestamp being saved to the players data must be the servers value never a client value
function TimeUtil.Now(): number
    if RunService:IsServer() then
        return os.time()
    else
        return Workspace.GetServerTimeNow()
    end
end


return TimeUtil