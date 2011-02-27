# -*- coding: utf-8 -*-
module Model
  class Hijack
    # --- constants ---
    EXPIRE = 60 * 5             # 5 minutes
    # --- class method ---

    def self.new_from_user(user) # user is from user
      raise "#user must be kind of Model::User" unless user.kind_of? Model::User
      found = self.collection.find_one({:from_screen_name => user.screen_name, :finish_on => {'$gt' => Time.now}})
      return unless found
      return self.new(found)
    end

    def self.create(data)
      %w{from_user to_user}.map(&:to_sym).each{|key|
        raise "data must have #{key}" unless data.has_key? key
        raise "#{key} must be kind of Model::User" unless data[key].kind_of? Model::User
      }

      from_user = data[:from_user]
      to_user = data[:to_user]

      p self.collection.update({
          :from_screen_name => from_user.screen_name,
          :finish_on => {'$gt' => Time.now},
        },
        {
          :from_screen_name => from_user.screen_name,
          :to_screen_name => to_user.screen_name,
          :start_on => Time.now,
          :finish_on => Time.now + EXPIRE,
        },
        {:upsert => true})

      self.new_from_user(from_user)
    end

    def initialize(data)        # private
      @data = data
    end

    def self.collection # private
      Model::Database.collection('hijack')
    end

    # --- instance method ---

    def key
      @data['_id'].to_s
    end

    def from_user
      Model::User.new_from_screen_name(@data['from_screen_name'])
    end

    def to_user
      Model::User.new_from_screen_name(@data['to_screen_name'])
    end

    def start_on
      @data['start_on']
    end

    def finish_on
      @data['finish_on']
    end

    def alive?
      self.finish_on > Time.now
    end
  end
end
