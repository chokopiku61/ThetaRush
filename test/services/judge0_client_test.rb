# frozen_string_literal: true

require "test_helper"

class Judge0ClientTest < ActiveSupport::TestCase
  test "maps language ids for python and cpp" do
    client = Judge0Client.new
    assert_equal 71, client.language_id_for!("python")
    assert_equal 54, client.language_id_for!("cpp")
  end

  test "rejects unsupported language" do
    assert_raises(Judge0Client::UnsupportedLanguage) do
      Judge0Client.new.language_id_for!("ruby")
    end
  end

  test "aggregate_results stays judging while pending" do
    results = [
      { "status" => { "id" => 1, "description" => "In Queue" } },
      { "status" => { "id" => 3, "description" => "Accepted" }, "time" => "0.01", "memory" => 1024 }
    ]
    aggregate = Judge0Client.aggregate_results(results)
    assert_equal "judging", aggregate[:status]
  end

  test "aggregate_results prefers first non-ac" do
    results = [
      { "status" => { "id" => 3, "description" => "Accepted" }, "time" => "0.01", "memory" => 100 },
      { "status" => { "id" => 4, "description" => "Wrong Answer" }, "stdout" => "0\n", "time" => "0.02", "memory" => 200 }
    ]
    aggregate = Judge0Client.aggregate_results(results)
    assert_equal "wa", aggregate[:status]
    assert_equal "0\n", aggregate[:stdout]
    assert_equal 20, aggregate[:time_ms]
    assert_equal 200, aggregate[:memory_kb]
  end

  test "aggregate_results returns ac when all accepted" do
    results = [
      { "status" => { "id" => 3, "description" => "Accepted" }, "time" => "0.01", "memory" => 100 },
      { "status" => { "id" => 3, "description" => "Accepted" }, "time" => "0.03", "memory" => 150 }
    ]
    aggregate = Judge0Client.aggregate_results(results)
    assert_equal "ac", aggregate[:status]
    assert_equal 30, aggregate[:time_ms]
    assert_equal 150, aggregate[:memory_kb]
  end

  test "maps memory limit description to mle" do
    assert_equal "mle", Judge0Client.map_status_id(12, status_description: "Memory Limit Exceeded")
  end
end
