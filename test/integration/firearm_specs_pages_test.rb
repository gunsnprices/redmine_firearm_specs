# frozen_string_literal: true

require_relative "../test_helper"

# Saves a wiki page, an issue and a news item that use the macros, then loads the pages as a browser would.
class FirearmSpecsPagesTest < Redmine::IntegrationTest
  fixtures :projects, :users, :email_addresses, :user_preferences, :roles, :members, :member_roles,
           :enabled_modules, :wikis, :wiki_pages, :wiki_contents, :trackers, :projects_trackers,
           :issue_statuses, :issues, :enumerations, :news, :workflows

  TEXT = <<~TEXT
    h2. Range report

    {{gun_specs(Glock 19 Gen 5 MOS 9mm 4.02in 15rd Pistol)}}

    Ammo: {{gun_specs(Federal American Eagle 9mm Luger 115gr FMJ, 50/Box, price=18.99)}}

    We paid {{cost_per_round(18.99, Federal 9mm 115gr 50rd)}} for {{caliber(9MM LUGER)}}.
    Next time {{caliber(300 BLK)}}.
  TEXT

  def test_wiki_page
    log_user("jsmith", "jsmith")
    put "/projects/ecookbook/wiki/Firearm_specs", params: {content: {text: TEXT, comments: "macros"}}
    assert_redirected_to "/projects/ecookbook/wiki/Firearm_specs"

    get "/projects/ecookbook/wiki/Firearm_specs"
    assert_response :success
    assert_macros_rendered
  end

  def test_wiki_page_with_caliber_links
    with_settings plugin_redmine_firearm_specs: {"caliber_links" => "1", "currency_symbol" => "$"} do
      log_user("jsmith", "jsmith")
      put "/projects/ecookbook/wiki/Firearm_specs", params: {content: {text: TEXT}}
      get "/projects/ecookbook/wiki/Firearm_specs"
      assert_response :success
      assert_select "div.wiki a.external.firearm-specs-caliber[href=?]",
                    "https://gunsnprices.com/ammo/rifle-ammo/300-aac-blackout", text: ".300 AAC Blackout"
      assert_select "div.wiki a.external.firearm-specs-caliber", 4
    end
  end

  def test_issue
    log_user("jsmith", "jsmith")
    post "/projects/ecookbook/issues", params: {
      issue: {tracker_id: 1, subject: "Range report", description: TEXT, priority_id: 5}
    }
    issue = Issue.order(:id).last
    assert_equal "Range report", issue.subject
    assert_redirected_to "/issues/#{issue.id}"

    put "/issues/#{issue.id}", params: {issue: {notes: "Bulk: {{cost_per_round($449.99, 1,000)}}"}}
    get "/issues/#{issue.id}"
    assert_response :success
    assert_macros_rendered
    assert_select "#history div.wiki span.firearm-specs-cost-per-round", text: "$0.45 per round"
  end

  def test_news
    news = News.create!(project: Project.find(1), author: User.find(2), title: "Range report",
                        summary: "Specs", description: TEXT)
    get "/news/#{news.id}"
    assert_response :success
    assert_macros_rendered
  end

  def test_plugin_is_listed
    log_user("admin", "admin")
    get "/admin/plugins"
    assert_response :success
    assert_select "tr#plugin-redmine_firearm_specs" do
      assert_select "td.name", text: /Firearm Specs/
      assert_select "td.version", text: RedmineFirearmSpecs::VERSION
      assert_select "td.configure a[href=?]", "/settings/plugin/redmine_firearm_specs"
    end
  end

  private

  def assert_macros_rendered
    assert_select "div.wiki table.firearm-specs", 2
    assert_select "div.wiki table.firearm-specs td", text: "Glock 19 Gen 5 MOS"
    assert_select "div.wiki table.firearm-specs td", text: "$0.38"
    assert_select "div.wiki span.firearm-specs-cost-per-round", text: "$0.38 per round"
    assert_select "div.wiki .firearm-specs-caliber", text: "9×19mm Parabellum"
    assert_select "div.wiki .firearm-specs-caliber", text: ".300 AAC Blackout"
    assert_select "div.flash.error", 0
  end
end
