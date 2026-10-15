# frozen_string_literal: true

require "test_helper"

class SubmissionTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @problem = Problem.create!(
      title: "A Plus B",
      slug: "a-plus-b",
      statement: "Add two numbers.",
      rating: 800,
      tags: [ "implementation" ]
    )
  end

  # --- language and status allowlists ---

  test "accepts supported languages and statuses" do
    submission = Submission.new(
      user: @user,
      problem: @problem,
      language: "python",
      source_code: "print(1)",
      status: "queued"
    )

    assert submission.valid?

    Submission::LANGUAGES.each do |language|
      submission.language = language
      assert submission.valid?, "expected language #{language} to be valid"
    end

    Submission::STATUSES.each do |status|
      submission.status = status
      assert submission.valid?, "expected status #{status} to be valid"
    end
  end

  test "rejects unsupported language and status" do
    submission = Submission.new(
      user: @user,
      problem: @problem,
      language: "ruby",
      source_code: "puts 1",
      status: "accepted"
    )

    assert_not submission.valid?
    assert_includes submission.errors[:language], "is not included in the list"
    assert_includes submission.errors[:status], "is not included in the list"
  end

  # --- contest membership invariant ---

  test "practice submission without contest is valid" do
    submission = Submission.create!(
      user: @user,
      problem: @problem,
      language: "cpp",
      source_code: "int main(){}",
      status: "queued"
    )

    assert_nil submission.contest_id
    assert_not_nil submission.submitted_at
  end

  test "contest submission requires problem on the contest" do
    contest = Contest.create!(
      title: "Weekly",
      starts_at: 1.hour.ago,
      ends_at: 1.hour.from_now,
      status: "running"
    )
    other_problem = Problem.create!(
      title: "Other",
      slug: "other-problem",
      statement: "Other statement",
      rating: 900,
      tags: [ "math" ]
    )
    ContestProblem.create!(contest: contest, problem: other_problem, position: 1, letter: "A")

    submission = Submission.new(
      user: @user,
      problem: @problem,
      contest: contest,
      language: "python",
      source_code: "print(1)",
      status: "queued"
    )

    assert_not submission.valid?
    assert_includes submission.errors[:problem], "is not part of the contest"
  end

  test "contest submission is valid when problem belongs to contest" do
    contest = Contest.create!(
      title: "Weekly",
      starts_at: 1.hour.ago,
      ends_at: 1.hour.from_now,
      status: "running"
    )
    ContestProblem.create!(contest: contest, problem: @problem, position: 1, letter: "A")

    submission = Submission.create!(
      user: @user,
      problem: @problem,
      contest: contest,
      language: "python",
      source_code: "print(1)",
      status: "judging"
    )

    assert_equal "judging", submission.status
    assert_equal contest.id, submission.contest_id
  end

  # --- submitted_at default ---

  test "sets submitted_at on create when omitted" do
    freeze_time do
      submission = Submission.create!(
        user: @user,
        problem: @problem,
        language: "python",
        source_code: "print(1)",
        status: "queued"
      )

      assert_equal Time.current, submission.submitted_at
    end
  end

  test "preserves explicit submitted_at" do
    stamped = 2.hours.ago.change(usec: 0)
    submission = Submission.create!(
      user: @user,
      problem: @problem,
      language: "python",
      source_code: "print(1)",
      status: "ac",
      submitted_at: stamped
    )

    assert_equal stamped, submission.submitted_at
  end
end
