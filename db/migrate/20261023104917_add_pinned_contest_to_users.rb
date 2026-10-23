# frozen_string_literal: true

class AddPinnedContestToUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :pinned_contest, foreign_key: { to_table: :contests, on_delete: :nullify }, null: true
  end
end
