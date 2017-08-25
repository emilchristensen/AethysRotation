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
  FuryoftheIllidari = Spell(201467),
  -- Defensive

  -- Utility
  ConsumeMagic = Spell(183752),

  -- Legendaries

  -- Misc
  PoolFury = Spell(9999000010)

  -- Macros
}
local S = Spell.DemonHunter.Havoc
-- Items
if not Item.DemonHunter then
  Item.DemonHunter = {}
end
Item.DemonHunter.Havoc = {
  -- Legendaries
  DelusionsOfGrandeur  = Item(144279, {3}),
  AngerOftheHalfGiants = Item(137038, {11, 12}),

  -- Trinkets
  ConvergenceOfFates   = Item(140806, {13, 14}),
}
local I = Item.DemonHunter.Havoc

-- Rotation vars
local ShouldReturn; -- Used to get the return string
local ConsumeMagicRange = S.ConsumeMagic:MaximumRange();
local DesiredTargets = 1;

-- Cache stats
local BaseHaste = Player:HastePct();
local BaseCrit = Player:CritChancePct();

-- GUI Settings
local Settings = {
  General = AR.GUISettings.General,
  Commons = AR.GUISettings.APL.DemonHunter.Commons,
  Havoc = AR.GUISettings.APL.DemonHunter.Havoc
}

-- Custom helper functions
local function MetamorphosisAdjustedCooldown()
  local ReductionPerSecond = 0.0;

  if (I.ConvergenceOfFates:IsEquipped()) then
    -- Hard coding RPPM to 4.35 based of information on http://www.askmrrobot.com/wow/theory/mechanic/item/140806/convergenceoffates?spec=DruidFeral&version=live
    -- Overriding that with 3.36 since that is what simc is modelled with and returns when calling `simc spell_query=spell.name=prescience`
    local RPPM = 3.36;

    local Reduction = 5.0;

    ReductionPerSecond = ReductionPerSecond + (Reduction / (60.0 / RPPM));
  end

  -- Based on the implementation in simc: https://github.com/simulationcraft/simc/blob/07f1475d1228838d4192d2575a35121e1831b4c9/engine/class_modules/sc_demon_hunter.cpp#L6064
  if (I.DelusionsOfGrandeur:IsEquipped()) then
    -- Fury estimates are on the conservative end, intended to be rough approximation only
    local ApproxFuryPerSecond = 10.2;

    -- Basic adjustment for Demonic specs, assuming Blind Fury+Appetite
    if S.Demonic:IsAvailable() and S.BlindFury:IsAvailable() and S.DemonicAppetite:IsAvailable() then
      ApproxFuryPerSecond = ApproxFuryPerSecond + 1.2;
    end

    if I.AngerOftheHalfGiants:IsEquipped() then
      ApproxFuryPerSecond = ApproxFuryPerSecond + 1.8;
    end

    if AC.Tier20_4Pc then
      ApproxFuryPerSecond = ApproxFuryPerSecond + 2.0;
    end

    if AC.Tier19_2Pc then
      ApproxFuryPerSecond = ApproxFuryPerSecond * 1.1;
    end

    -- Use base haste only for approximation, don't want to calculate with temp buffs
    -- const double base_haste = 1.0 / dh->collected_data.buffed_stats_snapshot.attack_haste;
    -- Check if BaseHaste is 1.xx or 0.xx
    ApproxFuryPerSecond = ApproxFuryPerSecond * (1.0 + (BaseHaste / 100));

    if (S.ChaosStrike:IsAvailable()) then
      -- Assume 90% of Fury used on Chaos Strike/Annihilation
      local ChaosStrikeCrit = BaseCrit + (AC.Tier19_4Pc and 0.08 or 0.0)
      ApproxFuryPerSecond = ApproxFuryPerSecond + (ApproxFuryPerSecond * 0.9) * 0.5 * ChaosStrikeCrit;
    end

    -- DelusionsOfGrandeurFuryPerTime = 30
    -- DelusionsOfGrandeurReduction = -1
    -- ReductionPerSecond = ReductionPerSecond + (ApproxFuryPerSecond / DelusionsOfGrandeurFuryPerTime) * -(DelusionsOfGrandeurReduction);
    -- Shortened for optimization purposes
    ReductionPerSecond = ReductionPerSecond + (ApproxFuryPerSecond / 30);
  end

  return S.Metamorphosis:CooldownRemains() * (1.0 / (1.0 + ReductionPerSecond));
end


-- APL Variables

-- actions+=/variable,name=waiting_for_nemesis,value=!(!talent.nemesis.enabled|cooldown.nemesis.ready|cooldown.nemesis.remains>target.time_to_die|cooldown.nemesis.remains>60)
local function WaitingForNemesis()
  local NemCooldownRemains = S.Nemesis:CooldownRemains()
  return not (
     not S.Nemesis:IsAvailable()
      or S.Nemesis:IsReady()
      or NemCooldownRemains > Target:TimeToDie()
      or NemCooldownRemains > 60
  )
end

-- actions+=/variable,name=waiting_for_chaos_blades,value=!(!talent.chaos_blades.enabled|cooldown.chaos_blades.ready|cooldown.chaos_blades.remains>target.time_to_die|cooldown.chaos_blades.remains>60)
local function WaitingForChaosBlades()
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
local function PoolingForMeta()
  return AR.CDsON() 
    and not S.Demonic:IsAvailable()
    and S.Metamorphosis:CooldownRemains() < 6
    and Player:FuryDeficit() > 30
    and (
    not WaitingForNemesis()
      or S.Nemesis:CooldownRemains() < 10
    )
    and (
      not WaitingForChaosBlades()
      or S.ChaosBlades.CooldownRemains() < 6
    )
end

-- # Blade Dance conditions. Always if First Blood is talented or the T20 4pc set bonus, otherwise at 6+ targets with Chaos Cleave or 3+ targets without.
-- actions+=/variable,name=blade_dance,value=talent.first_blood.enabled|set_bonus.tier20_4pc|spell_targets.blade_dance1>=3+(talent.chaos_cleave.enabled*3)
local function ShouldBladeDance()
  return S.FirstBlood:IsAvailable()
      or AC.Tier20_4Pc
      or (AR.AoEON() and Cache.EnemiesCount[8] >= 3 + (S.ChaosCleave:IsAvailable() and 3 or 0))
end

-- # Blade Dance pooling condition, so we don't spend too much fury on Chaos Strike when we need it soon.
-- actions+=/variable,name=pooling_for_blade_dance,value=variable.blade_dance&(fury<75-talent.first_blood.enabled*20)
local function PoolingForBladeDance()
  return ShouldBladeDance()
     and (Player:Fury() < 75 - (S.FirstBlood:IsAvailable() and 20 or 0))
end

-- TODO raid_event.adds.up & raid_event.adds.in
-- # Chaos Strike pooling condition, so we don't spend too much fury when we need it for Chaos Cleave AoE
-- actions+=/variable,name=pooling_for_chaos_strike,value=talent.chaos_cleave.enabled&fury.deficit>40&!raid_event.adds.up&raid_event.adds.in<2*gcd
local function PoolingForChaosStrike()
  return S.ChaosCleave:IsAvailable()
    and Player:FuryDeficit() > 40
    --and not raid_event.adds.up&raid_event.adds.in<2*gcd
end

--- ======= ACTION LISTS =======
local function APLCDs()
  -- # Use Metamorphosis when we are done pooling Fury and when we are not waiting for other cooldowns to sync.
-- actions.cooldown=metamorphosis,if=!(talent.demonic.enabled|variable.pooling_for_meta|variable.waiting_for_nemesis|variable.waiting_for_chaos_blades)|target.time_to_die<25
  if S.Metamorphosis:IsCastable() and (not (
      S.Demonic:IsAvailable()
      or PoolingForMeta()
      or WaitingForNemesis()
      or WaitingForChaosBlades()
    )
    or Target:TimeToDie() < 25)
  then
    if AR.Cast(S.Metamorphosis) then return "Cast Metamorphosis"; end
  end

-- actions.cooldown+=/metamorphosis,if=talent.demonic.enabled&buff.metamorphosis.up&fury<40
  if S.Metamorphosis:IsCastable() and (S.Demonic:IsAvailable()
    and Player:Buff(S.Metamorphosis)
    and Player:Fury() < 40)
  then
    if AR.Cast(S.Metamorphosis) then return "Cast Metamorphosis"; end
  end

  -- # If adds are present, use Nemesis on the lowest HP add in order to get the Nemesis buff for AoE
  -- actions.cooldown+=/nemesis,target_if=min:target.time_to_die,if=raid_event.adds.exists&debuff.nemesis.down&(active_enemies>desired_targets|raid_event.adds.in>60)
  -- Since we don't have targeting of specific mobs or mob types this step is skipped

  -- actions.cooldown+=/nemesis,if=!raid_event.adds.exists&(buff.chaos_blades.up|buff.metamorphosis.up|cooldown.metamorphosis.adjusted_remains<20|target.time_to_die<=60)
  if S.Nemesis:IsCastable() and (Player:Buff(S.ChaosBlades)
    or Player:Buff(S.Metamorphosis)
    or MetamorphosisAdjustedCooldown() < 20
    or Target:TimeToDie() <= 60)
  then
    if AR.Cast(S.Nemesis) then return "Cast Nemesis"; end
  end

  -- actions.cooldown+=/chaos_blades,if=buff.metamorphosis.up|cooldown.metamorphosis.adjusted_remains>60|target.time_to_die<=12
  if S.ChaosBlades:IsCastable() and (Player.Buff(S.Metamorphosis)
    or MetamorphosisAdjustedCooldown() > 60
    or Target:TimeToDie() <= 12)
  then
    if AR.Cast(S.ChaosBlades) then return "Cast ChaosBlades"; end
  end

  -- actions.cooldown+=/use_item,slot=trinket1
  -- TODO Add SpectarOfBetrayal and UmbralMoonglaives

  -- actions.cooldown+=/potion,if=buff.metamorphosis.remains>25|target.time_to_die<30
  -- TODO Add support for potions
  return false
end

local function APLDemonic()
  -- Interrupts
  if S.ConsumeMagic:IsCastable() and (Target:IsInterruptible() and Settings.General.InterruptEnabled) then
    if Target:IsInRange(ConsumeMagicRange) then
      if AR.Cast(S.ConsumeMagic, Settings.Commons.OffGCDasOffGCD.ConsumeMagic) then return "Cast ConsumeMagic" end
    end
  end

  -- TODO This might not be practical since we want to show the icon before stuff is off GCD
  if AR.CDsON() then
    ShouldReturn = APLCDs();
    if ShouldReturn then return ShouldReturn; end
  end

  -- TODO Implement Demonic APL
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

  if Player:AffectingCombat() then
    if AR.Cast(S.PoolFury) then return "Cast PoolFocus" end
  end
  
  return false
end

local function APLNormal()

  -- Pre combat
  if not Player:AffectingCombat() then
    -- actions.precombat+=/metamorphosis,if=!(talent.demon_reborn.enabled&talent.demonic.enabled)
    -- Since we are in APLNormal we know that Demonic is not talented
    if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() then
      if S.Metamorphosis:IsCastable() and (AR.CDsON() and not S.DemonReborn:IsAvailable()) then
        if AR.Cast(S.Metamorphosis) then return "Cast Metamorphosis"; end
      end
    end
  end

  -- Interrupts
  if S.ConsumeMagic:IsCastable() and Target:IsInterruptible() and Settings.General.InterruptEnabled then
    if Target:IsInRange(ConsumeMagicRange) then
      if AR.Cast(S.ConsumeMagic, Settings.Commons.OffGCDasOffGCD.ConsumeMagic) then return "Cast ConsumeMagic" end
    end
  end

  if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() then
    if AR.CDsON() then
      ShouldReturn = APLCDs();
      if ShouldReturn then return ShouldReturn; end
    end


    -- # General APL for Non-Demonic Builds
    -- actions.normal=pick_up_fragment,if=talent.demonic_appetite.enabled&fury.deficit>=35
    -- No movement suggestions. Use common sense and grab fragments!

    -- # Vengeful Retreat backwards through the target to minimize downtime.
    -- actions.normal+=/vengeful_retreat,if=(talent.prepared.enabled|talent.momentum.enabled)&buff.prepared.down&buff.momentum.down
    if S.VengefulRetreat:IsCastable()
      and ((S.Prepared:IsAvailable() or S.Momentum:IsAvailable())
        and not Player:Buff(S.Prepared)
        and not Player:Buff(S.Momentum)
      )
    then
      if AR.Cast(S.VengefulRetreat) then return "Cast VengefulRetreat"; end
    end

    -- # Fel Rush for Momentum and for fury from Fel Mastery.
    -- actions.normal+=/fel_rush,if=(talent.momentum.enabled|talent.fel_mastery.enabled)&(!talent.momentum.enabled|(charges=2|cooldown.vengeful_retreat.remains>4)&buff.momentum.down)&(!talent.fel_mastery.enabled|fury.deficit>=25)&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
    if S.FelRush:IsCastable()
      and ((S.Momentum:IsAvailable() or S.FelMastery:IsAvailable())
        and (not S.Momentum:IsAvailable()
          or (S.FelRush:Charges() == 2 or S.VengefulRetreat:CooldownRemains() > 4)
          and not Player:Buff(S.Momentum))
        and (not S.FelMastery:IsAvailable() or Player:FuryDeficit() >= 25)
        and S.FelRush:Charges() == 2
      )
      -- Skipping (raid_event.movement.in>10&raid_event.adds.in>10) since we don't have raid_events
    then
      if AR.Cast(S.FelRush) then return "Cast FelRush"; end
    end

    -- # Use Fel Barrage at max charges, saving it for Momentum and adds if possible.
    -- actions.normal+=/fel_barrage,if=(buff.momentum.up|!talent.momentum.enabled)&(active_enemies>desired_targets|raid_event.adds.in>30)
    if AR.AoEON()
      and S.FelBarrage:IsCastable()
      and ((Player:Buff(S.Momentum) or not S.Momentum:IsAvailable())
        and Cache.EnemiesCount[30] > DesiredTargets
      )
    then
      if AR.Cast(S.FelBarrage) then return "Cast FelBarrage"; end
    end

    -- actions.normal+=/throw_glaive,if=talent.bloodlet.enabled&(!talent.momentum.enabled|buff.momentum.up)&charges=2
    if S.ThrowGlaive:IsCastable() and (S.Bloodlet:IsAvailable()
      and (not S.Momentum:IsAvailable() or Player:Buff(S.Momentum))
      and S.ThrowGlaive:Charges() == 2)
    then
      if AR.Cast(S.ThrowGlaive) then return "Cast ThrowGlaive"; end
    end

    -- actions.normal+=/felblade,if=fury<15&(cooldown.death_sweep.remains<2*gcd|cooldown.blade_dance.remains<2*gcd)
    -- TODO Check if S.BladeDance:CooldownRemains() also checks DeathSweep
    if S.FelBlade:IsCastable()
      and Player:Fury() < 15
      and S.BladeDance:CooldownRemains() < 2 * Player:GCD()
    then
      if AR.Cast(S.FelBlade) then return "Cast FelBlade"; end
    end

    -- actions.normal+=/death_sweep,if=variable.blade_dance
    if S.DeathSweep:IsReady()
      and ShouldBladeDance()
      and Player:Buff(S.Metamorphosis)
    then
      if Ar.Cast(S.DeathSweep) then return "Cast DeathSweep"; end
    end

    -- actions.normal+=/fel_rush,if=charges=2&!talent.momentum.enabled&!talent.fel_mastery.enabled
    if S.FelRush:IsCastable() and (not S.Momentum:IsAvailable() and not S.FelMastery:IsAvailable())
      and S.FelRush:Charges() == 2
      -- Skipping (raid_event.movement.in>10&raid_event.adds.in>10) since we don't have raid_events
    then
      if AR.Cast(S.FelRush) then return "Cast FelRush"; end
    end

    -- actions.normal+=/fel_eruption
    if S.FelEruption:IsReady()
      and S.FelEruption:IsAvailable()
    then
      if AR.Cast(S.FelEruption) then return "Cast FelEruption"; end
    end

    -- actions.normal+=/fury_of_the_illidari,if=(active_enemies>desired_targets)|(raid_event.adds.in>55&(!talent.momentum.enabled|buff.momentum.up)&(!talent.chaos_blades.enabled|buff.chaos_blades.up|cooldown.chaos_blades.remains>30|target.time_to_die<cooldown.chaos_blades.remains))
    -- Skipping raid_events
    if S.FuryoftheIllidari:IsCastable() and (
      (Cache.EnemiesCount[6] > DesiredTargets)
        or ((not S.Momentum:IsAvailable() or Player:Buff(S.Momentum))
          and (not S.ChaosBlades:IsAvailable()
            or Player:Buff(S.ChaosBlades)
            or S.ChaosBlades:CooldownRemains() > 30
            or Target:TimeToDie() < S.ChaosBlades:CooldownRemains()
          )
        )
      )
    then
      if AR.Cast(S.FuryoftheIllidari) then return "Cast FuryoftheIllidari"; end
    end

    -- actions.normal+=/blade_dance,if=variable.blade_dance&!cooldown.metamorphosis.ready
    if S.BladeDance:IsReady()
      and ShouldBladeDance()
      and not S.Metamorphosis:IsReady()
    then
      if AR.Cast(S.BladeDance) then return "Cast BladeDance"; end
    end

    -- actions.normal+=/throw_glaive,if=talent.bloodlet.enabled&spell_targets>=2&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&(spell_targets>=3|raid_event.adds.in>recharge_time+cooldown)
    -- No raid_events consolidated first and last condition
    if S.ThrowGlaive:IsCastable() and (S.Bloodlet:IsAvailable()
      and Cache.EnemiesCount[30] >= 3
      and (not S.MasteroftheGlaive.IsAvailable() or not S.Momentum:IsAvailable() or Player:Buff(S.Momentum)))
    then
      if AR.Cast(S.ThrowGlaive) then return "Cast ThrowGlaive"; end
    end

    -- actions.normal+=/felblade,if=fury.deficit>=30+buff.prepared.up*8
    if S.FelBlade:IsCastable()
      and Player:FuryDeficit() >= (30 + Player:Buff(S.Prepared) and 8 or 0)
    then
      if AR.Cast(S.FelBlade) then return "Cast FelBlade"; end
    end

    -- actions.normal+=/eye_beam,if=spell_targets.eye_beam_tick>desired_targets|(spell_targets.eye_beam_tick>=3&raid_event.adds.in>cooldown)|(talent.blind_fury.enabled&fury.deficit>=35)|set_bonus.tier21_2pc
    -- No raid_events
    -- Using 12 yard radius in place of 20 yard conal range.
    if S.EyeBeam:IsReady() and (Cache.EnemiesCount[12] > DesiredTargets
      or (S.BlindFury:IsAvailable() and Player:FuryDeficit() >= 35))
      -- Enable when T21 is implemented
      --or AC.Tier21_2Pc
    then
      if AR.Cast(S.EyeBeam) then return "Cast EyeBeam"; end
    end

    -- actions.normal+=/annihilation,if=(talent.demon_blades.enabled|!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8|buff.metamorphosis.remains<5)&!variable.pooling_for_blade_dance
    if S.Annihilation:IsReady() and ((S.DemonBladesL:IsAvailable()
        or not S.Momentum:IsAvailable()
        or Player:Buff(S.Momentum)
        or Player:FuryDeficit() < 30 + (Player:Buff(S.Prepared) and 8 or 0)
        or Player:BuffRemains(S.Metamorphosis) < 5
      )
      and not PoolingForBladeDance())
    then
      if AR.Cast(S.Annihilation) then return "Cast Annihiliation"; end
    end

    -- actions.normal+=/throw_glaive,if=talent.bloodlet.enabled&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&raid_event.adds.in>recharge_time+cooldown
    -- No raid_events
    if S.ThrowGlaive:IsCastable() and (S.Bloodlet:IsAvailable()
      and (not S.MasteroftheGlaive:IsAvailable() or not S.Momentum:IsAvailable() or Player:Buff(S.Momentum)))
    then
      if AR.Cast(S.ThrowGlaive) then return "Cast ThrowGlaive"; end
    end

    -- actions.normal+=/throw_glaive,if=!talent.bloodlet.enabled&buff.metamorphosis.down&spell_targets>=3
    if S.ThrowGlaive:IsCastable() and (not S.Bloodlet:IsAvailable()
      and not Player:Buff(S.Metamorphosis)
      and Cache.EnemiesCount[30] >= 3)
    then
      if AR.Cast(S.ThrowGlaive) then return "Cast ThrowGlaive"; end
    end

    print(S.ChaosStrike:IsCastable(),
      (S.DemonBlades:IsAvailable() or not S.Momentum:IsAvailable() or Player:Buff(S.Momentum) or Player:FuryDeficit() < 30 + (Player:Buff(S.Prepared) and 8 or 0)),
      not PoolingForChaosStrike(),
      not PoolingForMeta(),
      not PoolingForBladeDance()
    );

    -- actions.normal+=/chaos_strike,if=(talent.demon_blades.enabled|!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8)&!variable.pooling_for_chaos_strike&!variable.pooling_for_meta&!variable.pooling_for_blade_dance
    if S.ChaosStrike:IsCastable() and (
      (S.DemonBlades:IsAvailable() or not S.Momentum:IsAvailable() or Player:Buff(S.Momentum) or Player:FuryDeficit() < 30 + (Player:Buff(S.Prepared) and 8 or 0))
      and not PoolingForChaosStrike()
      and not PoolingForMeta()
      and not PoolingForBladeDance())
    then
      if AR.Cast(S.ChaosStrike) then return "Cast ChaosStrike"; end
    end

    -- actions.normal+=/fel_rush,if=!talent.momentum.enabled&raid_event.movement.in>charges*10&(talent.demon_blades.enabled|buff.metamorphosis.down)
    -- No raid_events
    if S.FelRush:IsCastable()
      and (not S.Momentum:IsAvailable()
        and (S.DemonBlades:IsAvailable() or not Player:Buff(S.Metamorphosis)))

    then
      if AR.Cast(S.FelRush) then return "Cast FelRush"; end
    end

    -- actions.normal+=/demons_bite
    if S.DemonsBite:IsCastable() then
      if AR.Cast(S.DemonsBite) then return "Cast DemonsBite"; end
    end

    -- actions.normal+=/throw_glaive,if=buff.out_of_range.up
    if S.ThrowGlaive:IsCastable()
      and Target:IsInRange(false, tostring(S.ThrowGlaive:ID()))
    then
      if AR.Cast(S.ThrowGlaive) then return "Cast ThrowGlaive"; end
    end

    -- actions.normal+=/felblade,if=movement.distance>15|buff.out_of_range.up
    if S.FelBlade:IsCastable()
      and (not Target:IsInRange(5) or Target:IsInRange(false, tostring(S.FelBlade:ID())))
    then
      if AR.Cast(S.FelBlade) then return "Cast FelBlade"; end
    end

    -- actions.normal+=/fel_rush,if=movement.distance>15|(buff.out_of_range.up&!talent.momentum.enabled)
    if S.FelRush:IsCastable()
      and (not Target:IsInRange(5) or not S.Momentum:IsAvailable())
    then
      if AR.Cast(S.FelRush) then return "Cast FelRush"; end
    end

    -- actions.normal+=/vengeful_retreat,if=movement.distance>15
    -- Skipping

    -- actions.normal+=/throw_glaive,if=!talent.bloodlet.enabled
    if S.ThrowGlaive:IsCastable() and not S.Bloodlet:IsAvailable() then
      if AR.Cast(S.ThrowGlaive) then return "Cast ThrowGlaive"; end
    end
  end

  return false
end

local function APL()
  -- Prime the cache tables
  AC.GetEnemies(6);  -- Fury of the Illidari radius
  AC.GetEnemies(8);  -- Blade Dance radius
  AC.GetEnemies(12); -- Eye Beam radius
  AC.GetEnemies(30); -- Fel Barrage + Throw Glaive radius

  -- Determine which APL to use
  if S.Demonic:IsAvailable() then
    ShouldReturn = APLDemonic();
  else
    ShouldReturn = APLNormal();
  end
  if ShouldReturn then return print(ShouldReturn); end
  
  if Player:AffectingCombat() then
    if AR.Cast(S.PoolFury) then return "Cast PoolFocus" end
  end

end

AR.SetAPL(577, APL);

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
