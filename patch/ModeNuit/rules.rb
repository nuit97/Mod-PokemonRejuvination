module ModeNuit
  PERFECT_IVS = [31, 31, 31, 31, 31, 31].freeze unless const_defined?(:PERFECT_IVS, false)

  def self.active?
    $game_system.is_a?(Game_System) && !!$game_system.mode_nuit_id
  end

  def self.fr?
    index = $Settings.respond_to?(:language) && $Settings.language
    return false unless index.is_a?(Integer) && defined?(LANGUAGES)
    LANGUAGES.keys[index].to_s.match?(/fran[cç]ais|french/i)
  end

  def self.text(en, fr)
    fr? ? fr : en
  end

  def self.enable
    return if active?
    # An ordinary String survives Marshal and needs no mod-defined save class.
    $game_system.mode_nuit_id = Random.new.bytes(16).unpack1('H*')
    $game_system.mode_nuit_slot = $Unidata.fetch(:saveslot)
    $game_system.mode_nuit_losses = 0
    $game_system.mode_nuit_revision = 0
    @checkpoint_needed = $game_system.mode_nuit_id
    $game_variables[:DifficultyModes] = 0
    $game_switches[:All_Field_Notes] = true
    runPostPasswordMaintenance
    prepare_party_and_bag
    normalize_storage
  end

  def self.prepare_party_and_bag
    return unless active?
    if $Trainer
      $Trainer.mode_nuit_id = $game_system.mode_nuit_id
      $Trainer.party.compact.each { |mon| normalize_mon(mon) }
    end
    if $PokemonBag
      $PokemonBag.mode_nuit_prepare
    end
  end

  def self.normalize_mon(mon)
    return unless mon.is_a?(PokeBattle_Pokemon)
    mon.calcStats
    mon.item
    normalize_mon(mon.fused) if mon.fused
  end

  def self.normalize_storage
    if $PokemonStorage && $Trainer
      pbEachPokemon { |mon, box| normalize_mon(mon) if box >= 0 }
    end
    if $PokemonGlobal
      Array($PokemonGlobal.daycare).each { |entry| normalize_mon(entry[0]) if entry.is_a?(Array) }
      $PokemonGlobal.pcItemStorage&.mode_nuit_prepare
    end
  end

  module SystemState
    attr_accessor :mode_nuit_id, :mode_nuit_slot, :mode_nuit_losses, :mode_nuit_revision
  end
  module TrainerState
    attr_accessor :mode_nuit_id
    def money=(amount)
      return super unless ModeNuit.active? && equal?($Trainer)
      @money = [amount, MAXMONEY].min
    end
  end
  module VariablesLock
    def []=(id, value)
      if ModeNuit.active? && (id == :DifficultyModes || id == DifficultModes::VARIABLE)
        value = 0
      end
      super(id, value)
    end
  end
  module PokemonRules
    def calcStats
      @iv = ModeNuit::PERFECT_IVS.dup if ModeNuit.active? && @iv != ModeNuit::PERFECT_IVS
      super
    end
    def iv=(values)
      return super unless ModeNuit.active?
      @iv = ModeNuit::PERFECT_IVS.dup
    end
    def iv
      return super unless ModeNuit.active?
      @iv = ModeNuit::PERFECT_IVS.dup unless @iv == ModeNuit::PERFECT_IVS
      # Several native event/breeding scripts mutate a returned Array in place.
      # The saved ivar always remains an ordinary six-element Array.
      @iv.dup
    end
    def item=(item)
      super(ModeNuit.reward(item))
    end
    def item
      original = super
      return original unless original == :RARECANDY && ModeNuit.active?
      @item = :ULTRABALL
    end
  end
  module FieldAndPasswordRules
    def pbStartTrade(index, incoming, ...)
      ModeNuit.normalize_mon(incoming) if ModeNuit.active?
      super
    end
    def addPkmnToPartyOrPC(pokemon, ...)
      ModeNuit.normalize_mon(pokemon) if ModeNuit.active?
      super
    end
    def pbTogglePassword(...)
      return super unless ModeNuit.active?
      false
    end
    def checkSeenFields
      return super unless ModeNuit.active?
      # V14's original function also writes to the cross-save field notebook.
      (1..TOTALFIELDS).to_h { |i| [i, true] }
    end
    def pbTrainerName(...)
      result = super
      ModeNuit.prepare_party_and_bag if ModeNuit.active?
      result
    end
    def gameSetup(...)
      result = super
      if ModeNuit.active?
        ModeNuit.prepare_party_and_bag
        ModeNuit.normalize_storage
        $game_switches[:All_Field_Notes] = true
        runPostPasswordMaintenance
      end
      result
    end
    private :pbTogglePassword, :checkSeenFields, :pbTrainerName, :gameSetup, :pbStartTrade, :addPkmnToPartyOrPC
  end
  module PasswordMenu
    def pbPasswordEntry
      return super unless ModeNuit.active?
      Kernel.pbMessage(ModeNuit.text('Passwords are locked in Night Mode.', 'Les mots de passe sont verrouillés en Mode Nuit.'))
      0
    end
  end
end

Game_System.prepend(ModeNuit::SystemState)
PokeBattle_Trainer.prepend(ModeNuit::TrainerState)
Game_Variables.prepend(ModeNuit::VariablesLock)
PokeBattle_Pokemon.prepend(ModeNuit::PokemonRules)
Object.prepend(ModeNuit::FieldAndPasswordRules)
PasswordEntry.prepend(ModeNuit::PasswordMenu)
