# -*- coding: utf-8 -*-
module Model
  class Hijack
    # --- constants ---
    EXPIRE = 60 * 5             # 5 minutes
    # --- class method ---

    def self.new_from_user(user) # user is from user
      raise "#user must be kind of Model::User" unless user.kind_of? Model::User
      found = self.collection.find_one({:from_user_id => user.user_id, :finish_on => {'$gt' => Time.now}})
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

      self.collection.update({
          :from_user_id => from_user.user_id,
          :finish_on => {'$gt' => Time.now},
        },
        {
          :from_user_id => from_user.user_id,
          :to_user_id => to_user.user_id,
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
      Model::User.new_from_user_id(@data['from_user_id'])
    end

    def to_user
      Model::User.new_from_user_id(@data['to_user_id'])
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
