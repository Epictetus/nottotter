require 'oauth'

module Model
  class User
    # --- class method ---

    def self.new_from_screen_name(screen_name)
      data = self.collection.find_one({:screen_name => screen_name})
      raise 'no such user' unless data
      self.new(data)
    end

    def self.new_from_key(key)
      key = BSON::ObjectId.from_string(key)
      data = self.collection.find_one({:_id => key})
      raise 'no such user' unless data
      self.new(data)
    end

    def self.admin_user              # returns nottotterJP
      self.new_from_key('admin_user')
    end

    def self.register(*data)
      %w{screen_name access_key access_secret}.each{|key|
        raise "data must have #{key}" unless data.has_key? key.to_sym
      }
      inserted = self.collection.save({:screen_name => data[:screen_name]}, data) # update by screenname
      self.new_from_key(inserted['_id'])
    end

    def initialize(data)        # private
      @data = data
    end

    def self.collection # private
      Model::Database.collection('user')
    end

    # --- instance method ---

    def key
      @data['key']
    end

    def screen_name
      @data['screen_name']
    end

    def access_secret
      @data['access_secret']
    end

    def access_key
      @data['access_key']
    end

    def rubytter                # returns rubytter instance
      return @rubytter if @rubytter
      consumer ||= OAuth::Consumer.new(
        CONSUMER_KEY,
        CONSUMER_SECRET,
        :site => 'http://api.twitter.com',
        )

      access_token = OAuth::AccessToken.new(consumer, self.access_token, self.access_secret)
      @rubytter = Rubytter.new(access_token)
    end

    def profile
      # TODO: use memcached
      @profile ||= self.rubytter.user(self.screen_name)
    end
  end
end
