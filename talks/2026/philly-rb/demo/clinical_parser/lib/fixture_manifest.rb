# lib/fixture_manifest.rb — loads fixtures/manifest.json for the bin/run_*
# scripts. The manifest now lists all 100 fixtures; set ORIGINAL_35=1 to
# run only the first 35 (the set the README's recorded v3/v4 results and the
# deck's "31/35" slides were measured against).
require "json"

module FixtureManifest
  ORIGINAL_COUNT = 35

  def self.load(root)
    entries = JSON.parse(File.read(File.join(root, "fixtures", "manifest.json")))
    ENV["ORIGINAL_35"] ? entries.first(ORIGINAL_COUNT) : entries
  end
end
