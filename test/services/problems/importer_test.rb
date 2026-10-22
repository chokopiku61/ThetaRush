# frozen_string_literal: true

require "test_helper"

module Problems
  class ImporterTest < ActiveSupport::TestCase
    test "imports problem and test cases idempotently" do
      path = Rails.root.join("db/seeds/problems/a_plus_b.json")

      problem = Problems::Importer.import_file!(path)
      assert_equal "a-plus-b", problem.slug
      assert_operator problem.test_cases.count, :>=, 2

      again = Problems::Importer.import_file!(path)
      assert_equal problem.id, again.id
      assert_equal problem.test_cases.count, again.test_cases.count
    end
  end
end
