require 'sinatra/base'
require 'rest-client'
require 'nokogiri'
require 'json'
require 'sinatra/activerecord'

require_relative 'models/summoner'
require_relative 'models/twitch_summoner'
require_relative 'models/twitch_user'

module Twitch
    def self.get_name(cookies)
        response = RestClient.get(
            'https://secure.twitch.tv/settings',
            :cookies => cookies
        )

        html = Nokogiri::HTML(response.body)
        display_name = html.css('#user_displayname')

        if display_name
            display_name.attr('value')
        end
    end
end

module League
    def self.get_name(region, cookies)
        response = RestClient.get(
            "http://boards.#{region.downcase}.leagueoflegends.com/en/submit",
            :cookies => cookies
        )

        html = Nokogiri::HTML(response.body)
        data = html.css('script').map(&:content).grep(/apolloPageBootstrap/)

        if data.length == 1
            match = data[0].match(/document\.apolloPageBootstrap\.push\({.*?data:.*?user.*?name.*?:"(.*?)"/m)
            match[1]
        end
    end
end

module Linker
    def self.create(twitch_name, league_name, league_region)
        twitch_user = TwitchUser.find_or_create_by(name: twitch_name)
        summoner = Summoner.find_or_create_by(name: league_name, region: league_region)
        twitch_user.summoners << summoner

        "http://mydomain.com/#{twitch_user.sha}"
    end

  def self.destroy(twitch_name, league_name, league_region)
      twitch_id = TwitchUser.find_by(name: twitch_name)
      summoner_id = Summoner.find_by(name: league_name, region: league_region.upcase)

      TwitchSummoner.find_by(twitch_user_id: twitch_id, summoner_id: summoner_id).destroy
  end
end

class TwitchLol < Sinatra::Base
    register Sinatra::ActiveRecordExtension

    get '/ping' do
        'pong'
    end

    post '/link' do
        headers 'Access-Control-Allow-Origin' => '*'
        content_type :json

        twitch_cookie = params[:twitch]
        league_token = params[:league][:token]
        league_region = params[:league][:region]

        twitch_name = Twitch.get_name(
            twitch_cookie[:name] => twitch_cookie[:value]
        )

        league_name = League.get_name(
            league_region[:value],
            league_token[:name] => league_token[:value]
        )

        link = Linker.create(twitch_name, league_name, league_region[:value])

        {
            twitch_name: twitch_name,
            league_name: league_name,
            link: link
        }.to_json
    end
end
