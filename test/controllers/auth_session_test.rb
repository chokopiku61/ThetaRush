require "test_helper"

class AuthSessionTest < ActionDispatch::IntegrationTest
  test "guest sees register and log in chrome" do
    get root_path
    assert_response :success
    assert_select "a[href=?]", new_user_registration_path
    assert_select "a[href=?]", new_user_session_path
    assert_select ".sidebar__user", count: 0
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
    user = User.find_by!(email: email)
    assert_select ".sidebar__user", text: /#{user.username}/

    get root_path
    assert_response :success
    assert_select ".sidebar__user", text: /#{user.username}/

    get dashboard_path
    assert_response :success
    assert_select "strong", text: email

    delete destroy_user_session_path
    assert_redirected_to root_path
    follow_redirect!
    assert_select "a[href=?]", new_user_registration_path
    assert_select ".sidebar__user", count: 0

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
    assert_select ".sidebar__user", text: /#{user.username}/
  end
end
