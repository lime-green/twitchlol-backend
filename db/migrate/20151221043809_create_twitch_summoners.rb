class CreateTwitchSummoners < ActiveRecord::Migration
    def change
        create_table :twitch_summoners do |t|
            t.belongs_to :twitch_user, :null => false, :index => true
            t.belongs_to :summoner, :null => false, :index => true
        end
    end
end
