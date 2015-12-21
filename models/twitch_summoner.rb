class TwitchSummoner < ActiveRecord::Base
  validates_presence_of :twitch_user, :summoner
  validates_uniqueness_of :twitch_user_id, :scope => :summoner_id

  belongs_to :twitch_user
  belongs_to :summoner
end
