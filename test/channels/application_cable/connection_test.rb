# frozen_string_literal: true

require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  tests ApplicationCable::Connection

  test "connects a signed-in user from the Devise session" do
    user = users(:one)
    warden = Object.new
    warden.define_singleton_method(:user) { |scope| scope == :user ? user : nil }

    connect env: { "warden" => warden }

    assert_equal user, connection.current_user
  end

  test "rejects a guest connection" do
    assert_reject_connection { connect }
  end
end
