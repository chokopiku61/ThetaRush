# frozen_string_literal: true

class CreateRatingHistories < ActiveRecord::Migration[8.1]
  def change
    create_table :rating_histories do |t|
      t.references :user, null: false, foreign_key: true
      t.references :contest, null: false, foreign_key: true
      t.integer :old_rating, null: false
      t.integer :new_rating, null: false
      t.integer :rank

      t.timestamps
    end

    add_index :rating_histories, [ :user_id, :contest_id ], unique: true
    add_index :rating_histories, [ :user_id, :created_at ]
  end
end
