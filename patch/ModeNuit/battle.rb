module ModeNuit
  def self.trainer_combat?(battle)
    active? && battle.opponent && !battle.isOnline?
  end

  # Mirrors the trainer prize in the WIN arm of V14.0.28's pbEndOfBattle.
  # A negative Luck contract awards no prize; pickup money is a separate effect.
  def self.prize(battle)
    luck = $game_variables[:LuckMoney]
    return 0 if !battle.internalbattle || $game_switches[:NotPlayerCharacter] || luck < 0 || luck > 10
    if battle.opponent.is_a?(Array)
      base = battle.opponent.each_with_index.sum do |t, i|
        level = battle.party2.fetch(i).compact.map(&:level).max || 0
        [100, level].min * t.moneyEarned
      end
    else
      level = battle.party2.flatten.compact.map(&:level).max || 0
      base = level * battle.opponent.moneyEarned
    end
    base *= 1 + battle.pbPlayer.numbadges.div(2)
    base *= 2 if battle.instance_variable_get(:@amuletcoin)
    base *= 2 if battle.instance_variable_get(:@happyhour)
    base *= 2 if $game_switches[:Moneybags]
    base = base.div(4) if $game_switches[:Grinding_Trainer_Money_Cut] || $game_switches[:Penniless_Mode]
    base *= 2 if luck != 0
    base
  end

  def self.classic_blackout_loss(battle)
    return 0 if $game_switches[:No_Money_Loss] || $Trainer.money <= 0
    rates = [8,16,24,36,48,64,80,100,120,140,160,180,190,200,210,220,230,240,250,250]
    level = battle.pbMaxLevelFromIndex(0)
    [level * rates[[$Trainer.numbadges, rates.size-1].min], $Trainer.money].min
  end

  module Battles
    def pbStartBattle(...)
      if ModeNuit.active? && !isOnline?
        @shiftStyle = false
        ModeNuit.before_battle
      end
      super
    end
    def pbReplaceFaintedBattlers(...)
      @shiftStyle = false if ModeNuit.active? && !isOnline?
      super
    end
    def pbRegisterItem(...)
      return false if ModeNuit.trainer_combat?(self)
      super
    end
    def pbEnemyUseItem(...)
      return 0 if ModeNuit.trainer_combat?(self)
      super
    end
    def pbEndOfBattle(...)
      return super unless ModeNuit.active? && !isOnline? && [2, 5].include?(@decision)
      # Facilities with an external scoring system do not award a cash prize.
      # A wild defeat and the native draw result follow the Classic blackout rule.
      loss = if @opponent && @decision == 2
               ModeNuit.prize(self)
             elsif @internalbattle
               ModeNuit.classic_blackout_loss(self)
             else
               0
             end
      ModeNuit.before_battle unless File.file?(ModeNuit.slot_path)
      unless @nuit_defeat_committed
        ModeNuit.commit_defeat(loss)
        @nuit_defeat_committed = true
        if loss > 0 && @opponent
          pbDisplayAutoPaused(ModeNuit.text("Defeat cost #{getPurchaseDisplay(loss)}. Balance: #{getPurchaseDisplay($Trainer.money)}.",
            "La défaite coûte #{getPurchaseDisplay(loss)}. Solde : #{getPurchaseDisplay($Trainer.money)}."))
        elsif loss > 0
          pbDisplayAutoPaused(_INTL("{1} panicked and lost {2}...", $Trainer.name, getPurchaseDisplay(loss)))
        end
      end
      previous = Thread.current[:nuit_skip_blackout_debit]
      begin
        Thread.current[:nuit_skip_blackout_debit] = true
        super
      ensure
        Thread.current[:nuit_skip_blackout_debit] = previous
      end
    end
  end
  module LossSwitch
    def [](key)
      return true if key == :No_Money_Loss && Thread.current[:nuit_skip_blackout_debit]
      super
    end
  end
  module BattleMenu
    def pbItemMenu(...)
      return super unless ModeNuit.trainer_combat?(@battle)
      @battle.pbDisplay(ModeNuit.text("The Bag is closed during trainer battles.", "Le sac est fermé pendant les combats de dresseurs."))
      [nil, -1]
    end
  end
  module BattleAI
    def getItemScore
      return super unless ModeNuit.trainer_combat?(@battle)
      @mondata.itemscore = {}
      nil
    end
  end
end
PokeBattle_Battle.prepend(ModeNuit::Battles)
Game_Switches.prepend(ModeNuit::LossSwitch)
PokeBattle_Scene.prepend(ModeNuit::BattleMenu)
PokeBattle_AI.prepend(ModeNuit::BattleAI)
