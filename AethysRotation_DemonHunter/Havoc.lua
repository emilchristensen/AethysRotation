--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- AethysCore
local AC = AethysCore
local Cache = AethysCache
local Unit = AC.Unit
local Player = Unit.Player
local Target = Unit.Target
local Spell = AC.Spell
local Item = AC.Item
-- AethysRotation
local AR = AethysRotation
-- Lua

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
local Everyone = AR.Commons.Everyone
-- Spells
if not Spell.DemonHunter then
    Spell.DemonHunter = {}
end
Spell.DemonHunter.Havoc = {
    -- Racials
    ArcaneTorrent = Spell(80483),
    -- Abilities
    Annihilation = Spell(201427),
    BladeDance = Spell(188499),
    ChaosStrike = Spell(162794),
    DeathSweep = Spell(210152),
    DemonsBite = Spell(162243),
    EyeBeam = Spell(198013),
    FelRush = Spell(195072),
    Metamorphosis = Spell(191427),
    ThrowGlaive = Spell(204157),
    VengefulRetreat = Spell(198793),
    -- Talents
    BlindFury = Spell(203550),
    Bloodlet = Spell(206473),
    ChaosBlades = Spell(211048),
    ChaosCleave = Spell(206475),
    DemonBlades = Spell(203555),
    Demonic = Spell(213410),
    DemonicAppetite = Spell(206478),
    DemonReborn = Spell(193897),
    FelBarrage = Spell(211053),
    FelBlade = Spell(232893),
    FelEruption = Spell(211881),
    FelMastery = Spell(192939),
    FirstBlood = Spell(206416),
    MasteroftheGlaive = Spell(203556),
    Momentum = Spell(206476),
    Nemesis = Spell(206491),
    Prepared = Spell(203551),
    -- Artifact
    FuryoftheIllidari = Spell(201467)
    -- Defensive

    -- Utility

    -- Legendaries

    -- Misc

    -- Macros
}
local S = Spell.DemonHunter.Havoc
-- Items
if not Item.DemonHunter then
    Item.DemonHunter = {}
end
Item.DemonHunter.Havoc = {}
local I = Item.DemonHunter.Havoc
-- Rotation vars
local BDIdentifier = tostring(S.BladeDance:ID());

-- GUI Settings
local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.DemonHunter.Commons,
    Havoc = AR.GUISettings.APL.DemonHunter.Havoc
}

-- APL Variables

-- actions+=/variable,name=waiting_for_nemesis,value=!(!talent.nemesis.enabled|cooldown.nemesis.ready|cooldown.nemesis.remains>target.time_to_die|cooldown.nemesis.remains>60)
local function waitingForNemesis()
  local NemCooldownRemains = S.Nemesis:CooldownRemains()
  return not (
      not S.Nemesis:IsAvailable()
      or S.Nemesis:IsReady()
      or NemCooldownRemains > Target:TimeToDie()
      or NemCooldownRemains > 60
  )
end

-- actions+=/variable,name=waiting_for_chaos_blades,value=!(!talent.chaos_blades.enabled|cooldown.chaos_blades.ready|cooldown.chaos_blades.remains>target.time_to_die|cooldown.chaos_blades.remains>60)
local function waitingForChaosBlades()
  local CBCooldownRemains = S.ChaosBlades:CooldownRemains()
  return not (
      not S.ChaosBlades:IsAvailable()
      or S.ChaosBlades:IsReady()
      or CBCooldownRemains > Target:TimeToDie()
      or CBCooldownRemains > 60
  )
end

-- # "Getting ready to use meta" conditions, this is used in a few places.
-- actions+=/variable,name=pooling_for_meta,value=!talent.demonic.enabled&cooldown.metamorphosis.remains<6&fury.deficit>30&(!variable.waiting_for_nemesis|cooldown.nemesis.remains<10)&(!variable.waiting_for_chaos_blades|cooldown.chaos_blades.remains<6)
local function poolingForMeta()
  return not S.Demonic:IsAvailable()
     and S.Metamorphosis:CooldownRemains() < 6
     and Player:FuryDeficit() > 30
     and (
       not waitingForNemesis()
        or S.Nemesis:CooldownRemains() < 10
     )
     and (
       not waitingForChaosBlades()
        or S.ChaosBlades.CooldownRemains() < 6
     )
end

-- # Blade Dance conditions. Always if First Blood is talented or the T20 4pc set bonus, otherwise at 6+ targets with Chaos Cleave or 3+ targets without.
-- actions+=/variable,name=blade_dance,value=talent.first_blood.enabled|set_bonus.tier20_4pc|spell_targets.blade_dance1>=3+(talent.chaos_cleave.enabled*3)
local function shouldBladeDance()
  return S.FirstBlood:IsAvailable()
      or AC.Tier20_4Pc
      or Cache.EnemiesCount[BDIdentifier] >= 3 + (S.ChaosCleave.IsAvailable() and 3 or 0)
end

-- # Blade Dance pooling condition, so we don't spend too much fury on Chaos Strike when we need it soon.
-- actions+=/variable,name=pooling_for_blade_dance,value=variable.blade_dance&(fury<75-talent.first_blood.enabled*20)
-- # Chaos Strike pooling condition, so we don't spend too much fury when we need it for Chaos Cleave AoE
-- actions+=/variable,name=pooling_for_chaos_strike,value=talent.chaos_cleave.enabled&fury.deficit>40&!raid_event.adds.up&raid_event.adds.in<2*gcd











--- ======= ACTION LISTS =======
-- actions.precombat+=/metamorphosis,if=!(talent.demon_reborn.enabled&talent.demonic.enabled)






--- How to call the correct APL
-- if Player:Buff(S.Meta or whatever its called) then
--   ShouldReturn = Meta();
local function APL()
  AC.GetEnemies(S.BladeDance, BDIdentifier);
end


--- ======= SIMC =======
--- Last Update: 08/15/2017

-- # Executed before combat begins. Accepts non-harmful actions only.
---- actions.precombat=flask
---- actions.precombat+=/augmentation
---- actions.precombat+=/food
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
---- actions.precombat+=/snapshot_stats
---- actions.precombat+=/potion
-- actions.precombat+=/metamorphosis,if=!(talent.demon_reborn.enabled&talent.demonic.enabled)

-- # Executed every time the actor is available.
-- actions=auto_attack
-- actions+=/variable,name=waiting_for_nemesis,value=!(!talent.nemesis.enabled|cooldown.nemesis.ready|cooldown.nemesis.remains>target.time_to_die|cooldown.nemesis.remains>60)
-- actions+=/variable,name=waiting_for_chaos_blades,value=!(!talent.chaos_blades.enabled|cooldown.chaos_blades.ready|cooldown.chaos_blades.remains>target.time_to_die|cooldown.chaos_blades.remains>60)
-- # "Getting ready to use meta" conditions, this is used in a few places.
-- actions+=/variable,name=pooling_for_meta,value=!talent.demonic.enabled&cooldown.metamorphosis.remains<6&fury.deficit>30&(!variable.waiting_for_nemesis|cooldown.nemesis.remains<10)&(!variable.waiting_for_chaos_blades|cooldown.chaos_blades.remains<6)
-- # Blade Dance conditions. Always if First Blood is talented or the T20 4pc set bonus, otherwise at 6+ targets with Chaos Cleave or 3+ targets without.
-- actions+=/variable,name=blade_dance,value=talent.first_blood.enabled|set_bonus.tier20_4pc|spell_targets.blade_dance1>=3+(talent.chaos_cleave.enabled*3)
-- # Blade Dance pooling condition, so we don't spend too much fury on Chaos Strike when we need it soon.
-- actions+=/variable,name=pooling_for_blade_dance,value=variable.blade_dance&(fury<75-talent.first_blood.enabled*20)
-- # Chaos Strike pooling condition, so we don't spend too much fury when we need it for Chaos Cleave AoE
-- actions+=/variable,name=pooling_for_chaos_strike,value=talent.chaos_cleave.enabled&fury.deficit>40&!raid_event.adds.up&raid_event.adds.in<2*gcd
-- actions+=/consume_magic
-- actions+=/call_action_list,name=cooldown,if=gcd.remains=0
-- actions+=/run_action_list,name=demonic,if=talent.demonic.enabled
-- actions+=/run_action_list,name=normal

-- # Use Metamorphosis when we are done pooling Fury and when we are not waiting for other cooldowns to sync.
-- actions.cooldown=metamorphosis,if=!(talent.demonic.enabled|variable.pooling_for_meta|variable.waiting_for_nemesis|variable.waiting_for_chaos_blades)|target.time_to_die<25
-- actions.cooldown+=/metamorphosis,if=talent.demonic.enabled&buff.metamorphosis.up&fury<40
-- # If adds are present, use Nemesis on the lowest HP add in order to get the Nemesis buff for AoE
-- actions.cooldown+=/nemesis,target_if=min:target.time_to_die,if=raid_event.adds.exists&debuff.nemesis.down&(active_enemies>desired_targets|raid_event.adds.in>60)
-- actions.cooldown+=/nemesis,if=!raid_event.adds.exists&(buff.chaos_blades.up|buff.metamorphosis.up|cooldown.metamorphosis.adjusted_remains<20|target.time_to_die<=60)
-- actions.cooldown+=/chaos_blades,if=buff.metamorphosis.up|cooldown.metamorphosis.adjusted_remains>60|target.time_to_die<=12
-- actions.cooldown+=/use_item,slot=trinket1
-- actions.cooldown+=/potion,if=buff.metamorphosis.remains>25|target.time_to_die<30

-- # Specific APL for the Blind Fury+Demonic Appetite+Demonic build
-- actions.demonic=pick_up_fragment,if=fury.deficit>=35&(cooldown.eye_beam.remains>5|buff.metamorphosis.up)
-- # Vengeful Retreat backwards through the target to minimize downtime.
-- actions.demonic+=/vengeful_retreat,if=(talent.prepared.enabled|talent.momentum.enabled)&buff.prepared.down&buff.momentum.down
-- # Fel Rush for Momentum.
-- actions.demonic+=/fel_rush,if=(talent.momentum.enabled|talent.fel_mastery.enabled)&(!talent.momentum.enabled|(charges=2|cooldown.vengeful_retreat.remains>4)&buff.momentum.down)&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
-- actions.demonic+=/throw_glaive,if=talent.bloodlet.enabled&(!talent.momentum.enabled|buff.momentum.up)&charges=2
-- actions.demonic+=/death_sweep,if=variable.blade_dance
-- actions.demonic+=/fel_eruption
-- actions.demonic+=/fury_of_the_illidari,if=(active_enemies>desired_targets)|(raid_event.adds.in>55&(!talent.momentum.enabled|buff.momentum.up))
-- actions.demonic+=/blade_dance,if=variable.blade_dance&cooldown.eye_beam.remains>5&!cooldown.metamorphosis.ready
-- actions.demonic+=/throw_glaive,if=talent.bloodlet.enabled&spell_targets>=2&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&(spell_targets>=3|raid_event.adds.in>recharge_time+cooldown)
-- actions.demonic+=/felblade,if=fury.deficit>=30
-- actions.demonic+=/eye_beam,if=spell_targets.eye_beam_tick>desired_targets|!buff.metamorphosis.extended_by_demonic
-- actions.demonic+=/annihilation,if=(!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8|buff.metamorphosis.remains<5)&!variable.pooling_for_blade_dance
-- actions.demonic+=/throw_glaive,if=talent.bloodlet.enabled&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&raid_event.adds.in>recharge_time+cooldown
-- actions.demonic+=/chaos_strike,if=(!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8)&!variable.pooling_for_chaos_strike&!variable.pooling_for_meta&!variable.pooling_for_blade_dance
-- actions.demonic+=/fel_rush,if=!talent.momentum.enabled&(buff.metamorphosis.down|talent.demon_blades.enabled)&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
-- actions.demonic+=/demons_bite
-- actions.demonic+=/throw_glaive,if=buff.out_of_range.up|!talent.bloodlet.enabled
-- actions.demonic+=/fel_rush,if=movement.distance>15|(buff.out_of_range.up&!talent.momentum.enabled)
-- actions.demonic+=/vengeful_retreat,if=movement.distance>15

-- # General APL for Non-Demonic Builds
-- actions.normal=pick_up_fragment,if=talent.demonic_appetite.enabled&fury.deficit>=35
-- # Vengeful Retreat backwards through the target to minimize downtime.
-- actions.normal+=/vengeful_retreat,if=(talent.prepared.enabled|talent.momentum.enabled)&buff.prepared.down&buff.momentum.down
-- # Fel Rush for Momentum and for fury from Fel Mastery.
-- actions.normal+=/fel_rush,if=(talent.momentum.enabled|talent.fel_mastery.enabled)&(!talent.momentum.enabled|(charges=2|cooldown.vengeful_retreat.remains>4)&buff.momentum.down)&(!talent.fel_mastery.enabled|fury.deficit>=25)&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
-- # Use Fel Barrage at max charges, saving it for Momentum and adds if possible.
-- actions.normal+=/fel_barrage,if=(buff.momentum.up|!talent.momentum.enabled)&(active_enemies>desired_targets|raid_event.adds.in>30)
-- actions.normal+=/throw_glaive,if=talent.bloodlet.enabled&(!talent.momentum.enabled|buff.momentum.up)&charges=2
-- actions.normal+=/felblade,if=fury<15&(cooldown.death_sweep.remains<2*gcd|cooldown.blade_dance.remains<2*gcd)
-- actions.normal+=/death_sweep,if=variable.blade_dance
-- actions.normal+=/fel_rush,if=charges=2&!talent.momentum.enabled&!talent.fel_mastery.enabled
-- actions.normal+=/fel_eruption
-- actions.normal+=/fury_of_the_illidari,if=(active_enemies>desired_targets)|(raid_event.adds.in>55&(!talent.momentum.enabled|buff.momentum.up)&(!talent.chaos_blades.enabled|buff.chaos_blades.up|cooldown.chaos_blades.remains>30|target.time_to_die<cooldown.chaos_blades.remains))
-- actions.normal+=/blade_dance,if=variable.blade_dance&!cooldown.metamorphosis.ready
-- actions.normal+=/throw_glaive,if=talent.bloodlet.enabled&spell_targets>=2&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&(spell_targets>=3|raid_event.adds.in>recharge_time+cooldown)
-- actions.normal+=/felblade,if=fury.deficit>=30+buff.prepared.up*8
-- actions.normal+=/eye_beam,if=spell_targets.eye_beam_tick>desired_targets|(spell_targets.eye_beam_tick>=3&raid_event.adds.in>cooldown)|(talent.blind_fury.enabled&fury.deficit>=35)|set_bonus.tier21_2pc
-- actions.normal+=/annihilation,if=(talent.demon_blades.enabled|!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8|buff.metamorphosis.remains<5)&!variable.pooling_for_blade_dance
-- actions.normal+=/throw_glaive,if=talent.bloodlet.enabled&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&raid_event.adds.in>recharge_time+cooldown
-- actions.normal+=/throw_glaive,if=!talent.bloodlet.enabled&buff.metamorphosis.down&spell_targets>=3
-- actions.normal+=/chaos_strike,if=(talent.demon_blades.enabled|!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8)&!variable.pooling_for_chaos_strike&!variable.pooling_for_meta&!variable.pooling_for_blade_dance
-- actions.normal+=/fel_rush,if=!talent.momentum.enabled&raid_event.movement.in>charges*10&(talent.demon_blades.enabled|buff.metamorphosis.down)
-- actions.normal+=/demons_bite
-- actions.normal+=/throw_glaive,if=buff.out_of_range.up
-- actions.normal+=/felblade,if=movement.distance>15|buff.out_of_range.up
-- actions.normal+=/fel_rush,if=movement.distance>15|(buff.out_of_range.up&!talent.momentum.enabled)
-- actions.normal+=/vengeful_retreat,if=movement.distance>15
-- actions.normal+=/throw_glaive,if=!talent.bloodlet.enabled
