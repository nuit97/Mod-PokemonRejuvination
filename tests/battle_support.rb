# Only substitutes the presentation and human controls of automated battles.
class NuitBattleScreen
  attr_reader :messages, :questions, :sprites
  attr_accessor :gainEXPPhase, :moveUseDisplayPhase, :speakingTrainer
  def initialize
    @sprites = {'battlebox1' => Struct.new(:opacity).new(255)}
    @messages = []
    @questions = []
  end
  def pbStartBattle(battle)
    @battle = battle
  end
  def addToBattleLog(*); end
  def pbCommandMenu(*); 0; end
  def pbFightMenu(*); 0; end
  def pbChooseBallTarget(*); 1; end
  def pbDisplayConfirmMessage(text, *)
    @questions << text
    false
  end
  def pbDisplayMessage(text, *, **); @messages << text; end
  def pbDisplayPausedMessage(text, *, **); @messages << text; end
  def method_missing(name, *args, **kwargs, &block)
    return if PokeBattle_Scene.method_defined?(name)
    super
  end
end

# Automated full battle: native move, AI, damage, KO, prize and money writes.
def duel(player_mon, enemy_mon, enemy_type)
  $Trainer.party.replace(Array(player_mon))
  trainer = PokeBattle_Trainer.new('Test', enemy_type)
  trainer.party.concat(Array(enemy_mon))
  screen = NuitBattleScreen.new
  battle = PokeBattle_Battle.new(screen, [$Trainer.party], [trainer.party], $Trainer, trainer)
  battle.items = [:POTION]
  battle.endspeech = 'OK'
  battle.endspeechwin = 'OK'
  battle.shiftStyle = true
  [battle, screen]
end
def test_enemy_type
  $cache.trainertypes.keys.find { |k| $cache.trainertypes[k].moneymult == 100 }
end
def test_mon(species, level, move)
  mon = PokeBattle_Pokemon.new(species, level)
  mon.moves = [PBMove.new(move)]
  mon
end
