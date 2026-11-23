require "test_helper"

class FundraiserCreditsTest < ActionDispatch::IntegrationTest
  def sign_in_as(username, password: "password123")
    post family_session_path, params: { family: { login: username, password: password } }
  end

  def fundraiser_params(**extra)
    { fundraiser_credit: { name: "Wreaths", fund_id: funds(:general).id, scout_share_percent: "50", record_proceeds: "1",
                           sales: { families(:one).id.to_s => "80" } } }.merge(extra)
  end

  test "admins review, then record, a fundraiser" do
    sign_in_as "adminfamily"
    get funds_path
    assert_select "a[href=?]", new_fundraiser_credit_path

    get new_fundraiser_credit_path
    assert_response :success
    assert_select "input[name=?]", "fundraiser_credit[sales][#{families(:one).id}]"

    assert_no_difference "DoubleEntry::Line.count" do
      post fundraiser_credits_path, params: fundraiser_params
    end
    assert_response :success
    assert_match "Nothing has been recorded yet", response.body
    assert_match "$40.00", response.body

    post fundraiser_credits_path, params: fundraiser_params(edit: "Make changes", confirm: "1")
    assert_select "input[value=?]", "80"
    assert_equal Money.new(0), families(:one).balance

    post fundraiser_credits_path, params: fundraiser_params(confirm: "1")
    assert_redirected_to fund_path(funds(:general))
    assert_equal Money.new(4000), families(:one).balance
  end

  test "invalid input re-renders the form" do
    sign_in_as "adminfamily"
    post fundraiser_credits_path, params: fundraiser_params(confirm: "1").deep_merge(fundraiser_credit: { scout_share_percent: "200" })
    assert_response :unprocessable_content
    assert_equal Money.new(0), families(:one).balance
  end

  test "families can't record fundraisers" do
    sign_in_as "examplefamily"
    get new_fundraiser_credit_path
    assert_redirected_to root_path

    post fundraiser_credits_path, params: fundraiser_params(confirm: "1")
    assert_redirected_to root_path
    assert_equal Money.new(0), families(:one).balance
  end
end
