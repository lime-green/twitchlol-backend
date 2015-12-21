require 'digest/sha1'

class TwitchUser < ActiveRecord::Base
  before_validation :create_hash
  validates :name, :presence => true, :uniqueness => true

  has_many :twitch_summoners, dependent: :destroy
  has_many :summoners, :through => :twitch_summoners

  def create_hash
    self.sha = Digest::SHA1.hexdigest self.name
  end
end
