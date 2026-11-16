# frozen_string_literal: true

# Firearm Specs, a Redmine plugin: wiki macros that read firearm and ammunition specs from product titles with the
# gunsnprices gem.
module RedmineFirearmSpecs
  VERSION = "1.0.0"

  # Plugin settings and their defaults (Administration > Plugins > Firearm Specs > Configure).
  DEFAULT_SETTINGS = {
    "caliber_links" => "0",
    "currency_symbol" => "$"
  }.freeze

  # Longest currency symbol that is used; longer values are cut.
  MAX_CURRENCY_SYMBOL_LENGTH = 5

  class << self
    # @return [Hash{String => String}] the saved settings merged over the defaults
    def settings
      with_defaults(Setting.plugin_redmine_firearm_specs)
    end

    # @param saved [Hash, nil] settings as Redmine stores them (string or symbol keys)
    # @return [Hash{String => String}] the settings merged over the defaults, with string keys and values
    def with_defaults(saved)
      saved = {} unless saved.respond_to?(:each_pair)
      saved.each_pair.with_object(DEFAULT_SETTINGS.dup) { |(key, value), all| all[key.to_s] = value.to_s }
    end

    # @return [Boolean] whether caliber names link to their price comparison pages on gunsnprices.com
    def caliber_links?(settings = self.settings)
      settings["caliber_links"].to_s == "1"
    end

    # @return [String] the symbol shown before prices and costs per round ("" for none)
    def currency_symbol(settings = self.settings)
      settings["currency_symbol"].to_s.strip[0, MAX_CURRENCY_SYMBOL_LENGTH]
    end
  end
end
