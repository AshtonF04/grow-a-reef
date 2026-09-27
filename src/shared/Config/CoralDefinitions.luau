--!strict
export type LightLevel = "Bright" | "Dim"
export type FlowLevel = "Low" | "Medium" | "High"

export type CoralDefinition = {
    id: string, -- The id of the specific coral used to reference it in definitionns data
    displayName: string, -- Display name of the coral shown to players
    zone: number, -- The zone the coral is unlocked and plannted in
    growSeconds: number, -- The total number of seconds it takes the coral to mature
    baseYield: number, -- The base value recieved when harvesting/selling the coral
    light: string, -- The ideal light for the coral corresponds to light on the socket
    flow: string, -- The ideal flow for the coral corresponds to the flow on the socket
    traitPool: { string }, -- List of traits this coral can naturally have when planted
}

local CoralDefinitions = { [string]: CoralDefinition } = {\

    sun_coral = {
        id = "sun_coral",
        displayName = "Sun Coral",
        zone = 1,
        growSeconds = 300,
        baseYield = 18,
        light = "Bright",
        flow = "Medium",
        traitPool = {}
    }
    
}

for _, coral in CoralDefinitions do
	table.freeze(coral.traitPool)
	table.freeze(coral)
end
table.freeze(CoralDefinitions)

return CoralDefinitionsß