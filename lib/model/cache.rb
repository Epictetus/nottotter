gem 'memcache-client'
require 'memcache'
MemCache.new('localhost:11211').stats

module Model
  module Cache
    def self.instance
      MemCache.new('localhost:11211')
    end

    def self.get_or_set(key)
      raise "block needed" unless block_given?
      cache = self.instance.get(key)
      return cache if cache

      new_value = yield
      expire = 3600 * 24 *rand
      self.instance.set(key, new_value, expire)
      new_value
    rescue => error
      Model.logger.warn error
      new_value || yield
    end
  end
end
