require_relative 'support'
require_relative 'battle_support'
raise 'Expected private test profile' unless File.file?('Save Data/.portable') && ENV['NUIT_TEST_FILE']
$Settings = PokemonOptions.new
if ENV['NUIT_TEST_LANG'] == 'fr'
  300.times { break if respond_to?(:_orig_pbLoadLanguage_fr, true); sleep 0.01 }
  $Settings.language = 1
  pbLoadLanguage
end
Kernel.singleton_class.prepend(NuitChecks::Inputs)
$Unidata = {saveslot: 1}
$game_temp = Game_Temp.new
$PokemonTemp = PokemonTemp.new
PBDebug.define_singleton_method(:logonerr) { |&action| action.call }
loader_scene = Object.new
def loader_scene.pbEndScene; end
PokemonLoad.new(loader_scene).startPlayingSaveFile(RTP.getSaveSlotPath(1))
nc('cold restart through native Continue') { ModeNuit.active? && $game_map && $scene.is_a?(Scene_Map) }
ne('defeat persists after process exit', [-2000,1], [$Trainer.money,$game_system.mode_nuit_losses])
ne('restored party retains true nature and IVs', [:TIMID,[31]*6], [$Trainer.party.first.nature,$Trainer.party.first.instance_variable_get(:@iv)])
ne('original adventure restored', File.read('adventure-id'), $game_system.mode_nuit_id)
enemy_type = test_enemy_type
hero = test_mon(:MEWTWO,75,:PSYSTRIKE)
enemy = test_mon(:MAGIKARP,10,:SPLASH)
victory, screen = duel([hero,test_mon(:EEVEE,15,:TACKLE)],[enemy,test_mon(:MAGIKARP,10,:SPLASH)],enemy_type)
$game_temp.in_battle = true
ne('engine finishes trainer win', 1, victory.pbStartBattle(true))
$game_temp.in_battle = false
nc('opponent sends its reserve with no free switch prompt') { !screen.questions.include?(_INTL("Will you switch your Pokémon?")) && victory.party2.flatten.compact.all? { |m| m.hp == 0 } }
ne('stock victory prize raises negative balance', -1000, $Trainer.money)
nc('save new balance in the active slot') { pbSave }
ne('winning balance on disk', -1000, ModeNuit.read_slot(ModeNuit.slot_path)[:Trainer].money)
path = ModeNuit.slot_path
baseline = File.binread(path)
begin
  ModeNuit.install_snapshot { |temp, _, _| File.binwrite(temp, 'broken') }
  raise 'invalid staged file accepted'
rescue TypeError, ArgumentError, EOFError
  ne('damaged staged write leaves active slot intact', baseline, File.binread(path))
end
nc('recovery copy loads and is outside the slot list') do
  data = ModeNuit.read_slot(path + '.nuit-secours')
  data[:system].mode_nuit_id == $game_system.mode_nuit_id &&
    Dir.children(File.dirname(path)).grep(/\AGame(?:_\d+)?\.rxdata\z/).size == 2
end
rev = $game_system.mode_nuit_revision
$game_system.mode_nuit_revision = rev-1
begin
  ModeNuit.save_game
  raise 'stale revision accepted'
rescue IOError
  ne('stale revision cannot overwrite newer slot', baseline, File.binread(path))
ensure
  $game_system.mode_nuit_revision = rev
end
$Unidata[:saveslot] = 2
begin
  ModeNuit.save_game
  raise 'foreign slot write accepted'
rescue IOError
  ne('other adventure is byte-identical', File.binread('story-baseline'), File.binread(RTP.getSaveSlotPath(2)))
ensure
  $Unidata[:saveslot] = 1
end
class TestShopUI
  def pbChooseSellItem
    return if @sold
    @sold = true
    :POTION
  end
  def pbConfirm(*); true; end
  def pbDisplayPaused(*); end
  def pbStartSellScene(*); end
  def pbEndSellScene; end
  def pbShowMoney; end
  def pbHideMoney; end
end
stock = ItemStock.of(:POTION)
shop = PokemonMartScreen.new(TestShopUI.new,[stock])
nc('native shop declines purchase with insufficient funds') { !shop.pbCheckAffordability(stock, 1) }
nc('money display retains negative sign') { getPurchaseDisplay(-1000).include?('-') }
$PokemonBag.pbStoreItem(:POTION)
price = PokemonMartAdapter.new.getPrice(:POTION,true).div(2)
nc('native shop sells an item and credits the negative purse') { shop.pbSellScreen && $Trainer.money == -1000 + price && $PokemonBag.pbQuantity(:POTION) == 0 }
event = Interpreter.new
[0,1].each do |action|
  event.instance_variable_set(:@parameters,[action,0,120])
  before = $Trainer.money
  event.command_125
  ne("event cash operation #{action}",before + (action == 0 ? 120 : -120),$Trainer.money)
end
$MapFactory.setup(294)
ModeNuit.checkpoint_map
ne('map change records an idle overworld checkpoint', 294, ModeNuit.read_slot(path)[:map_id])
# A recovery rehearsal is confined to this temporary installation.
File.binwrite(path,'damaged')
File.rename(path,path + '.damaged-test')
File.binwrite(path,File.binread(path + '.nuit-secours'))
nc('native Continue opens a copied technical recovery file') { PokemonLoad.new(loader_scene).startPlayingSaveFile(path) && ModeNuit.active? && $Trainer.money == -1000 }
PokemonLoad.new(loader_scene).startPlayingSaveFile(RTP.getSaveSlotPath(2))
nc('other Story adventure loads with native IVs and difficulty') { !ModeNuit.active? && $game_variables[:DifficultyModes] == 1 && $Trainer.party.first.iv == [1,2,3,4,5,6] }
nc('Story shop and native item catalog restored') { !$cache.items.key?(:NUITMINTCASE) && ComplexPokemonMartAdapter.new([ItemStock.of(:RARECANDY)]).getStock.first.item == :RARECANDY }
# Exercise the loader's version guard in isolation on the supported engine API.
Object.send(:remove_const, :GAME_VERSION)
Object.const_set(:GAME_VERSION, 'test-incompatible')
load 'patch/Mods/zz_mode_nuit.rb'
nc('changed version refuses marked save before loading it') { !PokemonLoad.new(loader_scene).startPlayingSaveFile(path) && !ModeNuit.active? }
