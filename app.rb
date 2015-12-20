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
    def self.get_name(cookies)
        response = RestClient.get(
            'http://boards.na.leagueoflegends.com/en/c/bug-report/irZuU2Kz-crashes-affecting-mac-users-in-514',
            :cookies => cookies
        )

        html = Nokogiri::HTML(response.body)
        data = html.css('script').map(&:content).grep(/DiscussionShowPage/)

        if data.length == 1
            match = data[0].match(/document\.apolloPageBootstrap\.push\({.*?data:(.*)}.*\)/m)
            if match
                JSON.parse(match[1])["user"]["name"]
            end
        end
    end
end

class TwitchLol < Sinatra::Base
    get '/ping' do
        'pong'
    end

    post '/link' do
        headers 'Access-Control-Allow-Origin' => '*'
        twitch_cookie = params[:twitch]
        league_cookie = params[:league]

        twitch_name = Twitch.get_name(
            twitch_cookie[:name] => twitch_cookie[:value]
        )

        league_name = League.get_name(
            league_cookie[:name] => league_cookie[:value]
        )

        puts "TWITCH: #{twitch_name}\nLEAGUE: #{league_name}"
    end
end
