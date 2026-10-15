# frozen_string_literal: true

module Contests
  # ICPC-style contest scoring: solved count and penalty minutes.
  #
  # Rules:
  # - Practice submissions (no contest) do not affect standings.
  # - Only submissions with submitted_at in [contest.starts_at, contest.ends_at] count.
  # - Wrong attempts before the first AC add WRONG_ATTEMPT_PENALTY minutes each
  #   (WA, TLE, MLE, RE). Compile errors and internal errors do not.
  # - Penalty for a problem is time-to-first-AC in whole minutes plus wrong-attempt
  #   penalties. Unsolved problems contribute 0 penalty.
  # - Submissions after the first AC for a problem are ignored for that problem.
  # - Rank order: more solves first, then lower penalty, then earlier registration.
  #   Equal solved_count and penalty share the same rank (competition ranking).
  class Scoring
    WRONG_ATTEMPT_PENALTY = 20
    WRONG_STATUSES = %w[wa tle mle re].freeze
    AC_STATUS = "ac"

    class << self
      # Recalculate the submitter's standings from contest submissions, then ranks.
      # Returns the updated ContestParticipation, or nil when scoring does not apply.
      def apply!(submission)
        new(submission.contest).apply!(submission)
      end

      # Recalculate solved_count/penalty for every participant and assign ranks.
      def recompute_contest!(contest)
        new(contest).recompute_contest!
      end
    end

    def initialize(contest)
      @contest = contest
    end

    def apply!(submission)
      return nil if @contest.nil?
      return nil if submission.contest_id != @contest.id

      participation = @contest.contest_participations.find_by(user_id: submission.user_id)
      return nil if participation.nil?

      update_participation!(participation)
      assign_ranks!
      participation.reload
    end

    def recompute_contest!
      return [] if @contest.nil?

      @contest.contest_participations.find_each do |participation|
        update_participation!(participation)
      end
      assign_ranks!
      @contest.contest_participations.order(:rank, :id).to_a
    end

    private

    def update_participation!(participation)
      solved_count, penalty = standings_for(participation.user_id)
      participation.update!(solved_count: solved_count, penalty: penalty)
    end

    def standings_for(user_id)
      submissions = in_window_submissions
        .where(user_id: user_id)
        .order(:submitted_at, :id)

      by_problem = submissions.group_by(&:problem_id)
      solved_count = 0
      penalty = 0

      by_problem.each_value do |problem_subs|
        result = score_problem(problem_subs)
        next unless result

        solved_count += 1
        penalty += result
      end

      [ solved_count, penalty ]
    end

    def score_problem(submissions)
      wrong_attempts = 0

      submissions.each do |submission|
        status = submission.status

        if status == AC_STATUS
          minutes = minutes_from_start(submission.submitted_at)
          return minutes + (wrong_attempts * WRONG_ATTEMPT_PENALTY)
        end

        wrong_attempts += 1 if WRONG_STATUSES.include?(status)
      end

      nil
    end

    def minutes_from_start(submitted_at)
      ((submitted_at - @contest.starts_at) / 60).floor
    end

    def in_window_submissions
      @contest.submissions.where(submitted_at: @contest.starts_at..@contest.ends_at)
    end

    def assign_ranks!
      ordered = @contest.contest_participations
        .order(solved_count: :desc, penalty: :asc, registered_at: :asc, id: :asc)
        .to_a

      previous_key = nil
      previous_rank = 0

      ordered.each_with_index do |participation, index|
        key = [ participation.solved_count, participation.penalty ]
        rank = if key == previous_key
          previous_rank
        else
          index + 1
        end
        previous_key = key
        previous_rank = rank
        participation.update!(rank: rank) if participation.rank != rank
      end
    end
  end
end
