--!strict
export type LightLevel = "Bright" | "Dim"
export type FlowLevel = "Low" | "Medium" | "High"

export type CoralDefinition = {
    id: string, -- The id of the specific coral used to reference it in definitionns data
    displayName: string, -- Display name of the coral shown to players
    family: string, -- Coral family, used by the collection book and habitat sets later
    zone: number, -- The zone the coral is unlocked and plannted in
    growSeconds: number, -- The total number of seconds it takes the coral to mature
    baseYield: number, -- The base value recieved when harvesting/selling the coral
    nurseryCost: number, -- Shells to buy one fragment in the Nursery
    light: LightLevel, -- The ideal light for the coral corresponds to light on the socket
    flow: FlowLevel, -- The ideal flow for the coral corresponds to the flow on the socket
    traitPool: { string }, -- List of traits this coral can naturally have when planted
}

-- Sunlit Shelf launch set. Each coral's light and flow match exactly one of the six sockets.
-- Yields and costs are placeholders to tune against the 15-25 minute "first six sockets" target.
local CoralDefinitions: { [string]: CoralDefinition } = {

    sun_coral = {
        id = "sun_coral",
        displayName = "Sun Coral",
        family = "Branching",
        zone = 1,
        growSeconds = 300,
        baseYield = 18,
        nurseryCost = 10,
        light = "Bright",
        flow = "Medium",
        traitPool = {}
    },

    branch_coral = {
        id = "branch_coral",
        displayName = "Branch Coral",
        family = "Branching",
        zone = 1,
        growSeconds = 120, -- the fast pick in the onboarding choice
        baseYield = 9,
        nurseryCost = 15,
        light = "Bright",
        flow = "High",
        traitPool = {}
    },

    brain_coral = {
        id = "brain_coral",
        displayName = "Brain Coral",
        family = "Massive",
        zone = 1,
        growSeconds = 900, -- the valuable pick in the onboarding choice
        baseYield = 60,
        nurseryCost = 40,
        light = "Bright",
        flow = "Low",
        traitPool = {}
    },

    plate_coral = {
        id = "plate_coral",
        displayName = "Plate Coral",
        family = "Plating",
        zone = 1,
        growSeconds = 600,
        baseYield = 36,
        nurseryCost = 30,
        light = "Dim",
        flow = "Medium",
        traitPool = {}
    },

    star_coral = {
        id = "star_coral",
        displayName = "Star Coral",
        family = "Massive",
        zone = 1,
        growSeconds = 1200,
        baseYield = 80,
        nurseryCost = 60,
        light = "Dim",
        flow = "High",
        traitPool = {}
    },

    bubble_coral = {
        id = "bubble_coral",
        displayName = "Bubble Coral",
        family = "Bubble",
        zone = 1,
        growSeconds = 1800,
        baseYield = 120,
        nurseryCost = 90,
        light = "Dim",
        flow = "Low",
        traitPool = {}
    },

}

for _, coral in CoralDefinitions do
	table.freeze(coral.traitPool)
	table.freeze(coral)
end
table.freeze(CoralDefinitions)

return CoralDefinitions
