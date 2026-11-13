# frozen_string_literal: true

require "test_helper"

class ScoreboardChannelTest < ActionCable::Channel::TestCase
  setup do
    @contest = Contest.create!(title: "Live Cup", starts_at: 1.hour.ago,
                               ends_at: 1.hour.from_now, status: "running")
  end

  test "signed-in user can subscribe to an existing contest scoreboard" do
    stub_connection(current_user: users(:one))
    subscribe(contest_id: @contest.id,
              signed_stream_name: Turbo::StreamsChannel.signed_stream_name([ @contest, :scoreboard ]))

    assert subscription.confirmed?
    assert_equal [ "#{@contest.to_gid_param}:scoreboard" ], subscription.streams
  end

  test "guest and unknown contest subscriptions are rejected" do
    stub_connection(current_user: nil)
    subscribe(contest_id: @contest.id,
              signed_stream_name: Turbo::StreamsChannel.signed_stream_name([ @contest, :scoreboard ]))
    assert subscription.rejected?

    stub_connection(current_user: users(:one))
    subscribe(contest_id: "missing",
              signed_stream_name: Turbo::StreamsChannel.signed_stream_name([ @contest, :scoreboard ]))
    assert subscription.rejected?
  end
end
