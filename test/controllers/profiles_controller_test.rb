# frozen_string_literal: true

require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  test "profile shows persisted rating and history" do
    contest = Contest.create!(
      title: "Profile Cup",
      starts_at: 2.hours.ago,
      ends_at: 1.hour.ago,
      status: "finalized"
    )
    users(:one).update!(rating: 1520, max_rating: 1520)
    RatingHistory.create!(
      user: users(:one),
      contest: contest,
      old_rating: 1500,
      new_rating: 1520,
      rank: 1
    )
    sign_in_as(users(:one))

    get profile_path

    assert_response :success
    assert_select ".rating-block__value", text: "1520"
    assert_select "td", text: contest.title
    assert_select "td", text: "+20"
  end

  private

  def sign_in_as(user)
    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }
  end
end
