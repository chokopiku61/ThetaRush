# frozen_string_literal: true

class NullifyPinnedContestOnDelete < ActiveRecord::Migration[8.1]
  def up
    remove_foreign_key :users, :contests, column: :pinned_contest_id
    add_foreign_key :users, :contests, column: :pinned_contest_id, on_delete: :nullify
  end

  def down
    remove_foreign_key :users, :contests, column: :pinned_contest_id
    add_foreign_key :users, :contests, column: :pinned_contest_id
  end
end
