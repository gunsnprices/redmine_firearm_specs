# frozen_string_literal: true

require_relative "../test_helper"

class FirearmSpecsSpecReaderTest < ActiveSupport::TestCase
  Reader = RedmineFirearmSpecs::SpecReader

  def test_split_options_without_options
    assert_equal ["Glock 19 Gen 5 9mm 15rd", {}], Reader.split_options(" Glock 19 Gen 5 9mm 15rd ", %w[price])
  end

  def test_split_options_keeps_commas_and_equal_signs_in_the_title
    title = "Federal 9mm, 50/Box, a=b"
    assert_equal [title, {}], Reader.split_options(title, %w[price kind])
  end

  def test_split_options_reads_options_at_the_end
    text, options = Reader.split_options("Federal 9mm, 50/Box, PRICE = $1,299.00, kind=ammo", %w[price kind])
    assert_equal "Federal 9mm, 50/Box", text
    assert_equal({"price" => "$1,299.00", "kind" => "ammo"}, options)
  end

  def test_split_options_values_can_contain_commas_and_quotes
    text, options = Reader.split_options('Pistol 9mm, brand="Smith & Wesson", mpn=A,B', %w[brand mpn])
    assert_equal "Pistol 9mm", text
    assert_equal({"brand" => "Smith & Wesson", "mpn" => "A,B"}, options)
  end

  def test_unquote
    assert_equal "Glock 19, Gen 5", Reader.unquote(' "Glock 19, Gen 5" ')
    assert_equal 'Remington 870 18.5"', Reader.unquote('Remington 870 18.5"')
    assert_equal '"', Reader.unquote('"')
    assert_equal "", Reader.unquote('""')
  end

  def test_split_price
    assert_equal ["18.99", "Federal 9mm 115gr 50rd"], Reader.split_price("18.99, Federal 9mm 115gr 50rd")
    assert_equal ["$1,299.00", "1,000"], Reader.split_price(" $1,299.00 , 1,000")
    assert_equal ["300", "500"], Reader.split_price("300,500")
    assert_equal ["1,000", "500"], Reader.split_price("1,000,500")
    assert_equal ["18.99", ""], Reader.split_price("18.99,")
    assert_nil Reader.split_price("18.99")
    assert_nil Reader.split_price("cheap, 50")
  end

  def test_parse_price
    assert_equal BigDecimal("18.99"), Reader.parse_price("18.99")
    assert_equal BigDecimal("18.99"), Reader.parse_price(" $18.99 ")
    assert_equal BigDecimal("1299"), Reader.parse_price("US$ 1,299.00")
    assert_equal BigDecimal("0.99"), Reader.parse_price(".99")
    assert_equal BigDecimal("5"), Reader.parse_price("€5")
    assert_nil Reader.parse_price("18,99")
    assert_nil Reader.parse_price("0")
    assert_nil Reader.parse_price("-5")
    assert_nil Reader.parse_price("$")
    assert_nil Reader.parse_price("ten dollars")
    assert_nil Reader.parse_price("1e9")
  end

  def test_parse_count
    assert_equal 50, Reader.parse_count("50")
    assert_equal 1000, Reader.parse_count(" 1,000 ")
    assert_equal 1000, Reader.parse_count("1000")
    assert_nil Reader.parse_count("50rd")
    assert_nil Reader.parse_count("1,00")
    assert_nil Reader.parse_count("2.5")
    assert_nil Reader.parse_count("")
  end

  def test_parse_decimals
    assert_equal 2, Reader.parse_decimals(nil)
    assert_equal 2, Reader.parse_decimals(" ")
    assert_equal 0, Reader.parse_decimals("0")
    assert_equal 4, Reader.parse_decimals("4")
    assert_nil Reader.parse_decimals("5")
    assert_nil Reader.parse_decimals("two")
  end

  def test_parse_kind
    assert_equal "ammo", Reader.parse_kind("Ammunition")
    assert_equal "ammo", Reader.parse_kind(" ammo ")
    assert_equal "firearm", Reader.parse_kind("FIREARM")
    assert_nil Reader.parse_kind("magazine")
  end

  def test_cost_per_round_rounds_half_up
    assert_equal BigDecimal("0.38"), Reader.cost_per_round(BigDecimal("18.99"), 50)
    assert_equal BigDecimal("0.45"), Reader.cost_per_round(BigDecimal("449.99"), 1000)
    assert_equal BigDecimal("0.45"), Reader.cost_per_round(BigDecimal("0.89"), 2)
    assert_equal BigDecimal("0.0445"), Reader.cost_per_round(BigDecimal("22.25"), 500, 4)
    assert_equal BigDecimal("2"), Reader.cost_per_round(BigDecimal("31.99"), 20, 0)
    assert_nil Reader.cost_per_round(BigDecimal("18.99"), 0)
  end

  def test_format_amount
    assert_equal "0.38", Reader.format_amount(BigDecimal("0.38"), 2)
    assert_equal "1,299.00", Reader.format_amount(BigDecimal("1299"), 2)
    assert_equal "1,234,567.5", Reader.format_amount(BigDecimal("1234567.45"), 1)
    assert_equal "0.0400", Reader.format_amount(BigDecimal("0.04"), 4)
    assert_equal "2", Reader.format_amount(BigDecimal("1.5"), 0)
  end

  def test_format_length
    assert_equal "4.02", Reader.format_length(4.02)
    assert_equal "16.5", Reader.format_length(16.5)
    assert_equal "20", Reader.format_length(20.0)
    assert_equal "100", Reader.format_length(100.0)
  end

  def test_delimit
    assert_equal "50", Reader.delimit(50)
    assert_equal "1,000", Reader.delimit(1000)
    assert_equal "12,345,678", Reader.delimit("12345678")
  end
end
