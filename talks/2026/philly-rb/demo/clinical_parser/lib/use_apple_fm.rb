# frozen_string_literal: true

# Preload (ruby -r./lib/use_apple_fm) that points squishling at the on-device
# Apple Foundation Model instead of a hosted one. The bin/run_* scripts keep
# their own Squishling.configure blocks; those don't touch the adapter, so this
# setting survives. `model:`/`provider:` are ignored by the adapter (one model).
require "bundler/setup"
require "squishling"
require "squishling/apple_fm"

Squishling.configure do |c|
  c.adapter = { type: :apple_fm, timeout: 120, ignore_unsupported_params: true }
end
