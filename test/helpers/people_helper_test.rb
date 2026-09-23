require "test_helper"

class PeopleHelperTest < ActionView::TestCase
  BADGE_CLASSES = "rounded-full bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-700".freeze

  Person.dens.each_key do |den|
    test "the badge for #{den} shows its label" do
      assert_dom_equal %(<span class="#{BADGE_CLASSES}">#{I18n.t("people.dens.#{den}")}</span>),
                       den_badge(Person.new(den: den))
    end
  end

  test "the badge uses the display label, not the raw den" do
    assert_includes den_badge(Person.new(den: "aol")), ">AOL<"
    assert_includes den_badge(people(:smith_dad)), ">Adult<"
  end
end
