# frozen_string_literal: true

class CreateTestCases < ActiveRecord::Migration[8.1]
  def change
    create_table :test_cases do |t|
      t.references :problem, null: false, foreign_key: true
      t.integer :position, null: false
      t.boolean :sample, null: false, default: false
      # Small fixtures / samples can live in text columns; large files use ActiveStorage.
      t.text :stdin
      t.text :expected_output

      t.timestamps
    end

    add_index :test_cases, [ :problem_id, :position ], unique: true
  end
end
