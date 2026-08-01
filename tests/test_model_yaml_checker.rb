require "open3"
require "rbconfig"
require "tempfile"

CHECKER = File.expand_path("../scripts/check-model-yaml.rb", __dir__)

def run_checker(path)
  Open3.capture3(RbConfig.ruby, CHECKER, path)
end

Tempfile.create(["valid-model", ".yml"]) do |valid|
  valid.write("semver: 2.12.2\nheader:\n  name: Fixture\n")
  valid.flush

  Tempfile.create(["malformed-model", ".yml"]) do |malformed|
    malformed.write(File.read(valid.path))
    malformed.write("broken: [\n")
    malformed.flush

    puts "1..2"

    _stdout, stderr, status = run_checker(valid.path)
    abort "valid fixture rejected: #{stderr}" unless status.success?
    puts "ok 1 - valid YAML mapping is accepted"

    _stdout, stderr, status = run_checker(malformed.path)
    abort "malformed fixture was accepted" if status.success?
    abort "malformed diagnostic omitted path: #{stderr}" unless stderr.include?(malformed.path)
    puts "ok 2 - malformed YAML is rejected with its path"
  end
end
