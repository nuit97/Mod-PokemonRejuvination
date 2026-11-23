# Pokémon Rejuvenation 14.0.28 • Mode Nuit
if Rejuv && GAME_VERSION == '14.0.28'
  root = File.expand_path('../ModeNuit', __dir__)
  %w[rules inventory persistence battle interface].each { |name| load File.join(root, "#{name}.rb") }
elsif Rejuv && defined?(PokemonLoad) && PokemonLoad.method_defined?(:startPlayingSaveFile)
  # A later game update may still load mods. Protect marked slots from opening
  # with their rules silently disabled, while ordinary saves use the game loader.
  module ModeNuitVersionGuard
    def startPlayingSaveFile(path)
      marked = begin
        data = File.open(path, 'rb') { |file| Marshal.load(file) }
        data.is_a?(Hash) && data[:system]&.instance_variable_get(:@mode_nuit_id)
      rescue StandardError
        false
      end
      return super unless marked
      Kernel.pbMessage("Mode Nuit requires Rejuvenation 14.0.28.\nLe Mode Nuit nécessite Rejuvenation 14.0.28.")
      false
    end
  end
  PokemonLoad.prepend(ModeNuitVersionGuard)
end
