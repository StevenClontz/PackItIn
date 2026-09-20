require "test_helper"

class LedgerTransactionsTest < ActionDispatch::IntegrationTest
  def sign_in_as(username, password: "password123")
    post family_session_path, params: { family: { username: username, password: password } }
  end

  def assert_denied
    assert_redirected_to root_path
    follow_redirect!
    assert_match "not authorized", response.body
  end

  def post_transaction(from:, to:, amount:, memo: nil)
    post ledger_transactions_path, params: { ledger_transaction: { from: ledger_ref(from), to: ledger_ref(to), amount: amount, memo: memo } }
  end

  # --- guests and families ---

  test "guests are sent to sign in" do
    get new_ledger_transaction_path
    assert_redirected_to new_family_session_path

    assert_no_difference "DoubleEntry::Line.count" do
      post_transaction from: :outside, to: families(:one), amount: "10"
    end
    assert_redirected_to new_family_session_path
  end

  test "families can't record transactions, even for themselves" do
    sign_in_as "examplefamily"

    get new_ledger_transaction_path
    assert_denied

    assert_no_difference "DoubleEntry::Line.count" do
      post_transaction from: :outside, to: families(:one), amount: "10"
      assert_denied
      post_transaction from: families(:two), to: families(:one), amount: "10"
      assert_denied
    end
    assert_equal Money.new(0), families(:one).balance
  end

  # --- admin ---

  test "the form offers outside, every family and every fund for both From and To" do
    sign_in_as "adminfamily"

    get new_ledger_transaction_path
    assert_response :success
    %w[from to].each do |field|
      assert_select "select[name=?]", "ledger_transaction[#{field}]" do
        assert_select "option", text: /Outside the pack/
        assert_select "option[value=?]", ledger_ref(families(:one)), text: "Family: The Example Family"
        assert_select "option[value=?]", ledger_ref(families(:two)), text: "Family: The Joneses"
        assert_select "option[value=?]", ledger_ref(funds(:general)), text: "Fund: General"
        assert_select "option[value=?]", ledger_ref(funds(:campout)), text: "Fund: Campout Fund"
      end
    end
    assert_select "input[name=?]", "ledger_transaction[amount]"
    assert_select "input[name=?]", "ledger_transaction[memo]"
  end

  test "admin credits a family and lands on its statement" do
    sign_in_as "adminfamily"

    assert_difference "DoubleEntry::Line.count", 2 do
      post_transaction from: :outside, to: families(:one), amount: "$60.00", memo: "Popcorn money"
    end
    assert_redirected_to family_account_path(families(:one))
    follow_redirect!
    assert_match "Transaction recorded.", response.body
    assert_match "Popcorn money", response.body
    assert_match "$60.00", response.body
    assert_equal Money.new(60_00), families(:one).balance
    assert_equal families(:admin).id, families(:one).ledger_lines.first.metadata["admin_id"], "records who did it"
  end

  test "admin debits a fund and lands on its page" do
    transact from: :outside, to: funds(:general), dollars: 100
    sign_in_as "adminfamily"

    post_transaction from: funds(:general), to: :outside, amount: "35.25", memo: "Supplies"
    assert_redirected_to fund_path(funds(:general))
    follow_redirect!
    assert_match "Withdrawal", response.body
    assert_match "Supplies", response.body
    assert_equal Money.new(64_75), funds(:general).balance
  end

  test "admin transfers between a family and a fund" do
    transact from: :outside, to: families(:two), dollars: 50
    sign_in_as "adminfamily"

    post_transaction from: families(:two), to: funds(:campout), amount: "20"
    assert_redirected_to fund_path(funds(:campout))
    assert_equal Money.new(30_00), families(:two).balance
    assert_equal Money.new(20_00), funds(:campout).balance
  end

  test "a family can be taken negative and it shows in red on its statement" do
    sign_in_as "adminfamily"

    post_transaction from: families(:one), to: :outside, amount: "15"
    assert_equal Money.new(-15_00), families(:one).balance

    get family_account_path(families(:one))
    assert_select "span.text-red-600", text: "-$15.00", minimum: 1
  end

  test "invalid input re-renders the form and records nothing" do
    sign_in_as "adminfamily"

    assert_no_difference "DoubleEntry::Line.count" do
      post_transaction from: :outside, to: families(:one), amount: "abc"
      assert_response :unprocessable_entity
      assert_select "#error_explanation", /Amount must be a dollar amount/

      post_transaction from: :outside, to: :outside, amount: "5"
      assert_response :unprocessable_entity
      assert_select "#error_explanation", /Choose at least one account inside the pack/

      post_transaction from: families(:one), to: families(:one), amount: "5"
      assert_response :unprocessable_entity
      assert_select "#error_explanation", /To must be different/

      post_transaction from: "family:0", to: families(:one), amount: "5"
      assert_response :unprocessable_entity
      assert_select "#error_explanation", /From must be an account/

      post_transaction from: :outside, to: families(:one), amount: "0"
      assert_response :unprocessable_entity
      assert_select "#error_explanation", /greater than zero/
    end
  end

  test "the form keeps what was typed after an error" do
    sign_in_as "adminfamily"

    post_transaction from: :outside, to: families(:one), amount: "12.345", memo: "Keep me"
    assert_response :unprocessable_entity
    assert_select "select[name=?] option[selected][value=?]", "ledger_transaction[to]", ledger_ref(families(:one))
    assert_select "input[name=?][value=?]", "ledger_transaction[memo]", "Keep me"
  end

  test "the acting admin can't be spoofed through parameters" do
    sign_in_as "adminfamily"

    post ledger_transactions_path, params: { ledger_transaction: { from: "outside", to: ledger_ref(families(:one)), amount: "5", admin: families(:two).id } }
    assert_equal families(:admin).id, families(:one).ledger_lines.first.metadata["admin_id"]
  end
end
