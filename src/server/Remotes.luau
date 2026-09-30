--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function makeFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing and existing:IsA("Folder") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
	return folder
end

local function makeEvent(folder: Folder, name: string): RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = folder
	return event
end

local folder = makeFolder()

return {
	folder = folder,
	state_changed = makeEvent(folder, "state_changed"),
	action_notice = makeEvent(folder, "action_notice"),
	request_state = makeEvent(folder, "request_state"),
	unlock_socket = makeEvent(folder, "unlock_socket"),
	plant_coral = makeEvent(folder, "plant_coral"),
	harvest_coral = makeEvent(folder, "harvest_coral"),
}
