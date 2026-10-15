# frozen_string_literal: true

class AddProfileFieldsToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :username, :string
    add_column :users, :rating, :integer, null: false, default: 1500
    add_column :users, :max_rating, :integer, null: false, default: 1500

    # Backfill handles for any existing Devise users before enforcing uniqueness.
    say_with_time "backfill usernames from email" do
      execute <<~SQL.squish
        UPDATE users
        SET username = CONCAT(
          REGEXP_REPLACE(SPLIT_PART(email, '@', 1), '[^a-zA-Z0-9_]', '', 'g'),
          '_',
          id
        )
        WHERE username IS NULL OR username = ''
      SQL
    end

    change_column_null :users, :username, false
    add_index :users, :username, unique: true
  end

  def down
    remove_index :users, :username
    remove_column :users, :username
    remove_column :users, :rating
    remove_column :users, :max_rating
  end
end
