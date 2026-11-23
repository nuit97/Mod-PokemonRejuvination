require_relative "support"
raise 'Expected isolated portable save folder' unless File.file?('Save Data/.portable') && ENV['NUIT_TEST_FILE']
File.write('nuit-results.txt', "")
Kernel.singleton_class.prepend(NuitChecks::Inputs)
# The stock logger records and swallows battle exceptions. Make them fail CI.
PBDebug.define_singleton_method(:logonerr) { |&action| action.call }
$Settings = PokemonOptions.new
if ENV['NUIT_TEST_LANG'] == 'fr'
  # An ordinary player reaches Language after the startup hooks have settled.
  300.times { break if respond_to?(:_orig_pbLoadLanguage_fr, true); sleep 0.01 }
  $Settings.language = 1
  pbLoadLanguage
  raise 'RejuvFR missing or unavailable' unless LANGUAGES.keys[1] == 'Francais'
  nc('real RejuvFR catalog and French mode strings') { ModeNuit.fr? && _INTL('New Game') != 'New Game' && ModeNuit.text('Night Mode','Mode Nuit') == 'Mode Nuit' }
end
$Unidata = {saveslot: 1}
Graphics.time_passed = 0
Graphics.start_playing = Process.clock_gettime(Process::CLOCK_MONOTONIC)
$game_temp = Game_Temp.new
$PokemonTemp = PokemonTemp.new
$game_system = Game_System.new
$game_switches = Game_Switches.new
$game_variables = Game_Variables.new
$game_self_switches = Game_SelfSwitches.new
$game_screen = Game_Screen.new
$game_player = Game_Player.new
$PokemonMap = PokemonMapMetadata.new
$PokemonGlobal = PokemonGlobalMetadata.new
$PokemonBag = PokemonBag.new
$PokemonStorage = PokemonStorage.new
$PokemonEncounters = PokemonEncounters.new
$MapFactory = PokemonMapFactory.new
$scene = Scene_Map.new
$MapFactory.setup(1)
player_type = $cache.trainertypes.keys.find { |id| $cache.trainertypes[id].checkFlag?(:player) }
$Trainer = PokeBattle_Trainer.new('Nuit', player_type)
nc('exact V14 and native engine') { GAME_VERSION == '14.0.28' && defined?(Graphics) && $cache.pkmn.size > 1000 }
ne('Classic and Story start with stock items', nil, $cache.items[:NUITMINTCASE])
refreshLevelCaps
classic_caps = LEVELCAPS.dup
$game_variables[:DifficultyModes] = 1
ne('Story difficulty is writable', 1, $game_variables[:DifficultyModes])
$Trainer.money = -100
ne('Classic/Story keep base money floor', 0, $Trainer.money)
original = PokeBattle_Pokemon.new(:EEVEE, 50)
original.iv = [1, 2, 3, 4, 5, 6]
original.calcStats
ne('Classic IVs and native setter', [1, 2, 3, 4, 5, 6], original.iv)
$Trainer.party << original
$Unidata[:saveslot] = 2
raise 'Could not save comparison Story slot' unless saveNew(RTP.getSaveSlotPath(2))
File.binwrite('story-baseline',File.binread(RTP.getSaveSlotPath(2)))
$Unidata[:saveslot] = 1
$PokemonBag.pbStoreItem(:RARECANDY, 4)
pc = $PokemonGlobal.pcItemStorage = PCItemStorage.new
pc.pbStoreItem(:RARECANDY, 3)
boxed = PokeBattle_Pokemon.new(:DITTO, 22)
boxed.item = :RARECANDY
$PokemonStorage[0,0] = boxed
baseline_team = pbLoadTrainer(:POKEBREEDER_F, 'Lemmi', 0)[2].map { |p| [p.species, p.level, p.ev.dup, p.moves.map(&:move)] }
intro = load_data('Data/Map001.rxdata').events.fetch(1).pages.first.list
nc('introduction selector anchor') { intro[10].parameters[1] == 'Difficulty_1' && intro[93].parameters == ['postdifficulty'] }
selector = Interpreter.new
selector.setup(intro, 1, 1)
selector.instance_variable_set(:@index, 10)
selector.instance_variable_set(:@parameters, intro[10].parameters)
Kernel.answers = [0]
selector.command_231
ne('Story remains selectable in real intro event', 1, $game_variables[:DifficultyModes])
selector.instance_variable_set(:@index, 10)
Kernel.answers = [2, false, 1]
selector.command_231
nc('cancel irreversible selection and choose Classic') { !ModeNuit.active? && $game_variables[:DifficultyModes] == 0 }
selector.instance_variable_set(:@index, 10)
Kernel.answers = [2, true]
selector.command_231
nc('third choice activates on real intro event') { ModeNuit.active? && selector.instance_variable_get(:@index) == 95 && $game_system.mode_nuit_slot == 1 }
refreshLevelCaps
ne('same native badge level caps as Classic',classic_caps,LEVELCAPS)
perfect = [31] * 6
ne('normalize existing party', perfect, original.iv)
ne('normalize already stored Pokémon', perfect, boxed.instance_variable_get(:@iv))
ne('convert held pre-existing Rare Candy', :ULTRABALL, boxed.item)
ne('convert existing bag stock', [0,4], [:RARECANDY,:ULTRABALL].map { |i| $PokemonBag.pbQuantity(i) })
ne('convert existing PC stock', [0,3], [:RARECANDY,:ULTRABALL].map { |i| pc.pbQuantity(i) })
ModeNuit::STARTER_TOOLS.each { |id| ne("starter item #{id}", 1, $PokemonBag.pbQuantity(id)) }
ModeNuit.prepare_party_and_bag
nc('duplicate initialization grants no extra items') { ModeNuit::STARTER_TOOLS.all? { |i| $PokemonBag.pbQuantity(i) == 1 } }
$game_variables[200] = 1
$game_variables[:DifficultyModes] = 1
ne('difficulty locked by index and symbol', 0, $game_variables[200])
nc('password entry and toggle blocked') { !pbTogglePassword('emptyivs') && PasswordEntry.allocate.pbPasswordEntry == 0 && !$game_switches[:Empty_IVs_Password] }
selector.instance_variable_set(:@index, 1295)
selector.command_101
ne('intro password branch returns to cleanup', 1373, selector.instance_variable_get(:@index))
nc('field app and every compiled field switch') { $game_switches[:Field_Notes] && $cache.FEData.values.all? { |f| !f.fieldAppSwitch || $game_switches[f.fieldAppSwitch] } }
nc('all published fields visible without cross-slot unlock') { Scene_FieldNotes.new.buildFieldMenu.none? { |entry| entry[:label].to_s.include?('???') } && $Unidata[:fieldNotes].nil? }
nc('no conditional field-note text hidden') { $cache.FENotes.none?(&:condition) }
wild = pbGenerateWildPokemon(:RATTATA, 8)
ne('wild Pokémon through encounter generator', perfect, wild.iv)
egg = pbGenerateEgg(:EEVEE)
nc('egg creation with real IVs') { egg.isEgg? && egg.instance_variable_get(:@iv) == perfect }
pbAddPokemonSilent(:PIDGEY, 7, true, [0]*6)
ne('scripted gift specifying six zero IVs', perfect, $Trainer.party.last.instance_variable_get(:@iv))
wild.iv[5] = 0
wild.iv = [0]*6
wild.calcStats
ne('IV mutations resisted after recalculation', perfect, wild.instance_variable_get(:@iv))
opp, items, team = pbLoadTrainer(:POKEBREEDER_F, 'Lemmi', 0)
ne('original Classic team, moves, levels and EVs', baseline_team, team.map { |p| [p.species, p.level, p.ev.dup, p.moves.map(&:move)] })
nc('trainer Pokémon all have perfect IVs') { team.all? { |p| p.instance_variable_get(:@iv) == perfect } }
nc('legendary with six IVs') { PokeBattle_Pokemon.new(:MEWTWO,75).iv == perfect }
boss_id = $cache.bosses.keys.find { |id| $cache.bosses[id].moninfo && $cache.bosses[id].moninfo[:species] } rescue nil
boss_id ||= $cache.bosses.keys.first
boss = pbGenerateWildPokemon(boss_id, 50)
nc('scripted boss builder preserves boss and six IVs') { boss.isbossmon && boss.iv == perfect }
# Bypass only the screen transition and animation for the trade.
module TestTradeAnimation
  def pbFadeOutInWithMusic(...)
    return if Thread.current[:nuit_test_trade]
    super
  end
end
Object.prepend(TestTradeAnimation)
trade = PokeBattle_Pokemon.new(:ABRA, 12)
trade.instance_variable_set(:@iv, [2]*6)
Thread.current[:nuit_test_trade] = true
pbStartTrade($Trainer.party.length-1, trade, 'Psi', 'Nyu')
Thread.current[:nuit_test_trade] = nil
nc('native NPC trade normalizes received existing Pokemon') { $Trainer.party.last.equal?(trade) && trade.obtainMode == 2 && trade.instance_variable_get(:@iv) == perfect }
terminals = load_data('Data/Map294.rxdata').events
(52..57).each do |id|
  cmd = terminals.fetch(id).pages.flat_map(&:list).find { |c| c.code == 111 && c.parameters[1].to_s.include?('CARD)>0') }
  nc("EV room card activates compiled terminal #{id}") { cmd && eval(cmd.parameters[1]) }
end
scene = NuitChecks::ItemScene.new
nc('two reusable native key items') { [:NUITMINTCASE,:NUITEVRESET].all? { |id| pbIsImportantItem?(id) && pbGetPocket(id) == 8 } }
ne('localized item label through real bag API', ModeNuit.fr? ? 'Boîte à Menthes' : 'Mint Case', getItemName(:NUITMINTCASE))
nc('localized item description through real bag API') { getItemDescription(:NUITEVRESET).include?(ModeNuit.fr? ? 'Réutilisable' : 'Reusable') }
ne('twenty-one distinct mint effects', 21, ModeNuit.mint_options.size)
original.natureflag = :MODEST
original.ev = [50,0,100,150,100,110]
original.calcStats
before_stats = original.getStats
nc('use EV reset through party interface') { pbUseItemOnPokemon(:NUITEVRESET, original, scene) }
nc('all six EVs reset, stats recalculated, key item kept') { original.ev == [0]*6 && original.getStats != before_stats && $PokemonBag.pbQuantity(:NUITEVRESET) == 1 }
keep = original.nature
scene.selection = -1
nc('cancel mint menu keeps nature') { !pbUseItemOnPokemon(:NUITMINTCASE, original, scene) && original.nature == keep }
ModeNuit.mint_options.each_with_index do |id, index|
  scene.selection = index
  used = pbUseItemOnPokemon(:NUITMINTCASE, original, scene)
  nc("real mint #{id}") { used && original.nature == id && original.natureflag.nil? && original.instance_variable_get(:@nature) == id && scene.labels.size == 21 }
end
# Exercise the full Bag -> party -> nature route. Only rendering and
# selections are replaced; PokemonScreen and pbUseItem are the game's own.
class TestPartyUI < NuitChecks::ItemScene
  def pbStartScene(*); end
  def pbSetHelpText(*); end
  def pbEndScene; end
  def pbChoosePokemon(**)
    return -1 if @selected
    @selected = true
    0
  end
  def pbShowCommands(_prompt, labels, *)
    ModeNuit.mint_options.index(:BOLD)
  end
end
module TestPartyFactory
  def new(...)
    return TestPartyUI.new if Thread.current[:nuit_test_bag]
    super
  end
end
PokemonScreen_Scene.singleton_class.prepend(TestPartyFactory)
Thread.current[:nuit_test_bag] = true
begin
  original.ev = [20]*6
  pbUseItem($PokemonBag,:NUITEVRESET)
  pbUseItem($PokemonBag,:NUITMINTCASE)
ensure
  Thread.current[:nuit_test_bag] = nil
end
nc('bag menu selects a party member and uses reusable key items') { original.ev == [0]*6 && original.nature == :BOLD && $PokemonBag.pbQuantity(:NUITEVRESET) == 1 }
ne('case remains after 21 uses', 1, $PokemonBag.pbQuantity(:NUITMINTCASE))
$PokemonBag.pbStoreItem(:RARECANDY, 2)
ne('new bag distribution converted', 6, $PokemonBag.pbQuantity(:ULTRABALL))
pc.pbStoreItem(:RARECANDY, 2)
ne('new PC distribution converted', 5, pc.pbQuantity(:ULTRABALL))
$PokemonBag.pbStoreItem(:EXPCANDYXS, 1)
ne('EXP candy retains its identity', 1, $PokemonBag.pbQuantity(:EXPCANDYXS))
wild.item = :RARECANDY
ne('held drop converted', :ULTRABALL, wild.item)
apstock = ItemStock.of(:RARECANDY).costs(6,:AP)
cashstock = ItemStock.of(:RARECANDY).costs(30000)
native_ball = ItemStock.of(:ULTRABALL)
mart = ComplexPokemonMartAdapter.new([apstock,cashstock,native_ball])
ne('replacement shop goods keep both prices and currencies',
   [[:ULTRABALL,6,:AP],[:ULTRABALL,30000,:Money],[:ULTRABALL,native_ball.price,:Money]],
   mart.getStock.map { |i| [i.item,i.price,i.currency] })
count_before = $PokemonBag.pbQuantity(:ULTRABALL)
nc('map item pickup and event gift award Ultra Balls') { Kernel.pbItemBall(:RARECANDY) && Kernel.pbReceiveItem(:RARECANDY,2) && $PokemonBag.pbQuantity(:ULTRABALL) == count_before + 3 }
ne('shared shop definition unchanged', :RARECANDY, apstock.item)
opts = PokemonOptionScene.new.initOptions.reject { |o| o.is_a?(String) }.map(&:name)
nc('Nuit hides battle style, difficulty and backup choices') { ['Difficulty Selection','Battle Style','Backup Saves','Max Backup Number'].none? { |s| opts.include?(_INTL(s)) } }
nc('comfort settings remain accessible') { opts.size > 25 }
ModeNuit::PRACTICE.each do |(id, ev), name|
  pages = load_data(format('Data/Map%03d.rxdata',id)).events.fetch(ev).pages
  pages.each_with_index do |page, n|
    next unless page.list.any? { |c| c.code == 111 && c.parameters[1].to_s.include?(%Q{"#{name}"}) }
    ip = Interpreter.new
    ip.setup(page.list, ev, id)
    if name == 'Lemmi'
      nc('mixed trainer first battle available') { ip.instance_variable_get(:@list).equal?(page.list) }
      $game_system.instance_variable_set(:@nuit_lemmi_won, true)
      ip.setup(page.list, ev, id)
    end
    closed = ip.instance_variable_get(:@list)
    nc("targeted trainer event #{id}/#{ev}/#{n}") { closed.size == 2 && closed.first.code == 101 && closed.last.code == 0 }
    ip.setup(page.list, ev+1, id)
    nc("neighbor #{id}/#{ev+1}/#{n} untouched") { ip.instance_variable_get(:@list).equal?(page.list) }
  end
end

require_relative "battle_support"
enemy_type = test_enemy_type
battle_scene = NuitBattleScreen.new
b = PokeBattle_Battle.new(battle_scene, [$Trainer.party], [team], $Trainer, opp)
wild_b = PokeBattle_Battle.new(battle_scene, [$Trainer.party], [[wild]], $Trainer, nil)
nc('trainer item registration blocked on both sides') { !b.pbRegisterItem(0,:POTION,0) && !b.pbRegisterItem(1,:POTION,1) && b.pbEnemyUseItem(:POTION,nil) == 0 }
actual_bag_scene = PokeBattle_Scene.allocate
actual_bag_scene.instance_variable_set(:@battle,b)
ne('trainer Bag menu returns normal cancel shape', [nil,-1], actual_bag_scene.pbItemMenu(0))
wild_b.battlers[0].pbInitPokemon(original,0)
wild_b.battlers[1].pbInitPokemon(wild,0)
nc('wild potion can be registered') { wild_b.pbRegisterItem(0,:POTION,0) }
nc('normal ball targeting permits a live wild Pokémon') { ItemHandlers.checkUseInBattle(:POKEBALL, wild_b.battlers[0], battle_scene) }
original.ev = [0]*6
wild_b.pbGainEvs(original,1)
ne('ordinary battle EV yield', wild_b.battlers[1].evYield, original.ev)
original.ev = [252,252,0,0,0,5]
wild_b.pbGainEvs(original,1)
wild_b.pbGainEvs(original,1)
ne('native 510 total limit', 510, original.ev.sum)
original.ev = [0,0,0,0,0,251]
wild_b.pbGainEvs(original,1)
wild_b.pbGainEvs(original,1)
ne('native 252 individual limit', 252, original.ev[5])
original.item = :MACHOBRACE
original.ev = [0]*6
wild_b.pbGainEvs(original,1)
ne('accelerated training with native Macho Brace', wild_b.battlers[1].evYield.map { |n| 8*n }, original.ev)
original.item = nil
held = wild_b.battlers[0]
held.hp = 1
recover = PokeBattle_Move.pbFromPBMove(wild_b, PBMove.new(:RECOVER), held.pokemon)
recover.pbEffect(held,[held])
nc('Recover restores HP through the native move') { held.hp > 1 }
held.item = :SITRUSBERRY
held.hp = 1
held.pbBerryHerbCheck
nc('held berry consumed and recovers HP in battle') { held.hp > 1 && held.item.nil? }
regen = PokeBattle_Pokemon.new(:SLOWPOKE,25)
regen.ability = :REGENERATOR
held.pbInitPokemon(regen,0)
held.hp = 1
held.pbInitialize(original,0,false)
nc('Regenerator heals departing Pokemon') { regen.hp > 1 }
nc('native wild capture places Pokemon in party') { wild_b.pbThrowPokeBall(1,:MASTERBALL) && $Trainer.party.include?(wild) && wild.iv == [31]*6 }
original.hp = 0
$PokemonBag.pbStoreItem(:REVIVE)
nc('ordinary revive usable outside battle') { pbUseItemOnPokemon(:REVIVE, original, scene) && original.hp > 0 }

$Trainer.money = 500
loser = test_mon(:MAGIKARP,1,:SPLASH)
loser.natureflag = nil
ModeNuit.apply_mint(loser,:TIMID)
winner = test_mon(:MEWTWO,25,:PSYSTRIKE)
battle, screen = duel(loser,winner,enemy_type)
ne('expected trainer award in first duel', 2500, ModeNuit.prize(battle))
$game_temp.in_battle = true
ne('engine finishes trainer loss', 2, battle.pbStartBattle(true))
$game_temp.in_battle = false
ne('loss creates real negative balance', -2000, $Trainer.money)
path = ModeNuit.slot_path
head = ModeNuit.read_slot(path)
ne('defeat written before return to overworld', [-2000,1], [head[:Trainer].money,head[:system].mode_nuit_losses])
ne('no native second blackout debit', 1, $game_system.mode_nuit_losses)
ne('Set style enforced by replacement routine', false, battle.shiftStyle)
nc('AI did not consume its potion') { battle.items.include?(:POTION) }
ne('mint, IVs and adventure id in serialized game', [:TIMID,[31]*6,$game_system.mode_nuit_id],
   [head[:Trainer].party.first.nature,head[:Trainer].party.first.iv,head[:Trainer].mode_nuit_id])
nc('native slot label identifies adventure') { saveinfo(path).include?('MODE NUIT') }
File.write('adventure-id', $game_system.mode_nuit_id)
