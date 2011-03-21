require 'model/database'
require 'model/cache'
require 'model/user'
require 'model/hijack'
require 'model/twitter'
require 'model/active_rubytter'
require 'model/aamaker.rb'
require 'logger'

module Model
  def self.logger
    @logger ||= Logger.new($stderr)
  end
end
