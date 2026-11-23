module ModeNuit
  STARTER_TOOLS = %i[HPCARD ATKCARD DEFCARD SPATKCARD SPDEFCARD SPEEDCARD MACHOBRACE NUITMINTCASE NUITEVRESET].freeze unless const_defined?(:STARTER_TOOLS, false)

  def self.reward(item)
    item == :RARECANDY && active? ? :ULTRABALL : item
  end

  module ItemCache
    def items
      base = super
      return base unless ModeNuit.active? && base
      lang = ModeNuit.fr?
      if !@nuit_base_items.equal?(base) || @nuit_item_lang != lang
        @nuit_base_items, @nuit_item_lang = base, lang
        definitions = [
          [:NUITMINTCASE, 'Mint Case', 'Boîte à Menthes', 'Choose a new nature for a Pokémon. Reusable.', 'Choisit la véritable nature d’un Pokémon. Réutilisable.', 'seriousmint'],
          [:NUITEVRESET, 'EV Resetter', "Réinitialiseur d’EV", 'Reset all six EVs of a Pokémon. Reusable.', 'Remet à zéro les six EV d’un Pokémon. Réutilisable.', 'hpup']
        ]
        @nuit_items = base.dup
        definitions.each do |id, en, fr, detail_en, detail_fr, icon|
          name = lang ? fr : en
          @nuit_items[id] = ItemData.new(id, {name: name, plural: name,
            desc: lang ? detail_fr : detail_en, image: icon, price: 0,
            keyitem: true, noUseInBattle: true, noArticle: true})
        end
      end
      @nuit_items
    end
  end

  module Bag
    def pbStoreItem(item, qty = 1)
      super(ModeNuit.reward(item), qty)
    end
    def pbCanStore?(item, qty = 1)
      super(ModeNuit.reward(item), qty)
    end
    def mode_nuit_prepare
      return if $game_switches[:NotPlayerCharacter]
      count = pbQuantity(:RARECANDY)
      if count > 0
        capacity = [BAGMAXPERSLOT - pbQuantity(:ULTRABALL), 0].max
        in_bag = [capacity, count].min
        pbStoreItem(:ULTRABALL, in_bag) if in_bag > 0
        # Retain any overflow for the next withdrawal, without exceeding the native bag limit.
        @mode_nuit_ball_overflow = (@mode_nuit_ball_overflow || 0) + count - in_bag
        pbDeleteItem(:RARECANDY, count)
      end
      return if @mode_nuit_equipped
      ModeNuit::STARTER_TOOLS.each { |id| pbStoreItem(id) unless pbHasItem?(id) }
      @mode_nuit_equipped = true
    end
    def pbDeleteItem(item, qty = 1)
      result = super
      if result && item == :ULTRABALL && ModeNuit.active? && @mode_nuit_ball_overflow.to_i > 0
        n = [BAGMAXPERSLOT - pbQuantity(:ULTRABALL), @mode_nuit_ball_overflow].min
        pbStoreItem(:ULTRABALL, n) if n > 0
        @mode_nuit_ball_overflow -= n
      end
      result
    end
  end

  module WalkRewards
    def pbItemBall(item, quantity = 1)
      super(ModeNuit.reward(item), quantity)
    end
    def pbReceiveItem(item, quantity = 1)
      super(ModeNuit.reward(item), quantity)
    end
  end

  module ItemPC
    def mode_nuit_prepare
      # Native storage supports several stacks of the same item.
      @items.each { |stack| stack[0] = :ULTRABALL if stack && stack[0] == :RARECANDY }
    end
    def pbCanStore?(item, qty = 1)
      super(ModeNuit.reward(item), qty)
    end
    def pbStoreItem(item, qty = 1)
      super(ModeNuit.reward(item), qty)
    end
  end

  module Shop
    def initialize(inventory)
      if ModeNuit.active?
        inventory = inventory.map do |stock|
          next stock unless stock.is_a?(ItemStock) && stock.item == :RARECANDY
          # Work on a copy: native mart definitions are shared by all saves.
          replacement = stock.dup
          replacement.instance_variable_set(:@price, stock.price)
          replacement.instance_variable_set(:@item, :ULTRABALL)
          replacement
        end
      end
      super(inventory)
    end
  end

  def self.apply_mint(pokemon, nature)
    pokemon.natureflag = nil
    pokemon.nature = nature # V14 writes the stored nature, then recalculates once.
  end

  def self.mint_options
    $cache.natures.select { |id, n| id == :SERIOUS || (n.incStat && n.decStat && n.incStat != n.decStat) }.keys
  end

  def self.choose_mint(pokemon, scene)
    choices = mint_options
    labels = choices.map do |id|
      n = $cache.natures.fetch(id)
      if id == :SERIOUS
        "#{getNatureName(id)} (#{text('neutral', 'neutre')})"
      else
        "#{getNatureName(id)} (+#{getStatName(n.incStat, :supershort)} / -#{getStatName(n.decStat, :supershort)})"
      end
    end
    i = scene.pbShowCommands(text("Choose #{pokemon.name}'s nature.", "Choisis la nature de #{pokemon.name}."), labels)
    return false unless i && i >= 0 && i < choices.length
    apply_mint(pokemon, choices[i])
    scene.pbDisplay(text("#{pokemon.name}'s nature is now #{getNatureName(pokemon.nature)}.", "Nouvelle nature de #{pokemon.name} : #{getNatureName(pokemon.nature)}."))
    true
  end
end

Cache_Game.prepend(ModeNuit::ItemCache)
PokemonBag.prepend(ModeNuit::Bag)
PCItemStorage.prepend(ModeNuit::ItemPC)
Kernel.singleton_class.prepend(ModeNuit::WalkRewards)
ComplexPokemonMartAdapter.prepend(ModeNuit::Shop)
ItemHandlers::UseOnPokemon.add(:NUITMINTCASE, proc { |_item, pokemon, scene|
  next false unless ModeNuit.active?
  ModeNuit.choose_mint(pokemon, scene)
})
ItemHandlers::UseOnPokemon.add(:NUITEVRESET, proc { |_item, pokemon, scene|
  next false unless ModeNuit.active?
  pokemon.ev = [0, 0, 0, 0, 0, 0]
  pokemon.calcStats
  scene.pbDisplay(ModeNuit.text("#{pokemon.name}'s six EVs are now zero.", "Les six EV de #{pokemon.name} sont à zéro."))
  true
})
