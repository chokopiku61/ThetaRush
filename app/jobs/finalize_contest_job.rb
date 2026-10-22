# frozen_string_literal: true

class FinalizeContestJob < ApplicationJob
  queue_as :default

  def perform(contest_id)
    contest = Contest.find(contest_id)
    return if contest.status == "finalized"

    raise ArgumentError, "Contest has not ended yet" if contest.ends_at.future?

    Contests::Scoring.recompute_contest!(contest)
    contest.update!(status: "finished") unless contest.status == "finished"
    UpdateRatingsJob.perform_now(contest.id)
  end
end
