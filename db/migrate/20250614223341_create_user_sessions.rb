class CreateUserSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :user_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :session_id, null: false
      t.string :ip_address
      t.text :user_agent
      t.datetime :last_activity_at, null: false
      t.datetime :expires_at, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end
    
    add_index :user_sessions, :session_id, unique: true
    add_index :user_sessions, [:user_id, :active]
    add_index :user_sessions, :last_activity_at
    add_index :user_sessions, :expires_at
  end
end
