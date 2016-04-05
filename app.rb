require 'sinatra/base'
require 'rest-client'
require 'nokogiri'
require 'json'
require 'sinatra/activerecord'
require 'uri'
require 'redis'

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
    display_name.attr('value').to_s
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
    TwitchSummoner.create_by_component(twitch_name, league_name, league_region)
  end

  def self.destroy(sha, summoner_id)
    twitch_id = TwitchUser.find_by(sha: sha)

    TwitchSummoner.find_by(twitch_user_id: twitch_id, summoner_id: summoner_id).destroy
  end
end

module LeagueApi
  class RateLimitReached < StandardError; end

  def self.summoner_id(region, name)
    url = "https://na.api.pvp.net/api/lol/#{region}/v1.4/summoner/by-name/#{URI.escape name}"
    response = request(url)

    JSON.parse(response.body).first[1]['id']
  end

  def self.summoner_division(region, id)
    url = "https://na.api.pvp.net/api/lol/#{region}/v2.5/league/by-summoner/#{id}"
    response = request(url)

    if response.code == 404
      {league: 'UNKRANKED'}
    else
      hash = JSON.parse(response.body).first[1]
      ranked_solo = hash.find {|data| data['queue'] == "RANKED_SOLO_5x5"}
      entry = ranked_solo['entries'].find {|data| data['playerOrTeamId'] == id.to_s}

      if ranked_solo
        {
          league: ranked_solo['tier'],
          division: entry['division'],
          points: entry['leaguePoints']
        }
      else
        {league: 'UNRANKED'}
      end
    end
  end

  private

  def self.request(url)
    api_key = ENV['LEAGUE_API_KEY']
    response = RestClient.get("#{url}?api_key=#{api_key}")

    raise RateLimitReached if response.code == 429
    response
  end
end

class TwitchLol < Sinatra::Base
  def initialize
    super
    @redis = Redis.new
  end

  get '/summoner_division/:summoner_name' do
    headers 'Access-Control-Allow-Origin' => '*'
    content_type :json

    region = (params[:region] || 'na').downcase
    cache_key = 'summoner_division' + params[:summoner_name] + region
    cached = @redis.get(cache_key)

    if cached
      halt 200, cached
    end

    summoner_id = LeagueApi.summoner_id(region, params[:summoner_name])
    division = LeagueApi.summoner_division(region, summoner_id)
    output = division.to_json

    @redis.set(cache_key, output)
    @redis.expire(cache_key, 3600)
    output
  end

  get '/user/:sha' do
    headers 'Access-Control-Allow-Origin' => '*'
    content_type :json

    twitch_user = TwitchUser.find_by(sha: params[:sha])
    associated_summoners = twitch_user.summoners

    {
      name: twitch_user.name,
      summoners: associated_summoners.as_json
    }.to_json
  end

  get '/user/:sha/summoner/:summonerID' do
    headers 'Access-Control-Allow-Origin' => '*'
    content_type :json

    twitch_user = TwitchUser.find_by(sha: params[:sha])
    summoner = twitch_user.summoners.find(params[:summonerID])

    {
      name: twitch_user.name,
      summoner: summoner.as_json
    }.to_json
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

    twitch_summoner = Linker.create(twitch_name, league_name, league_region[:value])
    {
      twitch_name: twitch_name,
      league_name: league_name,
      link: twitch_summoner.twitch_user.to_url,
      code: twitch_summoner.twitch_user.to_code
    }.to_json
  end

  post '/unlink' do
    headers 'Access-Control-Allow-Origin' => '*'

    Linker.destroy(params[:sha], params[:summoner_id])
  end

  options "*" do
    headers 'Access-Control-Allow-Origin' => '*'

    response.headers["Allow"] = "HEAD,GET,PUT,POST,DELETE,OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept"
    200
  end
end
