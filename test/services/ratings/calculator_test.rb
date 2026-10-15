# frozen_string_literal: true

require "test_helper"

class Ratings::CalculatorTest < ActiveSupport::TestCase
  # --- place vs rating change ---

  test "higher place gains rating against equal-rated opponent" do
    results = Ratings::Calculator.calculate(
      [
        { id: 1, rating: 1500, rank: 1 },
        { id: 2, rating: 1500, rank: 2 }
      ]
    )

    assert_equal 2, results.size
    assert_operator results[0].new_rating, :>, results[0].old_rating
    assert_operator results[1].new_rating, :<, results[1].old_rating
    assert_equal results[0].delta, -results[1].delta
  end

  test "underdog who places first gains more than favorite who places first" do
    underdog_first = Ratings::Calculator.calculate(
      [
        { id: :low, rating: 1200, rank: 1 },
        { id: :high, rating: 1800, rank: 2 }
      ]
    )
    favorite_first = Ratings::Calculator.calculate(
      [
        { id: :high, rating: 1800, rank: 1 },
        { id: :low, rating: 1200, rank: 2 }
      ]
    )

    assert_operator underdog_first[0].delta, :>, favorite_first[0].delta
  end

  # --- edge cases ---

  test "single participant leaves rating unchanged" do
    results = Ratings::Calculator.calculate([ { id: 1, rating: 1600, rank: 1 } ])

    assert_equal 1, results.size
    assert_equal 1600, results[0].new_rating
    assert_equal 0, results[0].delta
  end

  test "tied ranks produce zero net delta between equal-rated players" do
    results = Ratings::Calculator.calculate(
      [
        { id: 1, rating: 1500, rank: 1 },
        { id: 2, rating: 1500, rank: 1 }
      ]
    )

    assert_equal 0, results[0].delta
    assert_equal 0, results[1].delta
    assert_equal 1500, results[0].new_rating
    assert_equal 1500, results[1].new_rating
  end

  test "new rating never goes below zero" do
    # Equal-rated last place loses to four peers: large negative delta, floored at 0.
    participants = [ { id: 0, rating: 15, rank: 5 } ] +
      (1..4).map { |i| { id: i, rating: 15, rank: i } }

    results = Ratings::Calculator.calculate(participants, k: 64)

    assert_equal 0, results[0].new_rating
  end

  # --- helpers and validation ---

  test "history_attributes builds RatingHistory-ready hash without persisting" do
    user = users(:one)
    contest = Contest.create!(
      title: "Rated Round",
      starts_at: 1.day.ago,
      ends_at: Time.current,
      status: "finished"
    )

    attrs = Ratings::Calculator.history_attributes(
      user: user,
      contest: contest,
      old_rating: 1500,
      new_rating: 1520,
      rank: 1
    )

    assert_equal(
      {
        user_id: user.id,
        contest_id: contest.id,
        old_rating: 1500,
        new_rating: 1520,
        rank: 1
      },
      attrs
    )
    assert_equal 0, RatingHistory.count
  end

  test "calculate raises when rating or rank is missing" do
    assert_raises(ArgumentError) do
      Ratings::Calculator.calculate([ { id: 1, rank: 1 } ])
    end

    assert_raises(ArgumentError) do
      Ratings::Calculator.calculate([ { id: 1, rating: 1500 } ])
    end

    assert_raises(ArgumentError) do
      Ratings::Calculator.calculate([ { id: 1, rating: 1500, rank: 0 } ])
    end
  end

  test "calculate preserves input order and accepts objects" do
    row = Struct.new(:id, :rating, :rank).new(99, 1400, 2)
    results = Ratings::Calculator.calculate(
      [
        row,
        { id: 7, rating: 1400, rank: 1 }
      ]
    )

    assert_equal [ 99, 7 ], results.map(&:id)
    assert_operator results[0].new_rating, :<, results[0].old_rating
    assert_operator results[1].new_rating, :>, results[1].old_rating
  end
end
