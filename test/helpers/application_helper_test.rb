require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "app_name defaults to Pack It In" do
    original = ENV["APP_NAME"]
    ENV["APP_NAME"] = nil
    assert_equal "Pack It In", app_name
  ensure
    ENV["APP_NAME"] = original
  end

  test "app_name can be overridden by the APP_NAME env var" do
    original = ENV["APP_NAME"]
    ENV["APP_NAME"] = "Troop 123"
    assert_equal "Troop 123", app_name
  ensure
    ENV["APP_NAME"] = original
  end
end
