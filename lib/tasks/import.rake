# frozen_string_literal: true

namespace :import do
  desc "Import problems from db/seeds/problems/*.json (idempotent upsert by slug)"
  task problems: :environment do
    seeds_dir = Rails.root.join("db/seeds/problems")
    files = Dir.glob(seeds_dir.join("*.json")).sort
    abort "No JSON files in #{seeds_dir}" if files.empty?

    files.each do |path|
      problem = Problems::Importer.import_file!(path)
      puts "Imported #{problem.slug} (#{problem.test_cases.count} tests)"
    end
  end
end
