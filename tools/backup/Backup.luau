--!nonstrict
-- Saves every service's Studio content to studio_backup/<Service>.rbxm via tools/backup/receiver.py.
-- Run in Edit mode (command bar / MCP) while the receiver is running. Rojo-managed code is included too,
-- but git is the source of truth for that.
local HttpService = game:GetService("HttpService")
local SerializationService = game:GetService("SerializationService")
local EncodingService = game:GetService("EncodingService")

local URL = "http://127.0.0.1:34900/"
local SERVICES = {
	"Workspace",
	"Lighting",
	"ReplicatedStorage",
	"ReplicatedFirst",
	"ServerScriptService",
	"ServerStorage",
	"StarterGui",
	"StarterPack",
	"StarterPlayer",
	"SoundService",
	"Teams",
}

local results = {}
for _, serviceName in SERVICES do
	local ok, err = pcall(function()
		local service = game:GetService(serviceName)
		local items = {}
		for _, child in service:GetChildren() do
			-- Skip things that can't or shouldn't be saved (camera, terrain object itself, Rojo lock)
			if child.Archivable and not child:IsA("Camera") and not child:IsA("Terrain") and child.Name ~= "__Rojo_SessionLock" then
				table.insert(items, child)
			end
		end
		if #items == 0 then
			return
		end
		local blob = SerializationService:SerializeInstancesAsync(items)
		local encoded = buffer.tostring(EncodingService:Base64Encode(blob))
		local response = HttpService:PostAsync(URL .. serviceName, encoded, Enum.HttpContentType.TextPlain)
		table.insert(results, response)
	end)
	if not ok then
		table.insert(results, serviceName .. " FAILED: " .. tostring(err))
	end
end

return table.concat(results, "\n")
