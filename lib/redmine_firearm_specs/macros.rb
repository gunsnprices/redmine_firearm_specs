# frozen_string_literal: true

module RedmineFirearmSpecs
  # Builds the HTML of the wiki macros {{gun_specs}}, {{cost_per_round}} and {{caliber}}.
  #
  # The HTML is made with the view's content_tag and safe_join, which escape every text value: the title, the
  # options, the names from the gunsnprices data and the currency symbol from the settings. Invalid arguments raise
  # ArgumentError; Redmine shows the message in its "Error executing the macro" box.
  class Macros
    include Redmine::I18n

    GUN_SPECS_OPTIONS = %w[kind brand mpn price decimals].freeze
    COST_PER_ROUND_OPTIONS = %w[decimals].freeze

    # Only links to these pages are made from the caliber data.
    CALIBER_URL_PREFIX = "https://gunsnprices.com/"

    # @param view [ActionView::Base] the view the macro runs in (self in a macro block)
    # @param settings [Hash{String => String}] plugin settings
    def initialize(view, settings = RedmineFirearmSpecs.settings)
      @view = view
      @caliber_links = RedmineFirearmSpecs.caliber_links?(settings)
      @currency = RedmineFirearmSpecs.currency_symbol(settings)
    end

    # {{gun_specs(title, kind=, brand=, mpn=, price=, decimals=)}}: a table of the specs found in a product title.
    #
    # @param args [String] the macro arguments, not split
    # @return [ActiveSupport::SafeBuffer]
    def gun_specs(args)
      title, options = SpecReader.split_options(args, GUN_SPECS_OPTIONS)
      title = checked_text(SpecReader.unquote(title), :firearm_specs_error_title_missing)
      kind = option_kind(options["kind"])
      price = option_price(options["price"])
      decimals = option_decimals(options["decimals"])

      info = GunsNPrices.parse_title(title, kind: kind, brand: options["brand"].presence, mpn: options["mpn"].presence)
      rows = spec_rows(info, price, decimals)
      if rows.empty?
        return @view.content_tag(:span, l(:firearm_specs_text_no_specs, title: title), class: "firearm-specs-empty")
      end

      kind_name = l(info.ammo? ? :firearm_specs_kind_ammo : :firearm_specs_kind_firearm)
      rows.unshift(row(:firearm_specs_label_type, kind_name))
      @view.content_tag(:table, @view.content_tag(:tbody, @view.safe_join(rows)), class: "firearm-specs")
    end

    # {{cost_per_round(price, round count or title, decimals=)}}: the price of one round, such as "$0.38 per round".
    #
    # @param args [String] the macro arguments, not split
    # @return [ActiveSupport::SafeBuffer]
    def cost_per_round(args)
      text, options = SpecReader.split_options(args, COST_PER_ROUND_OPTIONS)
      decimals = option_decimals(options["decimals"])
      price_text, rest = SpecReader.split_price(text)
      if price_text.nil?
        first = text.split(",", 2).first.to_s.strip
        raise ArgumentError, l(:firearm_specs_error_cost_per_round_usage) if first.empty? || !text.include?(",")

        raise ArgumentError, l(:firearm_specs_error_price, value: first)
      end
      price = option_price(price_text)
      rest = checked_text(SpecReader.unquote(rest), :firearm_specs_error_cost_per_round_usage)
      rounds = SpecReader.parse_count(rest) || GunsNPrices.rounds_per_box(rest)
      raise ArgumentError, l(:firearm_specs_error_rounds, text: rest) unless rounds.to_i.positive?

      amount = SpecReader.cost_per_round(price, rounds, decimals)
      @view.content_tag(
        :span,
        l(:firearm_specs_value_cost_per_round, amount: money(amount, decimals)),
        class: "firearm-specs-cost-per-round",
        title: l(:firearm_specs_text_cost_basis, price: money(price, 2), rounds: SpecReader.delimit(rounds))
      )
    end

    # {{caliber(text)}}: the standard name of the caliber in a caliber name or a title. Text without a known
    # caliber is shown as it was written.
    #
    # @param args [String] the macro arguments, not split
    # @return [ActiveSupport::SafeBuffer]
    def caliber(args)
      text = checked_text(SpecReader.unquote(args), :firearm_specs_error_caliber_missing)
      caliber = GunsNPrices.normalize_caliber(text)
      return caliber_html(caliber) if caliber

      @view.content_tag(:span, text, class: "firearm-specs-caliber firearm-specs-unknown",
                                     title: l(:firearm_specs_text_unknown_caliber))
    end

    private

    def spec_rows(info, price, decimals)
      rows = []
      rows << row(:firearm_specs_label_brand, info.brand) if info.brand.present?
      rows << row(:firearm_specs_label_model, info.model.model) if info.model
      if info.calibers.any?
        label = info.calibers.size > 1 ? :firearm_specs_label_calibers : :firearm_specs_label_caliber
        rows << row(label, @view.safe_join(info.calibers.map { |caliber| caliber_html(caliber) }, ", "))
      end
      rows << row(:firearm_specs_label_capacity, rounds_text(info.capacity)) if info.capacity
      if info.barrel_length
        length = l(:firearm_specs_value_inches, length: SpecReader.format_length(info.barrel_length))
        rows << row(:firearm_specs_label_barrel_length, length)
      end
      rows << row(:firearm_specs_label_rounds, SpecReader.delimit(info.rounds)) if info.rounds
      return rows if rows.empty?

      if price
        rows << row(:firearm_specs_label_price, money(price, 2))
        amount = info.rounds && SpecReader.cost_per_round(price, info.rounds, decimals)
        rows << row(:firearm_specs_label_cost_per_round, money(amount, decimals)) if amount
      end
      rows
    end

    def row(label_key, value)
      @view.content_tag(:tr, @view.content_tag(:th, l(label_key), align: "left") + @view.content_tag(:td, value))
    end

    def caliber_html(caliber)
      if @caliber_links && caliber.url.to_s.start_with?(CALIBER_URL_PREFIX)
        @view.content_tag(:a, caliber.name, href: caliber.url, class: "external firearm-specs-caliber")
      else
        @view.content_tag(:span, caliber.name, class: "firearm-specs-caliber")
      end
    end

    def rounds_text(count)
      l(:firearm_specs_value_rounds, count: count)
    end

    def money(amount, decimals)
      "#{@currency}#{SpecReader.format_amount(amount, decimals)}"
    end

    def checked_text(text, missing_key)
      raise ArgumentError, l(missing_key) if text.empty?
      if text.length > SpecReader::MAX_TEXT_LENGTH
        raise ArgumentError, l(:firearm_specs_error_too_long, max: SpecReader::MAX_TEXT_LENGTH)
      end

      text
    end

    def option_kind(value)
      return nil if value.nil?

      SpecReader.parse_kind(value) || raise(ArgumentError, l(:firearm_specs_error_kind, value: value))
    end

    def option_price(value)
      return nil if value.nil?

      SpecReader.parse_price(value) || raise(ArgumentError, l(:firearm_specs_error_price, value: value))
    end

    def option_decimals(value)
      SpecReader.parse_decimals(value) ||
        raise(ArgumentError, l(:firearm_specs_error_decimals, value: value, max: SpecReader::MAX_DECIMALS))
    end
  end
end
