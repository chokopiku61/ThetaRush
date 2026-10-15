require "test_helper"

class AuthSessionTest < ActionDispatch::IntegrationTest
  test "guest sees register and log in chrome" do
    get root_path
    assert_response :success
    assert_select ".site-nav", text: /Register/
    assert_select ".site-nav", text: /Log in/
    assert_select ".session-status--guest"
    assert_select ".session-status--signed-in", count: 0
  end

  test "guest is redirected from protected dashboard" do
    get dashboard_path
    assert_redirected_to new_user_session_path
    follow_redirect!
    assert_match(/sign in|log in/i, response.body)
  end

  test "register sign in refresh and sign out" do
    email = "racer@example.com"
    password = "password123"

    post user_registration_path, params: {
      user: {
        email: email,
        password: password,
        password_confirmation: password
      }
    }
    assert_redirected_to root_path
    follow_redirect!
    assert_select ".session-status--signed-in", text: /#{email}/
    assert_select ".site-nav__user", text: email

    get root_path
    assert_response :success
    assert_select ".session-status--signed-in", text: /#{email}/

    get dashboard_path
    assert_response :success
    assert_select "strong", text: email

    delete destroy_user_session_path
    assert_redirected_to root_path
    follow_redirect!
    assert_select ".session-status--guest"
    assert_select ".site-nav", text: /Register/

    get dashboard_path
    assert_redirected_to new_user_session_path
  end

  test "existing user can log in" do
    user = User.create!(email: "login@example.com", password: "password123")

    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }
    assert_redirected_to root_path
    follow_redirect!
    assert_select ".session-status--signed-in", text: /#{user.email}/
  end
end
