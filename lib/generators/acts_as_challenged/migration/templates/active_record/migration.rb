class ActsAsChallengedMigration < ActiveRecord::Migration

  def self.up
    create_table "challenges", :force => true do |t|
      t.string   "type"
      t.integer  "points",             :default => 0
      t.text     "data"
      t.integer  "user_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "child_challenge_id"
      t.datetime "ends_on"
      t.integer  "cursor",             :default => 0
      t.datetime "begins_on"
      t.datetime "locked_out_till"
      t.string   "status",             :default => "active", :null => false
    end

    add_index :challenges, [:user_id, :child_challenge_id]
  end

  def self.down
    drop_table "challenges"
  end

end
