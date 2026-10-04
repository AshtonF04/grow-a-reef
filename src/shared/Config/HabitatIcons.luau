--!strict
-- Icons and labels for socket / coral habitat conditions, shared by every screen and billboard.
local HabitatIcons = {}

HabitatIcons.Light = table.freeze({ Bright = "☀️", Dim = "🌙" }) :: { [string]: string }
HabitatIcons.Flow = table.freeze({ Low = "〰️", Medium = "🌊", High = "💨" }) :: { [string]: string }

HabitatIcons.LightLabel = table.freeze({ Bright = "Bright", Dim = "Dim" }) :: { [string]: string }
HabitatIcons.FlowLabel = table.freeze({ Low = "Low flow", Medium = "Medium flow", High = "High flow" }) :: { [string]: string }

return table.freeze(HabitatIcons)
