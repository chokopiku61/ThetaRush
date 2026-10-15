# frozen_string_literal: true

class CreateContestParticipations < ActiveRecord::Migration[8.1]
  def change
    create_table :contest_participations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :contest, null: false, foreign_key: true
      t.integer :solved_count, null: false, default: 0
      t.integer :penalty, null: false, default: 0
      t.integer :rank
      t.datetime :registered_at, null: false

      t.timestamps
    end

    add_index :contest_participations, [ :user_id, :contest_id ], unique: true
    add_index :contest_participations, [ :contest_id, :solved_count, :penalty ],
              name: "index_contest_participations_on_standings"
  end
end
