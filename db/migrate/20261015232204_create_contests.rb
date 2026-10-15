# frozen_string_literal: true

class CreateContests < ActiveRecord::Migration[8.1]
  def change
    create_table :contests do |t|
      t.string :title, null: false
      t.text :description
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :status, null: false, default: "upcoming"

      t.timestamps
    end

    add_index :contests, :status
    add_index :contests, :starts_at
  end
end
