# frozen_string_literal: true

require "gunsnprices"

Redmine::Plugin.register :redmine_firearm_specs do
  name "Firearm Specs"
  author "GunsNPrices"
  description "Wiki macros that read firearm and ammunition specs from a product title: caliber, model, " \
              "magazine capacity, barrel length, rounds per box and cost per round."
  version RedmineFirearmSpecs::VERSION
  url "https://github.com/gunsnprices/redmine_firearm_specs"
  author_url "https://gunsnprices.com/developers"
  requires_redmine version_or_higher: "5.1.0"

  settings default: RedmineFirearmSpecs::DEFAULT_SETTINGS.dup, partial: "settings/firearm_specs_settings"
end

Redmine::WikiFormatting::Macros.register do
  desc <<~TEXT
    Shows a table of the specs in a firearm or ammunition product title:
    brand, model, caliber, magazine capacity, barrel length, rounds per box.
    Options at the end: kind=firearm|ammo, brand=, mpn=, price=, decimals=0..4
    (price adds the cost per round of ammunition). Examples:

    {{gun_specs(Glock 19 Gen 5 9mm 15rd)}}
    {{gun_specs(Federal 9mm 115gr FMJ, 50/Box, price=18.99)}}
  TEXT
  macro :gun_specs, parse_args: false do |_obj, args|
    RedmineFirearmSpecs::Macros.new(self).gun_specs(args)
  end

  desc <<~TEXT
    Shows the price of one round. The second argument is the number of rounds
    or an ammunition title that contains it. Option: decimals=0..4 (default 2).
    Examples:

    {{cost_per_round(18.99, 50)}}
    {{cost_per_round(18.99, Federal 9mm 115gr 50rd)}}
  TEXT
  macro :cost_per_round, parse_args: false do |_obj, args|
    RedmineFirearmSpecs::Macros.new(self).cost_per_round(args)
  end

  desc <<~TEXT
    Shows the standard name of a caliber written in a common spelling, or of
    the first caliber in a product title. Examples:

    {{caliber(300 BLK)}}
    {{caliber(9MM LUGER)}}
  TEXT
  macro :caliber, parse_args: false do |_obj, args|
    RedmineFirearmSpecs::Macros.new(self).caliber(args)
  end
end
