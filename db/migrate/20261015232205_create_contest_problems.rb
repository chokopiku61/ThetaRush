# frozen_string_literal: true

class CreateContestProblems < ActiveRecord::Migration[8.1]
  def change
    create_table :contest_problems do |t|
      t.references :contest, null: false, foreign_key: true
      t.references :problem, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :letter, null: false, limit: 2

      t.timestamps
    end

    add_index :contest_problems, [ :contest_id, :problem_id ], unique: true
    add_index :contest_problems, [ :contest_id, :letter ], unique: true
    add_index :contest_problems, [ :contest_id, :position ], unique: true
  end
end
