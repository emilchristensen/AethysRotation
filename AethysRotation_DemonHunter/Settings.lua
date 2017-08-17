--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- AethysRotation
local AR = AethysRotation

--- ============================ CONTENT ============================
-- All settings here should be moved into the GUI someday.
AR.GUISettings.APL.DemonHunter = {
    Commons = {
        -- {Display OffGCD as OffGCD, ForceReturn}
        OffGCDasOffGCD = {
            -- Abilities
            ConsumeMagic = {true, false}
        }
    },
    Vengeance = {
        -- {Display OffGCD as OffGCD, ForceReturn}
        OffGCDasOffGCD = {
            -- Abilities
            DemonSpikes = {true, false},
            InfernalStrike = {true, false}
        }
    },
    Havoc = {
        -- {Display OffGCD as OffGCD, ForceReturn}
        OffGCDasOffGCD = {
            -- Abilities
            ArcaneTorrent = {true, false},
            ChaosBlades = {true, false},
            Nemesis = {true, false},
            FuryoftheIllidari = {true, false},
            Metamorphosis = {true, false}
        }
    }
}
