module ModeNuit
  # The active file is always a normal Rejuvenation Marshal hash. The recovery
  # copy has a different suffix so the native slot picker cannot select it.
  def self.slot_path
    slot = $game_system.mode_nuit_slot
    raise IOError, 'Mode Nuit: unexpected save slot' unless slot.is_a?(Integer) && slot > 0 && slot == $Unidata[:saveslot]
    RTP.getSaveSlotPath(slot)
  end

  def self.read_slot(path)
    data = File.open(path, 'rb') { |f| Marshal.load(f) }
    raise IOError, 'Mode Nuit: different adventure in this slot' unless data.is_a?(Hash) && data[:system]&.mode_nuit_id == $game_system.mode_nuit_id
    data
  end

  def self.install_snapshot
    path = slot_path
    key = "#{Process.pid}-#{Random.new.bytes(8).unpack1('H*')}"
    stage = "#{path}.#{key}.tmp"
    rescue_stage = "#{stage}.backup"
    # Coordinate two processes that happen to open the same active file.
    File.open("#{path}.nuit-lock", File::RDWR | File::CREAT, 0600) do |lock|
      raise IOError, 'Mode Nuit: save in use' unless lock.flock(File::LOCK_EX | File::LOCK_NB)
      old = File.file?(path) ? read_slot(path) : nil
      previous_revision = $game_system.mode_nuit_revision.to_i
      if old && old[:system].mode_nuit_revision.to_i != previous_revision
        raise IOError, 'Mode Nuit: another game window changed this save'
      end
      next_revision = previous_revision + 1
      yield(stage, old, next_revision)
      raise IOError, 'Mode Nuit: incomplete checkpoint' unless read_slot(stage)[:system].mode_nuit_revision == next_revision
      File.open(stage, 'r+b', &:fsync)
      if old
        File.open(path, 'rb') do |input|
          File.open(rescue_stage, 'wb') do |out|
            IO.copy_stream(input, out)
            out.fsync
          end
        end
        File.rename(rescue_stage, "#{path}.nuit-secours")
      end
      File.rename(stage, path)
      $game_system.mode_nuit_revision = next_revision
    end
    true
  ensure
    [stage, rescue_stage].compact.each { |p| File.delete(p) if File.file?(p) }
  end

  def self.save_game
    $Trainer.mode_nuit_id = $game_system.mode_nuit_id
    install_snapshot do |temp, _old, next_revision|
      previous_revision = $game_system.mode_nuit_revision
      begin
        $game_system.mode_nuit_revision = next_revision
        raise IOError, 'Rejuvenation saveNew failed' unless saveNew(temp)
      ensure
        $game_system.mode_nuit_revision = previous_revision
      end
    end
    @checkpoint_needed = nil
    @last_map = $game_map.map_id
    @last_adventure = $game_system.mode_nuit_id
    true
  end

  # A failure remains visible and a retry uses the same operation. No menu or
  # combat result is returned while a mandatory outcome is still uncommitted.
  def self.required_write
    loop do
      begin
        return yield
      rescue IOError, SystemCallError, ArgumentError, TypeError => e
        msg = text("Night Mode could not save. Check free space and close other windows.\n#{e.message}",
                   "Écriture impossible. Vérifie l’espace libre et ferme les autres fenêtres.\n#{e.message}")
        choice = Kernel.pbMessage(msg, [text('Retry', 'Réessayer'), text('Quit game', 'Quitter le jeu')], 0)
        exit if choice == 1
      end
    end
  end

  def self.before_battle
    # An ongoing scripted sequence can own temporary parties and interpreter
    # state. Prefer its preceding map checkpoint to serializing it in mid-call.
    if !File.file?(slot_path) || !pbMapInterpreterRunning?
      required_write { save_game }
    end
  end

  def self.commit_defeat(loss)
    after = $Trainer.money - loss
    serial = $game_system.mode_nuit_losses.to_i + 1
    required_write do
      install_snapshot do |temp, data, next_revision|
        raise IOError, 'Missing pre-battle checkpoint' unless data
        # A scripted guest has a different purse. Never copy it to the hero.
        unless $game_switches[:NotPlayerCharacter]
          if data[:switches][:NotPlayerCharacter]
            backup = data[:variable][:PlayerDataBackup]
            backup[1] = after if backup.is_a?(Array) && backup[1].is_a?(Numeric)
          else
            data.fetch(:Trainer).instance_variable_set(:@money, after)
          end
        end
        data.fetch(:system).mode_nuit_losses = serial
        data[:system].mode_nuit_revision = next_revision
        File.open(temp, 'wb') { |f| Marshal.dump(data, f) }
      end
    end
    $Trainer.money = after
    $game_system.mode_nuit_losses = serial
    @checkpoint_needed = $game_system.mode_nuit_id
  end

  def self.checkpoint_needed?
    active? && $game_map && (@checkpoint_needed == $game_system.mode_nuit_id ||
      @last_adventure != $game_system.mode_nuit_id || @last_map != $game_map.map_id)
  end

  def self.stable_map?
    $Trainer && $game_map && $game_map.map_id != 1 && $scene.is_a?(Scene_Map) &&
      !$game_temp.in_battle && !$game_temp.player_transferring && !$PokemonTemp.miniupdate &&
      !$game_system.save_disabled && !$game_player.move_route_forcing && !$game_switches[:Starting_Over] &&
      !pbMapInterpreterRunning?
  end

  def self.checkpoint_map
    required_write { save_game } if checkpoint_needed? && stable_map?
  end

  module Saving
    def pbSave
      return super unless ModeNuit.active?
      ModeNuit.save_game
    rescue IOError, SystemCallError, TypeError, ArgumentError => e
      raise unless ModeNuit.active?
      Kernel.pbMessage(ModeNuit.text("Save failed: #{e.message}", "Échec de la sauvegarde : #{e.message}"))
      false
    end
    def pbHandleSave(quick: false, confirm: true, cancancel: true)
      return super unless ModeNuit.active?
      if confirm
        options = [_INTL('Save')]
        options << _INTL("Don't Save") if cancancel
        i = Kernel.pbMessage(ModeNuit.text('Save this Night Mode adventure?', 'Sauvegarder cette partie Mode Nuit ?'), options, cancancel ? -1 : 0)
        return :Cancelled unless i == 0
      end
      super(quick: quick, confirm: false, cancancel: cancancel)
    end
    def pbEmergencySave
      return super unless ModeNuit.active?
      # During battle the last valid map + the committed loss is the safe recovery point.
      return if $game_temp.in_battle
      pbSave
    end
    private :pbSave, :pbHandleSave, :pbEmergencySave
  end
  module MapCheckpoint
    def updateSpritesets(...)
      result = super
      ModeNuit.checkpoint_map if $scene.equal?(self)
      result
    end
  end
end
Object.prepend(ModeNuit::Saving)
Scene_Map.prepend(ModeNuit::MapCheckpoint)
