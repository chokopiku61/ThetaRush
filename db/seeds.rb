# frozen_string_literal: true

# Idempotent seed data for the local happy path (problems + tests).
seeds_dir = Rails.root.join("db/seeds/problems")

Dir.glob(seeds_dir.join("*.json")).sort.each do |path|
  problem = Problems::Importer.import_file!(path)
  puts "Imported problem #{problem.slug} (#{problem.test_cases.count} tests)"
end

contest = Contest.find_or_initialize_by(title: "ThetaRush Demo Contest")
contest.assign_attributes(
  description: "A running contest for the local happy-path demo.",
  starts_at: 1.hour.ago,
  ends_at: 1.day.from_now,
  status: "running"
)
contest.save!

Problem.order(:id).limit(26).each_with_index do |problem, index|
  contest_problem = contest.contest_problems.find_or_initialize_by(problem: problem)
  contest_problem.update!(position: index + 1, letter: ("A".ord + index).chr)
end

puts "Seeded contest #{contest.title} (#{contest.contest_problems.count} problems)"

[
  { name: "ThetaRush Club", description: "Official community group for ThetaRush." },
  { name: "Uni ICPC Team", description: "University ICPC practice squad." },
  { name: "Night Owls", description: "Late-night problem solving circle." }
].each do |attrs|
  group = Group.find_or_initialize_by(name: attrs[:name])
  group.description = attrs[:description]
  group.save!
  puts "Seeded group #{group.slug}"
end
