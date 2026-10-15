# Fake catalog data for M3 placeholder screens (no domain models yet).
require "ostruct"

module PlaceholderData
  extend ActiveSupport::Concern

  private

  def placeholder_problems
    [
      OpenStruct.new(
        id: 1,
        title: "Two Sum",
        slug: "two-sum",
        rating: 800,
        tags: %w[arrays hashing],
        time_limit_ms: 1000,
        memory_limit_mb: 256,
        solved_count: 142,
        statement_html: <<~HTML
          <p>Given an array of integers <code>nums</code> and an integer <code>target</code>,
          return indices of the two numbers such that they add up to <code>target</code>.</p>
          <p>You may assume that each input has exactly one solution, and you may not use the same element twice.</p>
          <h3>Input</h3>
          <p>The first line contains two integers <code>n</code> and <code>target</code> (2 &le; n &le; 10<sup>5</sup>).</p>
          <p>The second line contains <code>n</code> integers <code>nums<sub>i</sub></code>.</p>
          <h3>Output</h3>
          <p>Print two 0-based indices. If several answers exist, print any.</p>
        HTML
          .strip,
        sample_input: "4 9\n2 7 11 15",
        sample_output: "0 1"
      ),
      OpenStruct.new(
        id: 2,
        title: "Binary Search Tree",
        slug: "binary-search-tree",
        rating: 1400,
        tags: %w[trees dfs],
        time_limit_ms: 2000,
        memory_limit_mb: 256,
        solved_count: 67,
        statement_html: <<~HTML
          <p>Insert values into a binary search tree and answer range queries.</p>
          <p>Placeholder statement for UI review. Real problem text arrives with the importer in a later milestone.</p>
        HTML
          .strip,
        sample_input: "3\n1 2 3",
        sample_output: "OK"
      ),
      OpenStruct.new(
        id: 3,
        title: "Shortest Path Relay",
        slug: "shortest-path-relay",
        rating: 1900,
        tags: %w[graphs shortest-paths],
        time_limit_ms: 2000,
        memory_limit_mb: 512,
        solved_count: 23,
        statement_html: <<~HTML
          <p>You are given a weighted directed graph. Find the shortest path from vertex 1 to vertex n.</p>
          <p>Placeholder statement for UI review.</p>
        HTML
          .strip,
        sample_input: "3 3\n1 2 1\n2 3 2\n1 3 10",
        sample_output: "3"
      )
    ]
  end

  def find_placeholder_problem(id)
    placeholder_problems.find { |problem| problem.id == id.to_i }
  end

  def placeholder_contests
    [
      OpenStruct.new(
        id: 1,
        title: "Daily Sprint #42",
        status: "running",
        starts_at: Time.zone.parse("2026-10-15 18:00"),
        ends_at: Time.zone.parse("2026-10-15 20:00"),
        problem_count: 3,
        registered_count: 48,
        description: "A short ICPC-style contest with three problems. Placeholder data for UI review."
      ),
      OpenStruct.new(
        id: 2,
        title: "Weekend Cup",
        status: "upcoming",
        starts_at: Time.zone.parse("2026-10-18 12:00"),
        ends_at: Time.zone.parse("2026-10-18 17:00"),
        problem_count: 5,
        registered_count: 12,
        description: "Longer practice contest. Registration opens soon (placeholder)."
      ),
      OpenStruct.new(
        id: 3,
        title: "ThetaRush Open #1",
        status: "finished",
        starts_at: Time.zone.parse("2026-10-01 10:00"),
        ends_at: Time.zone.parse("2026-10-01 15:00"),
        problem_count: 6,
        registered_count: 120,
        description: "Finished contest used to show a completed scoreboard layout."
      )
    ]
  end

  def find_placeholder_contest(id)
    placeholder_contests.find { |contest| contest.id == id.to_i }
  end

  def placeholder_contest_problems(contest)
    letters = %w[A B C D E F]
    placeholder_problems.first(contest.problem_count).each_with_index.map do |problem, index|
      OpenStruct.new(
        letter: letters[index],
        problem: problem
      )
    end
  end

  def placeholder_scoreboard_rows
    [
      OpenStruct.new(rank: 1, handle: "alice", solved: 3, penalty: 214, cells: [
        OpenStruct.new(letter: "A", text: "+1", verdict: "ac"),
        OpenStruct.new(letter: "B", text: "+2", verdict: "ac"),
        OpenStruct.new(letter: "C", text: "+1", verdict: "ac")
      ]),
      OpenStruct.new(rank: 2, handle: "bob", solved: 2, penalty: 189, cells: [
        OpenStruct.new(letter: "A", text: "+1", verdict: "ac"),
        OpenStruct.new(letter: "B", text: "-3", verdict: "wa"),
        OpenStruct.new(letter: "C", text: "+1", verdict: "ac")
      ]),
      OpenStruct.new(rank: 3, handle: "carol", solved: 2, penalty: 301, cells: [
        OpenStruct.new(letter: "A", text: "+1", verdict: "ac"),
        OpenStruct.new(letter: "B", text: "+4", verdict: "ac"),
        OpenStruct.new(letter: "C", text: ".", verdict: nil)
      ]),
      OpenStruct.new(rank: 4, handle: "dave", solved: 1, penalty: 45, cells: [
        OpenStruct.new(letter: "A", text: "+1", verdict: "ac"),
        OpenStruct.new(letter: "B", text: ".", verdict: nil),
        OpenStruct.new(letter: "C", text: "-1", verdict: "wa")
      ])
    ]
  end

  def placeholder_submission(id)
    OpenStruct.new(
      id: id.to_i.positive? ? id.to_i : 1,
      problem_id: 1,
      problem_title: "Two Sum",
      language: "python",
      verdict: "queued",
      time_ms: nil,
      memory_kb: nil,
      submitted_at: Time.zone.now
    )
  end

  def placeholder_profile(user)
    OpenStruct.new(
      email: user.email,
      handle: user.email.split("@").first,
      rating: 1520,
      max_rating: 1610,
      contests_played: 7,
      problems_solved: 34,
      recent_verdicts: [
        OpenStruct.new(problem: "Two Sum", verdict: "ac", when: "2h ago"),
        OpenStruct.new(problem: "Binary Search Tree", verdict: "wa", when: "1d ago"),
        OpenStruct.new(problem: "Shortest Path Relay", verdict: "tle", when: "3d ago")
      ]
    )
  end
end
