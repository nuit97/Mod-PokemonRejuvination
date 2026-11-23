# Run only in the disposable game copy created by tests/run.py.
module NuitChecks
  def self.check(name)
    raise "FAIL: #{name}" unless yield
    File.open('nuit-results.txt', 'a') { |out| out.puts("OK #{name}") }
  end
  def self.equal(name, expected, actual)
    raise "#{name}: expected #{expected.inspect}, got #{actual.inspect}" unless expected == actual
    check(name) { true }
  end
  # Queue only the human input, animations and dialog. Rules and serialized
  # objects still pass through the normal game implementation.
  module Inputs
    attr_accessor :answers
    def pbMessage(message, choices = nil, *args, **opts)
      raise "Unexpected save error: #{message}" if message.include?('could not save') || message.include?('Écriture impossible')
      return 0 unless choices
      raise "Unexpected menu #{choices.inspect}" if !answers || answers.empty?
      answers.shift
    end
    def pbConfirmMessage(message, *args)
      raise "Unexpected prompt #{message}" if !answers || answers.empty?
      answers.shift
    end
  end
  class ItemScene
    def pbRefresh; end
    attr_accessor :selection, :labels, :message
    def pbShowCommands(_prompt, labels)
      @labels = labels
      @selection
    end
    def pbDisplay(text)
      @message = text
    end
  end
end
def nc(name, &block)
  NuitChecks.check(name, &block)
end
def ne(name, expected, actual)
  NuitChecks.equal(name, expected, actual)
end
