class CreateTwitchUsers < ActiveRecord::Migration
  def change
      create_table :twitch_users do |t|
          t.string :name
          t.string :sha, index: true
      end
  end
end
