# frozen_string_literal: true

require_relative "../test_helper"

# Renders the macros with Redmine's own wiki formatting (textilizable), as on a wiki page, an issue or a news item.
class FirearmSpecsMacrosTest < Redmine::HelperTest
  include ApplicationHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::SanitizeHelper
  include ERB::Util
  extend ActionView::Helpers::SanitizeHelper::ClassMethods

  fixtures :users

  LINKS_ON = {"caliber_links" => "1", "currency_symbol" => "$"}.freeze

  def setup
    super
    @project = nil
  end

  # gun_specs

  def test_gun_specs_firearm_table
    html = textilizable("{{gun_specs(Glock 19 Gen 5 MOS 9mm 4.02in 15rd Pistol)}}")
    assert_select_in html, "table.firearm-specs", 1
    assert_equal(
      [
        ["Type", "Firearm"], ["Brand", "Glock"], ["Model", "Glock 19 Gen 5 MOS"],
        ["Caliber", "9×19mm Parabellum"], ["Capacity", "15 rounds"], ["Barrel length", "4.02 in"]
      ],
      table_rows(html)
    )
    assert_select_in html, "table.firearm-specs th[align=left]", 6
    assert_select_in html, "table.firearm-specs a", 0
  end

  def test_gun_specs_ammo_with_price
    html = textilizable("{{gun_specs(Federal American Eagle 9mm Luger 115gr FMJ, 50/Box, price=$18.99)}}")
    assert_equal(
      [
        ["Type", "Ammunition"], ["Caliber", "9×19mm Parabellum"], ["Rounds per box", "50"],
        ["Price", "$18.99"], ["Cost per round", "$0.38"]
      ],
      table_rows(html)
    )
  end

  def test_gun_specs_options
    html = textilizable("{{gun_specs(Magtech 9mm 1000rd, kind=ammo, brand=Magtech, price=1,299.00, decimals=3)}}")
    assert_equal(
      [
        ["Type", "Ammunition"], ["Brand", "Magtech"], ["Caliber", "9×19mm Parabellum"],
        ["Rounds per box", "1,000"], ["Price", "$1,299.00"], ["Cost per round", "$1.299"]
      ],
      table_rows(html)
    )
  end

  def test_gun_specs_several_calibers
    html = textilizable('{{gun_specs(Ruger GP100 .357 Mag / .38 Special 4.2" 6-shot Revolver)}}')
    assert_includes table_rows(html), ["Calibers", ".357 Mag, .38 S&W Special"]
  end

  def test_gun_specs_mpn_option
    html = textilizable("{{gun_specs(GLOCK 9MM PISTOL 15RD, brand=Glock, mpn=UA4350201)}}")
    assert_includes table_rows(html), ["Model", "Glock 43"]
  end

  def test_gun_specs_quoted_title
    html = textilizable('{{gun_specs("Federal 9mm 115gr, 50/Box", price=18.99)}}')
    assert_includes table_rows(html), ["Cost per round", "$0.38"]
  end

  def test_gun_specs_without_specs
    html = textilizable("{{gun_specs(hello world)}}")
    assert_select_in html, "table", 0
    assert_select_in html, "span.firearm-specs-empty", text: "No firearm or ammunition specs found in: hello world"
  end

  def test_gun_specs_links_calibers_when_enabled
    with_settings plugin_redmine_firearm_specs: LINKS_ON do
      html = textilizable("{{gun_specs(Glock 19 Gen 5 9mm 15rd)}}")
      assert_select_in html, "table.firearm-specs td a.external.firearm-specs-caliber", 1
      assert_include 'href="https://gunsnprices.com/ammo/handgun-ammo/9-19mm-parabellum"', html
    end
  end

  def test_gun_specs_errors
    assert_macro_error "{{gun_specs}}", "the product title is missing"
    assert_macro_error "{{gun_specs(, price=5)}}", "the product title is missing"
    assert_macro_error "{{gun_specs(Federal 9mm 50rd, price=cheap)}}", "&quot;cheap&quot; is not a price"
    assert_macro_error "{{gun_specs(Federal 9mm 50rd, kind=magazine)}}", "kind must be firearm or ammo"
    assert_macro_error "{{gun_specs(Federal 9mm 50rd, decimals=9)}}", "decimals must be a whole number from 0 to 4"
    assert_macro_error "{{gun_specs(#{'9mm ' * 130})}}", "the text is longer than 500 characters"
  end

  # cost_per_round

  def test_cost_per_round_with_round_count
    html = textilizable("Price: {{cost_per_round(18.99, 50)}}")
    assert_select_in html, "span.firearm-specs-cost-per-round[title=?]", "$18.99 for 50 rounds",
                     text: "$0.38 per round"
  end

  def test_cost_per_round_with_title
    html = textilizable("{{cost_per_round(18.99, Federal 9mm 115gr FMJ, 50/Box)}}")
    assert_select_in html, "span.firearm-specs-cost-per-round", text: "$0.38 per round"
  end

  def test_cost_per_round_with_thousands_and_decimals
    html = textilizable("{{cost_per_round($1,299.00, 1,000, decimals=3)}}")
    assert_select_in html, "span.firearm-specs-cost-per-round[title=?]", "$1,299.00 for 1,000 rounds",
                     text: "$1.299 per round"
  end

  def test_cost_per_round_currency_symbol_setting
    with_settings plugin_redmine_firearm_specs: {"caliber_links" => "0", "currency_symbol" => "€"} do
      html = textilizable("{{cost_per_round(18.99, 50)}}")
      assert_select_in html, "span.firearm-specs-cost-per-round", text: "€0.38 per round"
    end
    with_settings plugin_redmine_firearm_specs: {"caliber_links" => "0", "currency_symbol" => ""} do
      html = textilizable("{{cost_per_round(18.99, 50)}}")
      assert_select_in html, "span.firearm-specs-cost-per-round", text: "0.38 per round"
    end
  end

  def test_cost_per_round_errors
    assert_macro_error "{{cost_per_round}}", "give a price and a round count or a title"
    assert_macro_error "{{cost_per_round(18.99)}}", "give a price and a round count or a title"
    assert_macro_error "{{cost_per_round(18.99, )}}", "give a price and a round count or a title"
    assert_macro_error "{{cost_per_round(cheap, 50)}}", "&quot;cheap&quot; is not a price"
    assert_macro_error "{{cost_per_round(18.99, Federal 9mm FMJ)}}", "no round count found in &quot;Federal 9mm FMJ&quot;"
    assert_macro_error "{{cost_per_round(18.99, 0)}}", "no round count found in &quot;0&quot;"
  end

  # caliber

  def test_caliber
    html = textilizable("Chambered in {{caliber(300 BLK)}}.")
    assert_select_in html, "span.firearm-specs-caliber", text: ".300 AAC Blackout"
    assert_select_in html, "a", 0
  end

  def test_caliber_finds_the_caliber_in_a_title
    html = textilizable("{{caliber(Hornady Critical Defense 9mm Luger 115gr FTX 25rd)}}")
    assert_select_in html, "span.firearm-specs-caliber", text: "9×19mm Parabellum"
  end

  def test_caliber_link_when_enabled
    with_settings plugin_redmine_firearm_specs: LINKS_ON do
      html = textilizable("{{caliber(12ga)}}")
      assert_select_in html, "a.external.firearm-specs-caliber[href=?]",
                       "https://gunsnprices.com/ammo/shotgun-ammo/12-gauge", text: "12 Gauge"
    end
  end

  def test_caliber_unknown_text_is_shown_as_written
    html = textilizable("{{caliber(Plasma 9000)}}")
    assert_select_in html, "span.firearm-specs-caliber.firearm-specs-unknown[title=?]", "Unknown caliber",
                     text: "Plasma 9000"
  end

  def test_caliber_missing
    assert_macro_error "{{caliber}}", "the caliber is missing"
    assert_macro_error "{{caliber( )}}", "the caliber is missing"
  end

  # escaping

  def test_text_from_the_page_is_escaped
    html = textilizable('{{gun_specs(<script>alert("x")</script>)}}')
    assert_not_include "<script", html
    assert_include "&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;", html

    html = textilizable('{{caliber(<img src=x onerror="alert(1)">)}}')
    assert_not_include "<img", html
    assert_include "&lt;img src=x onerror=&quot;alert(1)&quot;&gt;", html

    html = textilizable("{{gun_specs(Glock 19 9mm, brand=<b>Acme</b>)}}")
    assert_not_include "<b>", html

    html = textilizable("{{cost_per_round(<i>18.99</i>, 50)}}")
    assert_not_include "<i>", html
    assert_select_in html, "div.flash.error"
  end

  def test_names_from_the_data_are_escaped
    html = textilizable("{{caliber(40 S&W)}}")
    assert_include ">.40 S&amp;W<", html
  end

  def test_currency_symbol_is_escaped
    with_settings plugin_redmine_firearm_specs: {"caliber_links" => "0", "currency_symbol" => "<b>"} do
      html = textilizable("{{cost_per_round(18.99, 50)}}")
      assert_not_include "<b>", html
      assert_include "&lt;b&gt;0.38 per round", html
    end
  end

  # formats and listing

  def test_common_mark_formatting
    with_settings text_formatting: "common_mark" do
      html = textilizable("**Specs**\n\n{{gun_specs(Glock 19 Gen 5 9mm 15rd)}}\n\nCPR: {{cost_per_round(18.99, 50)}}")
      assert_select_in html, "strong", text: "Specs"
      assert_select_in html, "table.firearm-specs tr", 5
      assert_select_in html, "span.firearm-specs-cost-per-round", text: "$0.38 per round"
    end
  end

  def test_escaped_macro_is_not_run
    html = textilizable("!{{caliber(300 BLK)}}")
    assert_include "{{caliber(300 BLK)}}", html
    assert_not_include "firearm-specs-caliber", html
  end

  def test_macro_list_describes_the_macros
    html = textilizable("{{macro_list}}")
    %w[gun_specs cost_per_round caliber].each do |name|
      assert_select_in html, "dt code", text: name
    end
  end

  private

  def table_rows(html)
    Nokogiri::HTML(html).css("table.firearm-specs tr").map do |tr|
      [tr.at_css("th").text, tr.at_css("td").text]
    end
  end

  def assert_macro_error(text, message)
    html = textilizable(text)
    assert_include 'class="flash error"', html
    assert_include message, html
  end
end
