--!strict

local function pick(name: string, fallback: Enum.Font): Enum.Font
	for _, item in Enum.Font:GetEnumItems() do
		if item.Name == name then
			return item
		end
	end
	return fallback
end

return {
	Bold = pick("BuilderSansBold", Enum.Font.GothamBold),
	Body = pick("BuilderSans", Enum.Font.Gotham),
}
