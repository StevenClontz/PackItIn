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
    assert_includes den_badge(people(:smith_dad)), ">Adult (Lion)<"
  end

  test "an adult's badge lists every regular den in their family, in den order" do
    families(:one).people.create!(first_name: "Wes", last_name: "Smith", den: :bear)
    assert_includes den_badge(people(:smith_dad)), ">Adult (Lion/Bear)<"
  end

  test "an adult with no regular-den family members gets a plain badge" do
    solo_adult = families(:admin).people.create!(first_name: "Ada", last_name: "Admin", den: :adult)
    assert_includes den_badge(solo_adult), ">Adult<"
    assert_not_includes den_badge(solo_adult), "("
  end

  test "an other_youth sibling never appears in the parenthetical" do
    families(:two).people.create!(first_name: "Kit", last_name: "Jones", den: :other_youth)
    assert_includes den_badge(people(:jones_dad)), ">Adult (Bear)<"
  end
end
