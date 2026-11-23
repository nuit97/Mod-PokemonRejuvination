# Loaded only by tests/run.py inside a fresh, portable test installation.
def mainFunction
  path = ENV.fetch('NUIT_TEST_FILE')
  begin
    load path
    File.write("passed-#{File.basename(path)}", "OK\n")
  rescue Exception => e
    message = e.message.to_s.split("\n", 2).first.to_s[0, 220]
    File.write('nuit-failure.txt', "#{e.class}: #{message}\n#{Array(e.backtrace).take(18).join("\n")}")
    exit 1
  end
  exit
end
