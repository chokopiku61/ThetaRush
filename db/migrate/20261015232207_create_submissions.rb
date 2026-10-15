# frozen_string_literal: true

class CreateSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :submissions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :problem, null: false, foreign_key: true
      t.references :contest, foreign_key: true
      t.string :language, null: false
      t.text :source_code, null: false
      t.string :status, null: false, default: "queued"
      t.integer :time_ms
      t.integer :memory_kb
      t.string :judge0_token
      t.text :stdout
      t.text :stderr
      t.text :compile_output
      t.datetime :submitted_at, null: false

      t.timestamps
    end

    add_index :submissions, :status
    add_index :submissions, :judge0_token, unique: true
    add_index :submissions, [ :contest_id, :user_id, :problem_id ]
    add_index :submissions, [ :user_id, :created_at ]
  end
end
