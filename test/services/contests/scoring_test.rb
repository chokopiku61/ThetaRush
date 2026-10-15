# frozen_string_literal: true

require "test_helper"

class Contests::ScoringTest < ActiveSupport::TestCase
  setup do
    @starts_at = Time.zone.parse("2026-10-01 12:00:00")
    @ends_at = @starts_at + 2.hours
    @contest = Contest.create!(
      title: "Scoring Cup",
      starts_at: @starts_at,
      ends_at: @ends_at,
      status: "running"
    )
    @problem_a = create_problem!("problem-a", "Problem A")
    @problem_b = create_problem!("problem-b", "Problem B")
    ContestProblem.create!(contest: @contest, problem: @problem_a, position: 1, letter: "A")
    ContestProblem.create!(contest: @contest, problem: @problem_b, position: 2, letter: "B")
    @user = users(:one)
    @other = users(:two)
    @participation = ContestParticipation.create!(user: @user, contest: @contest, registered_at: @starts_at - 1.hour)
    @other_participation = ContestParticipation.create!(user: @other, contest: @contest, registered_at: @starts_at - 30.minutes)
  end

  # --- first AC and wrong-attempt penalty ---

  test "WA then AC adds time minutes plus wrong-attempt penalty" do
    submit!(@user, @problem_a, status: "wa", at: @starts_at + 3.minutes)
    ac = submit!(@user, @problem_a, status: "ac", at: @starts_at + 10.minutes)

    participation = Contests::Scoring.apply!(ac)

    assert_equal 1, participation.solved_count
    assert_equal 10 + Contests::Scoring::WRONG_ATTEMPT_PENALTY, participation.penalty
  end

  test "compile error before AC does not add wrong-attempt penalty" do
    submit!(@user, @problem_a, status: "ce", at: @starts_at + 1.minute)
    ac = submit!(@user, @problem_a, status: "ac", at: @starts_at + 5.minutes)

    participation = Contests::Scoring.apply!(ac)

    assert_equal 1, participation.solved_count
    assert_equal 5, participation.penalty
  end

  test "unsolved wrong attempts do not count as solved or penalty" do
    wa = submit!(@user, @problem_a, status: "wa", at: @starts_at + 4.minutes)

    participation = Contests::Scoring.apply!(wa)

    assert_equal 0, participation.solved_count
    assert_equal 0, participation.penalty
  end

  # --- window and post-AC ignores ---

  test "submissions outside contest window are ignored" do
    submit!(@user, @problem_a, status: "ac", at: @starts_at - 1.minute)
    late = submit!(@user, @problem_a, status: "ac", at: @ends_at + 1.minute)

    participation = Contests::Scoring.apply!(late)

    assert_equal 0, participation.solved_count
    assert_equal 0, participation.penalty
  end

  test "submissions after first AC for a problem are ignored" do
    first_ac = submit!(@user, @problem_a, status: "ac", at: @starts_at + 8.minutes)
    Contests::Scoring.apply!(first_ac)

    later = submit!(@user, @problem_a, status: "wa", at: @starts_at + 20.minutes)
    participation = Contests::Scoring.apply!(later)

    assert_equal 1, participation.solved_count
    assert_equal 8, participation.penalty
  end

  # --- ranks and apply! guards ---

  test "ranks prefer more solves then lower penalty then earlier registration" do
    submit!(@user, @problem_a, status: "ac", at: @starts_at + 10.minutes)
    submit!(@user, @problem_b, status: "ac", at: @starts_at + 20.minutes)
    other_ac = submit!(@other, @problem_a, status: "ac", at: @starts_at + 5.minutes)

    Contests::Scoring.apply!(other_ac)
    Contests::Scoring.recompute_contest!(@contest)

    assert_equal 1, @participation.reload.rank
    assert_equal 2, @other_participation.reload.rank
    assert_equal 2, @participation.solved_count
    assert_equal 1, @other_participation.solved_count
  end

  test "equal solved_count and penalty share competition rank" do
    submit!(@user, @problem_a, status: "ac", at: @starts_at + 15.minutes)
    other_ac = submit!(@other, @problem_a, status: "ac", at: @starts_at + 15.minutes)

    Contests::Scoring.apply!(other_ac)
    Contests::Scoring.recompute_contest!(@contest)

    assert_equal 1, @participation.reload.rank
    assert_equal 1, @other_participation.reload.rank
  end

  test "apply! returns nil for practice submission without contest" do
    practice = Submission.create!(
      user: @user,
      problem: @problem_a,
      language: "python",
      source_code: "print(1)",
      status: "ac",
      submitted_at: @starts_at + 1.minute
    )

    assert_nil Contests::Scoring.apply!(practice)
  end

  test "apply! returns nil when user is not registered" do
    stranger = User.create!(email: "stranger@example.com", password: "password123", username: "stranger")
    submission = Submission.create!(
      user: stranger,
      problem: @problem_a,
      contest: @contest,
      language: "python",
      source_code: "print(1)",
      status: "ac",
      submitted_at: @starts_at + 1.minute
    )

    assert_nil Contests::Scoring.apply!(submission)
  end

  private

  def create_problem!(slug, title)
    Problem.create!(
      title: title,
      slug: slug,
      statement: "#{title} statement",
      rating: 1200,
      tags: [ "math" ]
    )
  end

  def submit!(user, problem, status:, at:)
    Submission.create!(
      user: user,
      problem: problem,
      contest: @contest,
      language: "python",
      source_code: "print(1)",
      status: status,
      submitted_at: at
    )
  end
end
