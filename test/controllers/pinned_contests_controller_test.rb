# frozen_string_literal: true

require "test_helper"

class PinnedContestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @contest = Contest.create!(
      title: "Pin Cup",
      description: "Pin test contest.",
      starts_at: 1.hour.ago,
      ends_at: 1.hour.from_now,
      status: "running"
    )
    @other = Contest.create!(
      title: "Other Cup",
      description: "Another contest.",
      starts_at: 2.hours.from_now,
      ends_at: 4.hours.from_now,
      status: "upcoming"
    )
  end

  test "guest cannot pin" do
    post pin_contest_path(@contest)
    assert_redirected_to new_user_session_path
  end

  test "signed-in user pins and replaces previous pin" do
    sign_in_as(users(:one))

    post pin_contest_path(@contest)
    assert_redirected_to contest_path(@contest)
    users(:one).reload
    assert_equal @contest.id, users(:one).pinned_contest_id

    post pin_contest_path(@other)
    users(:one).reload
    assert_equal @other.id, users(:one).pinned_contest_id

    delete pin_contest_path(@other)
    users(:one).reload
    assert_nil users(:one).pinned_contest_id
  end

  test "turbo stream pin replaces pin button and sidebar slot" do
    sign_in_as(users(:one))

    post pin_contest_path(@contest), as: :turbo_stream
    assert_response :success
    users(:one).reload
    assert_equal @contest.id, users(:one).pinned_contest_id

    assert_match(/turbo-stream[^>]*action="replace"[^>]*target="contest-pin-button"/, response.body)
    assert_match(/turbo-stream[^>]*action="replace"[^>]*target="sidebar-pin-slot"/, response.body)
    assert_includes response.body, "sidebar__pin--active"
    assert_includes response.body, "pin-btn--on"

    delete pin_contest_path(@contest), as: :turbo_stream
    assert_response :success
    users(:one).reload
    assert_nil users(:one).pinned_contest_id
    assert_includes response.body, "sidebar__pin--empty"
  end

  private

  def sign_in_as(user)
    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }
  end
end
