# frozen_string_literal: true

require "bigdecimal"

module RedmineFirearmSpecs
  # Reads macro arguments (titles, options, prices, round counts) and formats numbers.
  #
  # Plain Ruby without Redmine or Rails: every method returns plain values or nil, never HTML. Callers escape the
  # values for their output.
  module SpecReader
    # Longest title or caliber text a macro reads. Store titles are far shorter.
    MAX_TEXT_LENGTH = 500

    # Decimal places of a cost per round when none are given, and the most allowed.
    DEFAULT_DECIMALS = 2
    MAX_DECIMALS = 4

    PRICE_NUMBER = /(?:\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?|\.\d+)/
    private_constant :PRICE_NUMBER

    # Up to 4 characters of currency before the number ("$", "US$", "€"), then optional spaces. Signs are not
    # currency, so "-5" is not a price.
    PRICE = /\A[^\d.,\s+-]{0,4}\s*(#{PRICE_NUMBER})\z/
    private_constant :PRICE

    # A price, a comma, then the rest of the arguments.
    PRICE_AND_REST = /\A\s*([^\d.,\s+-]{0,4}\s*#{PRICE_NUMBER})\s*,\s*(.*)\z/m
    private_constant :PRICE_AND_REST

    COUNT = /\A(?:\d{1,3}(?:,\d{3})+|\d+)\z/
    private_constant :COUNT

    module_function

    # Splits macro arguments into the text and the options at the end ("key=value" after a comma).
    #
    #   split_options("Federal 9mm, 50/Box, price=$1,299.00, kind=ammo", %w[kind price])
    #   # => ["Federal 9mm, 50/Box", {"price" => "$1,299.00", "kind" => "ammo"}]
    #
    # Only the given keys count as options, so a title can contain commas and "=". The options start at the first
    # ", key=" and every value runs to the next ", key=", so a value can contain commas. Keys are case-insensitive;
    # a value in double quotes loses the quotes.
    #
    # @param text [String] the arguments of a macro, as written
    # @param keys [Array<String>] option names
    # @return [Array(String, Hash{String => String})]
    def split_options(text, keys)
      text = text.to_s
      key_pattern = keys.map { |key| Regexp.escape(key) }.join("|")
      start = text =~ /,\s*(?:#{key_pattern})\s*=/i
      return [text.strip, {}] unless start

      options = {}
      text[start..].split(/,\s*(?=(?:#{key_pattern})\s*=)/i).each do |part|
        key, value = part.split("=", 2)
        next if value.nil?

        options[key.strip.downcase] = unquote(value.strip)
      end
      [text[0...start].strip, options]
    end

    # Removes one pair of double quotes around a whole value: "\"Glock 19, Gen 5\"" gives "Glock 19, Gen 5".
    #
    # @param text [String]
    # @return [String]
    def unquote(text)
      text = text.to_s.strip
      text.length >= 2 && text.start_with?('"') && text.end_with?('"') ? text[1..-2].strip : text
    end

    # Splits "18.99, Federal 9mm 50rd" into the price and the rest. Commas in the price are thousands separators
    # only when 3 digits follow ("$1,299.00, 1,000" gives "$1,299.00" and "1,000").
    #
    # @param text [String]
    # @return [Array(String, String), nil] nil if the text does not start with a price and a comma
    def split_price(text)
      match = PRICE_AND_REST.match(text.to_s)
      match && [match[1].strip, match[2].strip]
    end

    # Reads a price: "18.99", "$18.99", "US$ 1,299.00", "1299", ".99".
    #
    # Up to 4 characters before the number are taken as the currency and ignored. Commas are thousands separators
    # only, so "18,99" is not a price.
    #
    # @param text [String]
    # @return [BigDecimal, nil] nil unless the text is a positive number
    def parse_price(text)
      match = PRICE.match(text.to_s.strip)
      return nil unless match

      price = BigDecimal(match[1].delete(","))
      price.positive? ? price : nil
    end

    # Reads a whole number such as a round count: "50", "1,000", "1000".
    #
    # @param text [String]
    # @return [Integer, nil]
    def parse_count(text)
      text = text.to_s.strip
      COUNT.match?(text) ? text.delete(",").to_i : nil
    end

    # Reads the number of decimal places of a cost per round.
    #
    # @param text [String, nil] "0" to "4"; nil or "" for the default
    # @return [Integer, nil] nil if the text is not a number from 0 to MAX_DECIMALS
    def parse_decimals(text)
      return DEFAULT_DECIMALS if text.to_s.strip.empty?

      decimals = parse_count(text)
      decimals if decimals && decimals <= MAX_DECIMALS
    end

    # Reads a product type: "firearm", "ammo" or "ammunition", in any case.
    #
    # @param text [String, nil]
    # @return [String, nil] "firearm", "ammo", or nil if the text is something else
    def parse_kind(text)
      case text.to_s.strip.downcase
      when "firearm", "gun" then "firearm"
      when "ammo", "ammunition" then "ammo"
      end
    end

    # Price of one round, rounded half up.
    #
    # @param price [BigDecimal]
    # @param rounds [Integer]
    # @param decimals [Integer]
    # @return [BigDecimal, nil] nil unless rounds is positive
    def cost_per_round(price, rounds, decimals = DEFAULT_DECIMALS)
      return nil unless rounds.to_i.positive?

      (BigDecimal(price.to_s) / rounds.to_i).round(decimals, BigDecimal::ROUND_HALF_UP)
    end

    # Formats an amount with a fixed number of decimal places, a dot and commas between thousands:
    # format_amount(BigDecimal("1299"), 2) gives "1,299.00".
    #
    # @param number [BigDecimal, Numeric]
    # @param decimals [Integer]
    # @return [String]
    def format_amount(number, decimals)
      number = BigDecimal(number.to_s).round(decimals, BigDecimal::ROUND_HALF_UP)
      whole, fraction = number.abs.to_s("F").split(".")
      text = delimit(whole)
      text += ".#{fraction.to_s.ljust(decimals, '0')[0, decimals]}" if decimals.positive?
      number.negative? ? "-#{text}" : text
    end

    # Formats a length with up to 2 decimal places and no trailing zeros: 16.5 gives "16.5", 20.0 gives "20".
    #
    # @param number [Numeric]
    # @return [String]
    def format_length(number)
      text = BigDecimal(number.to_s).round(2, BigDecimal::ROUND_HALF_UP).to_s("F")
      text.include?(".") ? text.sub(/0+\z/, "").chomp(".") : text
    end

    # Puts commas between thousands: 1000 gives "1,000".
    #
    # @param number [Integer, String] a whole number
    # @return [String]
    def delimit(number)
      number.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
    end
  end
end
