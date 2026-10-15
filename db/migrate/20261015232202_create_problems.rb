# frozen_string_literal: true

class CreateProblems < ActiveRecord::Migration[8.1]
  def change
    create_table :problems do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.text :statement, null: false
      t.integer :time_limit_ms, null: false, default: 1000
      t.integer :memory_limit_mb, null: false, default: 256
      t.integer :rating, null: false
      t.string :tags, array: true, null: false, default: []
      t.text :sample_input
      t.text :sample_output

      t.timestamps
    end

    add_index :problems, :slug, unique: true
    add_index :problems, :rating
  end
end
