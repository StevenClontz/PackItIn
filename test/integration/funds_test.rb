require "test_helper"

class FundsTest < ActionDispatch::IntegrationTest
  def sign_in_as(username, password: "password123")
    post family_session_path, params: { family: { username: username, password: password } }
  end

  def assert_denied
    assert_redirected_to root_path
    follow_redirect!
    assert_match "not authorized", response.body
  end

  # --- guests ---

  test "guests are sent to sign in" do
    [ funds_path, fund_path(funds(:general)), new_fund_path, edit_fund_path(funds(:general)) ].each do |path|
      get path
      assert_redirected_to new_family_session_path, "GET #{path}"
    end

    assert_no_difference "Fund.count" do
      post funds_path, params: { fund: { name: "Sneaky" } }
      delete fund_path(funds(:general))
    end
  end

  # --- any family can read ---

  test "a family sees every fund with its balance and the pack total" do
    transact from: :outside, to: funds(:general), dollars: "250.00"
    transact from: :outside, to: funds(:campout), dollars: "40.50"
    sign_in_as "examplefamily"

    get funds_path
    assert_response :success
    assert_select "a[href=?]", fund_path(funds(:general)), text: "General"
    assert_select "a[href=?]", fund_path(funds(:campout)), text: "Campout Fund"
    assert_match "$250.00", response.body
    assert_match "$40.50", response.body
    assert_match "Total held by the pack", response.body
    assert_match "$290.50", response.body
  end

  test "a family sees a fund's activity, including which families were involved" do
    transact from: :outside, to: funds(:general), dollars: 100, memo: "Fundraiser"
    transact from: families(:two), to: funds(:general), dollars: 20, memo: "Pack t-shirt"
    sign_in_as "examplefamily"

    get fund_path(funds(:general))
    assert_response :success
    assert_select "h2", "General"
    assert_match "Balance:", response.body
    assert_match "$120.00", response.body
    assert_match "Deposit", response.body
    assert_match "Fundraiser", response.body
    assert_match "Transfer from The Joneses", response.body.squish
    assert_match "Pack t-shirt", response.body
  end

  test "a family sees an empty fund's page" do
    sign_in_as "examplefamily"
    get fund_path(funds(:general))
    assert_response :success
    assert_match "No activity yet", response.body
    assert_match "$0.00", response.body
  end

  test "non-admin families see no admin controls on funds" do
    sign_in_as "examplefamily"

    get funds_path
    assert_select "a", text: "New fund", count: 0
    assert_select "a", text: "New transaction", count: 0
    assert_select "a", text: "Edit", count: 0
    assert_select "button", text: "Delete", count: 0

    get fund_path(funds(:general))
    assert_select "a", text: "New transaction", count: 0
    assert_select "a", text: "Edit", count: 0
    assert_select "button", text: "Delete", count: 0
  end

  test "non-admin families can't create, edit or delete funds" do
    sign_in_as "examplefamily"

    get new_fund_path
    assert_denied
    get edit_fund_path(funds(:general))
    assert_denied

    assert_no_difference "Fund.count" do
      post funds_path, params: { fund: { name: "Sneaky" } }
      assert_denied
      delete fund_path(funds(:general))
      assert_denied
    end

    patch fund_path(funds(:general)), params: { fund: { name: "Hijacked" } }
    assert_denied
    assert_equal "General", funds(:general).reload.name
  end

  # --- admin ---

  test "admin sees every control" do
    sign_in_as "adminfamily"

    get funds_path
    assert_select "a", text: "New fund", count: 1
    assert_select "a", text: "New transaction", count: 1
    assert_select "a[href=?]", edit_fund_path(funds(:general)), text: "Edit"
    assert_select "form[action=?] button", fund_path(funds(:general)), text: "Delete"
  end

  test "admin creates a fund" do
    sign_in_as "adminfamily"

    get new_fund_path
    assert_response :success

    assert_difference "Fund.count", 1 do
      post funds_path, params: { fund: { name: "Popcorn", description: "Sale proceeds" } }
    end
    fund = Fund.find_by!(name: "Popcorn")
    assert_redirected_to fund_path(fund)
    assert_equal "Sale proceeds", fund.description
    assert_equal Money.new(0), fund.balance
  end

  test "creating a fund with invalid data re-renders the form" do
    sign_in_as "adminfamily"

    assert_no_difference "Fund.count" do
      post funds_path, params: { fund: { name: "" } }
    end
    assert_response :unprocessable_entity
    assert_select "#error_explanation"

    assert_no_difference "Fund.count" do
      post funds_path, params: { fund: { name: "general" } }
    end
    assert_response :unprocessable_entity
  end

  test "admin renames a fund without disturbing its balance" do
    transact from: :outside, to: funds(:general), dollars: 75
    sign_in_as "adminfamily"

    get edit_fund_path(funds(:general))
    assert_response :success
    assert_select "input[name=?][value=?]", "fund[name]", "General"

    patch fund_path(funds(:general)), params: { fund: { name: "Pack General" } }
    assert_redirected_to fund_path(funds(:general))
    assert_equal "Pack General", funds(:general).reload.name
    assert_equal Money.new(75_00), funds(:general).balance
  end

  test "updating with invalid data re-renders the form" do
    sign_in_as "adminfamily"

    patch fund_path(funds(:general)), params: { fund: { name: "" } }
    assert_response :unprocessable_entity
    assert_equal "General", funds(:general).reload.name
  end

  test "admin deletes a fund with no activity" do
    sign_in_as "adminfamily"

    assert_difference "Fund.count", -1 do
      delete fund_path(funds(:general))
    end
    assert_redirected_to funds_path
    assert_response :see_other
  end

  test "admin can't delete a fund that has activity" do
    transact from: :outside, to: funds(:general), dollars: 5
    sign_in_as "adminfamily"

    assert_no_difference "Fund.count" do
      delete fund_path(funds(:general))
    end
    assert_redirected_to fund_path(funds(:general))
    follow_redirect!
    assert_match "General has account activity and can&#39;t be deleted", response.body
  end

  # --- the three lists: funds, Scout Accounts, Event Accounts ---

  test "the index has Funds, Scout Accounts and Event Accounts lists" do
    sign_in_as "examplefamily"

    get funds_path
    assert_select "h2", "Funds"
    assert_select "h3", "Scout Accounts"
    assert_select "h3", "Event Accounts"
    assert_select "a[href=?]", fund_path(funds(:general)), text: "General"
  end

  test "a family sees only its own Scout Account, with its balance" do
    transact from: :outside, to: families(:one), dollars: 40
    transact from: :outside, to: families(:two), dollars: 999
    sign_in_as "examplefamily"

    get funds_path
    assert_select "a[href=?]", family_account_path(families(:one)), text: "The Example Family"
    assert_select "li", text: /The Example Family\s*\$40\.00/
    assert_select "a[href=?]", family_account_path(families(:two)), count: 0
    assert_select "a[href=?]", family_account_path(families(:admin)), count: 0
    assert_no_match "The Joneses", response.body
    assert_no_match "$999.00", response.body
  end

  test "an admin sees every family's Scout Account" do
    transact from: :outside, to: families(:two), dollars: 25
    sign_in_as "adminfamily"

    get funds_path
    Family.find_each do |family|
      assert_select "a[href=?]", family_account_path(family), text: family.name
    end
    assert_select "li", text: /The Joneses\s*\$25\.00/
  end

  test "every family sees every event's account, with its date and balance" do
    transact from: :outside, to: events(:campout), dollars: 60
    sign_in_as "examplefamily"

    get funds_path
    Event.find_each do |event|
      assert_select "a[href=?]", event_account_path(event), text: event.title
    end
    assert_select "li", text: /Fall Campout.*\$60\.00/m
    assert_select "li", text: /Trail Hike/, minimum: 1
  end

  test "events are listed newest first" do
    sign_in_as "examplefamily"

    get funds_path
    titles = css_select("a[href*='/account']").map(&:text) & Event.pluck(:title)
    assert_equal Event.order(starts_at: :desc).pluck(:title), titles
  end

  test "the pack total covers every kind of account" do
    transact from: :outside, to: families(:one), dollars: 10
    transact from: :outside, to: funds(:general), dollars: 20
    transact from: :outside, to: events(:campout), dollars: 30
    sign_in_as "examplefamily"

    get funds_path
    assert_match "Total held by the pack (Scout Accounts, funds and events)", response.body
    assert_select "strong", text: "$60.00"
  end

  test "the lists show a message when empty" do
    Event.destroy_all
    Fund.destroy_all
    sign_in_as "examplefamily"

    get funds_path
    assert_match "No funds yet.", response.body
    assert_match "No events yet.", response.body
  end
end
