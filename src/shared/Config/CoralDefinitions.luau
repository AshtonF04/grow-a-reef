--!strict
local Types = require(script.Parent.Parent.Types)

type LightLevel = Types.LightLevel
type FlowLevel = Types.FlowLevel

export type CoralDefinition = {
    id: string, -- The id of the specific coral used to reference it in definitionns data
    displayName: string, -- Display name of the coral shown to players
    zone: number, -- The zone the coral is unlocked and plannted in
    growSeconds: number, -- The total number of seconds it takes the coral to mature
    baseYield: number, -- The base value recieved when harvesting/selling the coral
    light: LightLevel, -- The ideal light for the coral corresponds to light on the socket
    flow: FlowLevel, -- The ideal flow for the coral corresponds to the flow on the socket
    family: string, -- The family of the coral
    fragmentPriceShells: number, -- The price of the fragment in shells
    modelName: string, -- The name of the model in the assets
    traitPool: { string }, -- List of traits this coral can naturally have when planted
}

local CoralDefinitions: { [string]: CoralDefinition } = {

    sun_coral = {
        id = "sun_coral",
        displayName = "Sun Coral",
        zone = 1,
        growSeconds = 300,
        baseYield = 18,
        light = "Bright",
        flow = "Medium",
        family = "Branching",
        fragmentPriceShells = 10,
        modelName = "SunCoral",
        traitPool = {}
    }
    
}

for coralId, coral in CoralDefinitions do
    -- Boot Validation
    -- Asserts coralId matches, growSeconds is positive, baseYield is positive, zone is at least 1, fragmentPriceShells is non-negative
    assert(coral.id == coralId, "Coral ID mismatch: " .. coral.id .. " != " .. coralId)
    assert(coral.growSeconds > 0, "Coral growSeconds must be greater than 0: " .. coral.growSeconds)
    assert(coral.baseYield > 0, "Coral baseYield must be greater than 0: " .. coral.baseYield)
    assert(coral.zone >= 1, "Coral zone must be at least 1: " .. coral.zone)
    assert(coral.fragmentPriceShells >= 0, "Coral fragmentPriceShells must be greater than 0: " .. coral.fragmentPriceShells)
    
	table.freeze(coral.traitPool)
	table.freeze(coral)
end
table.freeze(CoralDefinitions)

return CoralDefinitions