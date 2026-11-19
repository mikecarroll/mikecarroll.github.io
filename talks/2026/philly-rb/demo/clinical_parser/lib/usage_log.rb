# lib/usage_log.rb — a squishling.squawk collector shared by the bin/run_*
# scripts. Writes one JSON line per LLM attempt (model, usage, pass/fail
# metadata) to a file, tagged with the fixture currently being processed via
# Thread.current, so a run's per-fixture token counts can be reconstructed
# and costed out afterward instead of only showing a final pass rate.
require "fileutils"
require "json"

module UsageLog
  def self.open(path)
    FileUtils.mkdir_p(File.dirname(path))
    file = File.open(path, "w")
    yield file
  ensure
    file&.close
  end

  # A squishling.configure squawk: — one JSON line per LLM attempt.
  def self.squawk_for(file)
    lambda do |output:, metadata:, error:|
      file.puts({
        file: Thread.current[:usage_log_fixture],
        **metadata.slice(:attempt, :attempts, :final, :model, :provider, :usage),
        error: error && "#{error.class}: #{error.message}"
      }.to_json)
    end
  end

  # Call before each fixture's parse — tags every squawk call it triggers.
  def self.tag(fixture_file)
    Thread.current[:usage_log_fixture] = fixture_file
  end
end
