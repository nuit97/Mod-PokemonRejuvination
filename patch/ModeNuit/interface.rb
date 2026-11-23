module ModeNuit
  # Entries verified against Map228, Map254, Map389 and Map516 in 14.0.28.
  PRACTICE = {[228, 7] => 'Lemmi', [254, 45] => 'Philip', [389, 15] => 'Miikal', [516, 115] => 'Philip'}.freeze unless const_defined?(:PRACTICE, false)

  def self.choose_difficulty
    return if active?
    loop do
      choices = [_INTL('Story'), _INTL('Classic'), text('Night Mode', 'Mode Nuit')]
      i = Kernel.pbMessage(text('Choose a difficulty.', 'Choisis une difficulté.'), choices, 0, nil, 1)
      unless i == 2
        $game_variables[:DifficultyModes] = (i == 0 ? 1 : 0)
        return
      end
      Kernel.pbMessage(text('Classic battles with Set style and no Bag against trainers. Every Pokémon has six perfect IVs. Your EV and nature tools are reusable.',
        'Combats Classic en mode Défini, sac fermé contre les dresseurs. Tous les Pokémon ont six IV parfaits. Les outils de nature et d’EV sont réutilisables.'))
      next unless Kernel.pbConfirmMessage(text('Defeats are saved and can make your balance negative. Difficulty and passwords are permanently locked. Start Night Mode?',
        'Les défaites sont sauvegardées et ton solde peut devenir négatif. Difficulté et mots de passe seront définitivement verrouillés. Commencer en Mode Nuit ?'))
      enable
      return
    end
  end
  module IntroEvents
    # Keep the original event and indices intact. Only the introduction's
    # difficulty picture is substituted; the stock event resumes immediately.
    def command_231
      if @map_id == 1 && @event_id == 1 && @index == 10 && @parameters[1] == 'Difficulty_1' &&
         @list[93]&.parameters == ['postdifficulty']
        ModeNuit.choose_difficulty
        @index = ModeNuit.active? ? 95 : 94
        return true
      end
      super
    end
    def command_101
      if ModeNuit.active? && @map_id == 1 && @event_id == 1 && @index == 1295 &&
         @list[1298]&.parameters&.first == ['No', 'Password'] && @list[1376]&.parameters == ['pw end']
        # Same branch as answering No. Both surrounding switch clears still run.
        @index = 1373
        return true
      end
      super
    end
    def setup(list, event_id, map_id = nil)
      if ModeNuit.active? && list && event_id != 0
        npc = ModeNuit::PRACTICE[[map_id || $game_map&.map_id, event_id]]
        closed = npc && (npc != 'Lemmi' || $game_system.instance_variable_get(:@nuit_lemmi_won))
        if closed && list.any? { |c| c.code == 111 && c.parameters[1].to_s.include?(%Q{"#{npc}"}) }
          msg = ModeNuit.text('This repeatable EXP training is closed in Night Mode.', 'Cet entraînement répétable d’EXP est fermé en Mode Nuit.')
          list = [RPG::EventCommand.new(101, 0, [msg]), RPG::EventCommand.new]
        end
        if equal?($game_system.map_interpreter) && ModeNuit.stable_map? &&
           list.any? { |command| [111, 355, 655].include?(command.code) &&
             command.parameters.any? { |part| part.is_a?(String) && part.match?(/\bpb(?:DoubleTrainer|Trainer|Wild|DoubleWild)Battle\b/) } }
          ModeNuit.required_write { ModeNuit.save_game }
        end
      end
      super(list, event_id, map_id)
    end
  end
  module PracticeResult
    def pbTrainerBattle(trainerid, trainername, ...)
      won = super
      if won && ModeNuit.active? && trainerid == :POKEBREEDER_F && trainername == 'Lemmi' && $game_map.map_id == 228
        $game_system.instance_variable_set(:@nuit_lemmi_won, true)
      end
      won
    end
    private :pbTrainerBattle
  end
  module Options
    def initOptions
      options = super
      return options unless ModeNuit.active? && $game_map
      hidden = ['Difficulty Selection', 'Battle Style', 'Backup Saves', 'Max Backup Number'].map { |s| _INTL(s) }
      options.reject { |option| option.respond_to?(:name) && hidden.include?(option.name) }
    end
  end
  module LoadPanel
    def addTitleAndMapName(mapname, positions)
      start = positions.length
      super
      if @trainer&.mode_nuit_id
        slot = @title.to_s[/\d+$/]
        title = ["☾ MODE NUIT", slot].compact.join(" · ")
        positions[start] = [title, *positions[start].drop(1).take(3), Color.new(194, 205, 255), Color.new(52, 48, 105)]
      end
    end
  end
  module SlotLabels
    def saveinfo(path)
      unless File.file?(path)
        folder = RTP.getSaveFolder
        tail = path.delete_prefix(folder)
        path = File.join(folder, tail) if tail != path && tail.match?(/\AGame(?:_\d+)?\.rxdata\z/)
      end
      text = super(path)
      # Only slot browsing (never the per-frame draw path).
      data = File.open(path, 'rb') { |f| Marshal.load(f) }
      data.is_a?(Hash) && data[:Trainer].respond_to?(:mode_nuit_id) && data[:Trainer].mode_nuit_id ? " ☾ MODE NUIT#{text}" : text
    rescue StandardError
      text
    end
    private :saveinfo
  end
  module SavePanel
    def pbStartScreen
      super
      if ModeNuit.active?
        window = @sprites.fetch('locwindow')
        label = "<ac>☾ MODE NUIT</ac><br>" + window.text
        window.resizeHeightToFit(label, window.width)
        window.text = label
      end
    end
  end
end
Interpreter.prepend(ModeNuit::IntroEvents)
Object.prepend(ModeNuit::PracticeResult)
PokemonOptionScene.prepend(ModeNuit::Options)
PokemonLoadPanel.prepend(ModeNuit::LoadPanel)
PokemonSaveScene.prepend(ModeNuit::SavePanel)
Object.prepend(ModeNuit::SlotLabels)
