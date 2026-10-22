# frozen_string_literal: true

# Idempotent seed data for the local happy path (problems + tests).
seeds_dir = Rails.root.join("db/seeds/problems")

Dir.glob(seeds_dir.join("*.json")).sort.each do |path|
  problem = Problems::Importer.import_file!(path)
  puts "Imported problem #{problem.slug} (#{problem.test_cases.count} tests)"
end
