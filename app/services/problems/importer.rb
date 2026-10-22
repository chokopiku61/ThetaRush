# frozen_string_literal: true

module Problems
  # Upserts problems and nested test cases from a Hash or JSON file by slug.
  class Importer
    class Error < StandardError; end

    def self.import_file!(path)
      new.import_file!(path)
    end

    def self.import_hash!(data)
      new.import_hash!(data)
    end

    def import_file!(path)
      path = Pathname(path)
      raise Error, "file not found: #{path}" unless path.exist?

      data = JSON.parse(path.read)
      import_hash!(data)
    end

    def import_hash!(data)
      data = data.deep_stringify_keys
      slug = data.fetch("slug")

      problem = Problem.find_or_initialize_by(slug: slug)
      problem.assign_attributes(
        title: data.fetch("title"),
        statement: data.fetch("statement"),
        time_limit_ms: data.fetch("time_limit_ms", 1000),
        memory_limit_mb: data.fetch("memory_limit_mb", 256),
        rating: data.fetch("rating"),
        tags: Array(data.fetch("tags")),
        sample_input: data["sample_input"],
        sample_output: data["sample_output"]
      )
      problem.save!

      sync_test_cases!(problem, Array(data["test_cases"]))
      problem
    end

    private

    def sync_test_cases!(problem, cases)
      keep_positions = []

      cases.each do |tc|
        position = tc.fetch("position").to_i
        keep_positions << position

        record = problem.test_cases.find_or_initialize_by(position: position)
        record.assign_attributes(
          sample: ActiveModel::Type::Boolean.new.cast(tc.fetch("sample", false)),
          stdin: tc.fetch("stdin"),
          expected_output: tc.fetch("expected_output")
        )
        record.save!
      end

      problem.test_cases.where.not(position: keep_positions).destroy_all
    end
  end
end
