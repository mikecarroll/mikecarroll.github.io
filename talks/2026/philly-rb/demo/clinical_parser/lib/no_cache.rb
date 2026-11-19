# frozen_string_literal: true

# Preload (ruby -r./lib/no_cache): turn squishling 0.6's default prompt caching off,
# to separate caching's cost effect from run-to-run model variance.
require "bundler/setup"
require "squishling"
Squishling.configure { |c| c.default_cache = false }
