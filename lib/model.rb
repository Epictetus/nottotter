require 'model/database'
require 'model/cache'
require 'model/user'
require 'model/hijack'
require 'model/twitter'
require 'model/active_rubytter'
require 'logger'

module Model
  def self.logger
    @logger ||= Logger.new($stdout)
  end
end
