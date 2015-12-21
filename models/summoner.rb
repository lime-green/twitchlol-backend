class Summoner < ActiveRecord::Base
  before_validation :upcase_region

  validates :name, :presence => true
  validates :region, :presence => true, :inclusion => { in: %w(BR EUNE EUW KR LAN LAS NA OCE RU TR) }

  validates_uniqueness_of :name, :scope => :region

  has_many :twitch_summoners, dependent: :restrict_with_exception
  has_many :twitch_users, :through => :twitch_summoners

  def upcase_region
    self.region.upcase!
  end
end
