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

  test "markdown renders formatting, lists, links and images" do
    html = markdown("**Bring** a [map](https://example.com/map)\n\n- tent\n- ~~stove~~\n\n![flyer](/rails/active_storage/blobs/redirect/abc/flyer.png)")
    assert_includes html, "<strong>Bring</strong>"
    assert_includes html, %(<a href="https://example.com/map">map</a>)
    assert_includes html, "<li>tent</li>"
    assert_includes html, "<del>stove</del>"
    assert_includes html, %(<img src="/rails/active_storage/blobs/redirect/abc/flyer.png" alt="flyer">)
  end

  test "markdown drops raw HTML and javascript links" do
    html = markdown(%(<script>alert(1)</script>\n\n<b onclick="x()">hi</b> [click](javascript:alert(1))))
    assert_not_includes html, "<script"
    assert_not_includes html, "onclick"
    assert_not_includes html, "javascript:"
  end

  test "markdown of nil is empty" do
    assert_equal "", markdown(nil).strip
  end
end
