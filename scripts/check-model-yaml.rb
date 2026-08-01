#!/usr/bin/env ruby

require "psych"

DEFAULT_TEMPLATES = %w[
  dist/SDCARD/TEMPLATES/3.SoarEdgeTx/pocket-F3K.yml
  dist/SDCARD/TEMPLATES/3.SoarEdgeTx/pocket-F5J-XTail.yml
  dist/SDCARD/TEMPLATES/3.SoarEdgeTx/pocket-F5J-MTail.yml
  dist/SDCARD/TEMPLATES/3.SoarEdgeTx/pocket-F5J-VTail.yml
].freeze

paths = ARGV.empty? ? DEFAULT_TEMPLATES : ARGV
failed = false

paths.each do |path|
  begin
    document = Psych.safe_load(
      File.read(path),
      permitted_classes: [],
      permitted_symbols: [],
      aliases: false,
      filename: path
    )
    unless document.is_a?(Hash)
      warn "#{path}: YAML root must be a mapping"
      failed = true
    end
  rescue Psych::Exception => error
    warn "#{path}: YAML parse error: #{error.message.lines.first.strip}"
    failed = true
  rescue SystemCallError => error
    warn "#{path}: #{error.message}"
    failed = true
  end
end

exit 1 if failed
