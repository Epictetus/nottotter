require 'oauth'

module Model
  class User
    # --- class method ---

    def self.new_from_user_id(user_id)
      data = self.collection.find_one({:user_id => user_id})
      raise 'no such user' unless data
      self.new(data)
    end

    def self.new_from_screen_name(screen_name)
      data = self.collection.find_one({:screen_name => screen_name})
      raise 'no such user' unless data
      self.new(data)
    end

    def self.admin_user              # returns nottotterJP
      self.new_from_screen_name('admin_user')
    end

    def self.register(data)
      %w{screen_name user_id access_token access_secret}.map(&:to_sym).each{|key|
        raise "data must have #{key}" unless data.has_key? key
      }
      self.collection.update({:user_id => data[:user_id]}, data, {:upsert => true}) # update by user id
      self.new_from_user_id(data[:user_id])
    end

    def initialize(data)        # private
      @data = data
    end

    def self.collection # private
      Model::Database.collection('user')
    end

    # --- instance method ---

    def key
      @data['_id'].to_s
    end

    def user_id
      @data['user_id']
    end

    def screen_name
      @data['screen_name']
    end

    def access_token
      @data['access_token']
    end

    def access_secret
      @data['access_secret']
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
      @profile ||= self.rubytter.user(self.user_id)
    end

    CONSUMER_KEY, CONSUMER_SECRET = open(File.expand_path("~/.nottotter_token")).read.split("\n")
  end
end
