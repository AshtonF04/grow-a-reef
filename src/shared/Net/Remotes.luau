--!strict
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Definitions: { [string]: "Function" | "Event" } = {
    client_ready = "Function",
    state_changed = "Event",
}

local Remotes = {}

-- Creates all remotes from the Definitions provided above, server only method
function Remotes.CreateAll() : Folder
    assert(RunService:IsServer(), "Remotes.CreateAll() must be called from the server.")
    assert(ReplicatedStorage:FindFirstChild("Remotes") == nil, "Remotes folder already exists in ReplicatedStorage")

    local remotesFolder = Instance.new("Folder", ReplicatedStorage)
    remotesFolder.Name = "Remotes"

    for remoteName, remoteType in Definitions do
        local remote : Instance

        if remoteType == "Function" then
            remote = Instance.new("RemoteFunction", remotesFolder)
        else
            remote = Instance.new("RemoteEvent", remotesFolder)
        end

        remote.Name = remoteName
    end

    return remotesFolder
end

-- Gets a remote event 
function Remotes.GetEvent(name) : RemoteEvent
    local remote = Definitions[name]
    assert(remote ~= nil, "Remotes: Unknown event '".. name .."'")
    assert(remote == "Event", "Remotes: This remote is not an event")

    local remoteInstance =  ReplicatedStorage.Remotes:WaitForChild(name, 10)
    assert(remoteInstance ~= nil, "Remotes: Timed out waiting for event instance")
    assert(remoteInstance:IsA("RemoteEvent"), "Remotes: Instance is not a RemoteEvent")

    return remoteInstance
end

-- Gets a remote function 
function Remotes.GetFunction(name) : RemoteFunction
    local remote = Definitions[name]
    assert(remote ~= nil, "Remotes: Unknown function '".. name .."'")
    assert(remote == "Function", "Remotes: This remote is not a RemoteFunction")

    local remoteInstance =  ReplicatedStorage.Remotes:WaitForChild(name, 10)
    assert(remoteInstance ~= nil, "Remotes: Timed out waiting for function instance")
    assert(remoteInstance:IsA("RemoteFunction"), "Remotes: Instance is not a RemoteFunction")

    return remoteInstance
end

return Remotes