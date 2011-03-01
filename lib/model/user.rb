# -*- coding: utf-8 -*-
require 'rubytter'

module Model
  class User
    # --- class method ---
    
    def self.all
      self.collection.find.map{|user|
        self.new(user)
      }
    end

    def self.recommends(from_user)
      # 毎回変える，先頭に知ってる人
      self.all.delete_if {|user|
        user.user_id == from_user.user_id
      }.sort_by{|user|
        score = rand
        score += 1 if from_user.friends_ids.include? user.user_id
      }.reverse
    end

    def self.new_from_user_id(user_id)
      data = self.collection.find_one({:user_id => user_id})
      return nil unless data
      self.new(data)
    end

    def self.new_from_screen_name(screen_name)
      data = self.collection.find_one({:screen_name => screen_name})
      return nil unless data
      self.new(data)
    end

    def self.admin_user              # returns nottotterJP
      ADMIN_USER
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

      consumer = Model::Twitter.consumer
      access_token = Model::Twitter.access_token(consumer, self.access_token, self.access_secret)
      @rubytter = OAuthRubytter.new(access_token)
    end

    def profile
      @profile ||= Model::Cache.get_or_set("profile-#{self.user_id}") {
        Model.logger.info "get user profile #{self.screen_name}"
        self.rubytter.user(self.screen_name).to_hash
      }
    end

    # --- profile ---
    def profile_image_url
      self.profile[:profile_image_url]
    end

    def profile_name
      self.profile[:name]
    end

    def profile_description
      self.profile[:description]
    end

    def friends_ids
      @friends_ids ||= Model::Cache.get_or_set("friend_ids-#{self.user_id}", 3600) { # 同時に動かないから固定，friend増える可能性あるので少し短かめ
        Model.logger.info "get friend ids #{self.screen_name}"
        self.rubytter.friends_ids(self.user_id)
      }
    end

    def timeline
      return @timeline if @timeline
      @timeline ||= Model::Cache.get_or_set("timeline-#{self.user_id}", 30) {
        Model.logger.info "get timeline #{self.screen_name}"
        self.rubytter.friends_timeline.map{|status| status.to_hash}
      }.map{|status|
        Model::ActiveRubytter.new(status)
      }
    end
    
    # --- constants ---
    TOKEN, SECRET, ID, NAME = open(File.expand_path("~/.nottotter_admin")).read.split("\n")
    ADMIN_USER = User.register({
        :user_id => ID,
        :access_token => TOKEN, 
        :access_secret => SECRET,
        :screen_name => NAME
      })
    
  end
end
