require 'sinatra/base'
require 'rest-client'
require 'nokogiri'
require 'json'

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
    def self.create(twitch_name, league_name)
        'http://someotherlink.com/abcd'
    end
end

class TwitchLol < Sinatra::Base
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

        link = Linker.create(twitch_name, league_name)

        {
            twitch_name: twitch_name,
            league_name: league_name,
            link: link
        }.to_json
    end
end
