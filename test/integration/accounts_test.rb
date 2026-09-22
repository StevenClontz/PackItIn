require "test_helper"

class AccountsTest < ActionDispatch::IntegrationTest
  def sign_in_as(username, password: "password123")
    post family_session_path, params: { family: { username: username, password: password } }
  end

  def assert_denied
    assert_redirected_to root_path
    follow_redirect!
    assert_match "not authorized", response.body
  end

  test "guests are sent to sign in" do
    get family_account_path(families(:one))
    assert_redirected_to new_family_session_path
  end

  test "a family sees its own balance and statement with running balances" do
    transact from: :outside, to: families(:one), dollars: 100, memo: "Dues"
    transact from: families(:one), to: funds(:general), dollars: 30, memo: "T-shirt"
    transact from: families(:two), to: families(:one), dollars: 5
    sign_in_as "examplefamily"

    get family_account_path(families(:one))
    assert_response :success
    assert_select "h2", "The Example Family Scout Account"
    assert_match "Balance:", response.body
    assert_select "strong", text: "$75.00"

    assert_select "td", text: /Deposit\s+Dues/
    assert_select "td", text: /Transfer to General\s+T-shirt/
    assert_select "td", text: /Transfer from The Joneses/
    assert_select "tbody tr", 3
    assert_select "tbody tr:first-child td:nth-child(3)", text: "$5.00"
    assert_select "tbody tr:first-child td:nth-child(4)", text: "$75.00", count: 1
    assert_select "tbody tr:last-child td:nth-child(4)", text: "$100.00"
  end

  test "an account with no activity shows a zero balance" do
    sign_in_as "examplefamily"
    get family_account_path(families(:one))
    assert_response :success
    assert_select "strong", text: "$0.00"
    assert_match "No activity yet", response.body
  end

  test "a family can't see another family's account" do
    transact from: :outside, to: families(:two), dollars: 80
    sign_in_as "examplefamily"

    get family_account_path(families(:two))
    assert_denied
    assert_no_match "$80.00", response.body

    get family_account_path(families(:admin))
    assert_denied
  end

  test "admin sees any family's account, with a link to record a transaction" do
    transact from: :outside, to: families(:two), dollars: 80
    sign_in_as "adminfamily"

    get family_account_path(families(:two))
    assert_response :success
    assert_select "strong", text: "$80.00"
    assert_select "a[href=?]", new_ledger_transaction_path, text: "New transaction"
  end

  test "a non-admin's statement has no transaction link" do
    sign_in_as "examplefamily"
    get family_account_path(families(:one))
    assert_select "a", text: "New transaction", count: 0
  end

  test "the family page shows the Scout Account to the family itself and to admins" do
    transact from: :outside, to: families(:two), dollars: 80
    sign_in_as "examplefamily"

    get family_path(families(:two)) # non-admins can't view another family's page at all
    assert_denied

    get family_path(families(:one))
    assert_select "dt", "Scout Account"
    assert_select "a[href=?]", family_account_path(families(:one))

    delete destroy_family_session_path
    sign_in_as "adminfamily"
    get family_path(families(:two))
    assert_select "dt", "Scout Account"
    assert_match "$80.00", response.body
  end

  test "the home page links to the family's own Scout Account, but not to funds for a non-admin" do
    sign_in_as "examplefamily"
    get root_path
    assert_select "a[href=?]", funds_path, count: 0
    assert_select "a[href=?]", family_account_path(families(:one)), text: "Our Scout Account"
  end

  test "the home page links to funds for an admin" do
    sign_in_as "adminfamily"
    get root_path
    assert_select "a[href=?]", funds_path, text: "Funds"
  end

  test "statements show only the latest 200 lines" do
    limit = AccountsController::STATEMENT_LINES
    (limit + 3).times { transact from: :outside, to: families(:one), dollars: 1 }
    sign_in_as "examplefamily"

    get family_account_path(families(:one))
    assert_select "tbody tr", limit
    assert_match "Showing the latest #{limit}", response.body
    assert_select "strong", text: "$#{limit + 3}.00", count: 1
  end

  # --- event accounts ---

  test "guests are sent to sign in from an event account" do
    get event_account_path(events(:campout))
    assert_redirected_to new_family_session_path
  end

  test "a non-admin family can't see an event's account" do
    transact from: :outside, to: events(:campout), dollars: 100, memo: "Sponsor gift"
    sign_in_as "examplefamily"

    get event_account_path(events(:campout))
    assert_denied
  end

  test "an admin sees an event's account balance and activity, with family names" do
    transact from: :outside, to: events(:campout), dollars: 100, memo: "Sponsor gift"
    transact from: families(:two), to: events(:campout), dollars: 20, memo: "Firewood"
    sign_in_as "adminfamily"

    get event_account_path(events(:campout))
    assert_response :success
    assert_select "h2", "Fall Campout Event Account"
    assert_select "p", text: /Event:\s*Fall Campout/
    assert_select "a[href=?]", event_path(events(:campout)), text: "Fall Campout"
    assert_select "p", text: /Balance:\s*\$120\.00/
    assert_select "td", text: /Deposit\s*Sponsor gift/
    assert_select "td", text: /Transfer from The Joneses\s*Firewood/
    assert_select "a", text: "Back to event"
  end

  test "an event account with no activity shows a zero balance" do
    sign_in_as "adminfamily"
    get event_account_path(events(:campout))
    assert_select "p", text: /Balance:\s*\$0\.00/
    assert_match "No activity yet", response.body
  end

  test "an admin gets a New transaction link on an event account" do
    sign_in_as "adminfamily"
    get event_account_path(events(:campout))
    assert_select "a[href=?]", new_ledger_transaction_path, text: "New transaction"
  end

  test "an event that doesn't exist is a 404" do
    sign_in_as "examplefamily"
    get event_account_path(event_id: 0)
    assert_response :not_found
  end

  test "a family's own account page still links back to the family" do
    sign_in_as "examplefamily"
    get family_account_path(families(:one))
    assert_select "h2", "The Example Family Scout Account"
    assert_select "a", text: "Back to family"
  end
end
