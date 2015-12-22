class TwitchSummoner < ActiveRecord::Base
  validates_presence_of :twitch_user, :summoner
  validates_uniqueness_of :twitch_user_id, :scope => :summoner_id

  belongs_to :twitch_user
  belongs_to :summoner

  def self.create_by_component(twitch_name, league_name, league_region)
    twitch_user = TwitchUser.find_or_create_by(name: twitch_name)
    summoner = Summoner.find_or_create_by(name: league_name, region: league_region)

    begin
      twitch_user.summoners << summoner
    rescue ActiveRecord::RecordInvalid
    end

    twitch_user.twitch_summoners.find_by(summoner: summoner)
  end
end
