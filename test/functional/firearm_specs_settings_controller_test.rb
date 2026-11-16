# frozen_string_literal: true

require_relative "../test_helper"

class FirearmSpecsSettingsControllerTest < Redmine::ControllerTest
  tests SettingsController

  fixtures :users, :email_addresses

  def setup
    User.current = nil
    @request.session[:user_id] = 1 # admin
  end

  def test_settings_page_shows_the_defaults
    get :plugin, params: {id: "redmine_firearm_specs"}
    assert_response :success
    assert_select "input[type=checkbox][name=?][value='1']", "settings[caliber_links]", 1
    assert_select "input[type=checkbox][name=?][checked]", "settings[caliber_links]", 0
    assert_select "input[type=hidden][name=?][value='0']", "settings[caliber_links]", 1
    assert_select "input[type=text][name=?][value=?]", "settings[currency_symbol]", "$", 1
  end

  def test_saving_the_settings
    post :plugin, params: {id: "redmine_firearm_specs", settings: {caliber_links: "1", currency_symbol: "€"}}
    assert_redirected_to "/settings/plugin/redmine_firearm_specs"
    assert RedmineFirearmSpecs.caliber_links?
    assert_equal "€", RedmineFirearmSpecs.currency_symbol

    get :plugin, params: {id: "redmine_firearm_specs"}
    assert_select "input[type=checkbox][name=?][checked]", "settings[caliber_links]", 1
    assert_select "input[type=text][name=?][value=?]", "settings[currency_symbol]", "€", 1
  end

  def test_turning_links_off_again
    post :plugin, params: {id: "redmine_firearm_specs", settings: {caliber_links: "1", currency_symbol: "$"}}
    post :plugin, params: {id: "redmine_firearm_specs", settings: {caliber_links: "0", currency_symbol: "$"}}
    assert_not RedmineFirearmSpecs.caliber_links?
  end

  def test_settings_page_needs_an_admin
    @request.session[:user_id] = 2
    get :plugin, params: {id: "redmine_firearm_specs"}
    assert_response :forbidden
  end
end
