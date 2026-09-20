require "test_helper"

class PeopleHelperTest < ActionView::TestCase
  BADGE_CLASSES = "rounded-full bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-700".freeze

  Person.positions.each_key do |position|
    test "the badge for #{position} shows its label" do
      assert_dom_equal %(<span class="#{BADGE_CLASSES}">#{I18n.t("people.positions.#{position}")}</span>),
                       position_badge(Person.new(position: position))
    end
  end

  test "the badge uses the display label, not the raw position" do
    assert_includes position_badge(Person.new(position: "aol")), ">AOL<"
    assert_includes position_badge(people(:smith_dad)), ">Adult<"
  end
end
