# -*- coding: utf-8 -*-
require 'rubytter'
require 'digest/sha1'

module Model
  class User

    # --- class method ---
    
    def self.all
      self.collection.find({:open => true}).map{|user|
        self.new(user)
      }
    end

    def self.recommends(from_user)
      # 毎回変える，先頭に知ってる人
      self.all.delete_if {|user|
        user.user_id == from_user.user_id or user.admin_user? or !from_user.can_hijack(user)
      }.sort_by{|user|
        score = rand
        score += 1.0 if from_user.friends_ids.include? user.user_id.to_i
        score
      }.reverse[0..40]
    end

    def self.new_from_user_id(user_id)
      data = self.collection.find_one({:user_id => user_id})
      return nil unless data
      self.new(data)
    end

    def self.new_from_screen_name(screen_name)
      data = self.collection.find_one({:screen_name => screen_name, :open => true})
      return nil unless data
      self.new(data)
    end

    def self.admin_user              # returns nottotterJP
      ADMIN_USER
    end

    def admin_user?
      return false
      self.user_id == ADMIN_USER.user_id 
    end

    def self.register(data)
      %w{screen_name user_id access_token access_secret}.map(&:to_sym).each{|key|
        raise "data must have #{key}" unless data.has_key? key
      }
      self.collection.update({:user_id => data[:user_id]}, data, {:upsert => true}) # update by user id
      self.new_from_user_id(data[:user_id])
    end


    def self.remove(user)
      raise "#user must be kind of Model::User" unless user.kind_of? Model::User
      self.collection.remove({:user_id => user.user_id})
    end

    def self.count
      Model::Cache.get_or_set("user-count", 600){
        self.collection.find({:open => true}).count
      }
    end
    
    def initialize(data)        # private
      @data = data
    end

    def self.collection # private
      Model::Database.collection('user')
    end

    # --- instance method ---
    def _id
      @data['_id']
    end

    def update(params)
      self.class.collection.update({:_id => self._id}, params)
    end

    def token
      Digest::SHA1.hexdigest(self.key + "aaaaa")
    end
   
    def close!
      self.update(:$set => {:open => false})
      @data['open'] = false
    end

    def hash
      self.user_id.hash
    end

    def eql?(comp)
      self.user_id == comp.user_id
    end

    def update_admin
      open(File.expand_path("~/.nottotter_admin"), "w"){|f|
        f.puts [self.access_token, self.access_secret, self.user_id, self.screen_name].join("\n")
      }
      Model.logger.info("update admin token")
    end

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

    def open?
      @data['open']
    end

    def allow_from_all
      @data['allow_from_all']
    end

    def can_hijack(to_user)
      self.user_id == to_user.user_id || to_user.allow_from_all || self.followers_ids.include?(to_user.user_id.to_i)
    end

    # --- twitter ---

    def verify_credentials
      self.rubytter{|r| r.verify_credentials }
    end

    class OAuthRevoked < Exception
      attr_reader :user
      def initialize(msg, user = nil)
        super(msg)
        @user = user
      end
    end

    def rubytter                # returns rubytter instance
      unless @rubytter
        consumer = Model::Twitter.consumer
        access_token = Model::Twitter.access_token(consumer, self.access_token, self.access_secret)
        @rubytter = OAuthRubytter.new(access_token)
      end

      if block_given?
        begin
          yield @rubytter
        rescue Rubytter::APIError => error
          Model.logger.warn error.message
          if error.message == "Could not authenticate with OAuth."
            raise OAuthRevoked.new(error.message, self)
          else
            raise error
          end
        end
      else
        @rubytter
      end
    end

    def profile
      @profile ||= Model::Cache.get_or_set("profile-#{self.user_id}") {
        Model.logger.info "get user profile #{self.screen_name}"
        begin
          self.rubytter{|r|
            r.user(self.screen_name)
          }.to_hash
        rescue
          {}
        end
      }
    end

    def tweet(status, options = {})
      Model.logger.info "#{screen_name} tweet #{status}"
      if ENV['NO_TWEET']
        Model.logger.info "skip because NO_TWEET mode"
        'ok'
      else
        rubytter{|r|
          r.update(status, options)
        }.to_hash unless ENV['NO_TWEET']
      end
    end

    def send_direct_message(params)
      Model.logger.info "#{screen_name} send DM to #{params[:user]} #{params[:text]}"
      if ENV['NO_TWEET']
        Model.logger.info "skip because NO_TWEET mode"
      else
        rubytter{|r|
          r.send_direct_message(params)
        }
      end
    end

    def can_delete_status(status_id)
      hijack = Model::Hijack.new_from_status_id(status_id.to_s)
      return false unless hijack
      return false unless hijack.to_user.open?
      hijack.any_user?(self)
    end

    def delete_status(status_id) # XXX: status_id.....
      raise 'cannot delete that status' unless can_delete_status(status_id)
      hijack = Model::Hijack.new_from_status_id(status_id)
      hijack.delete_status(status_id)
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

    def profile_background_color
      "##{self.profile[:profile_background_color]}"
    end
    
    def profile_background_image_url
      self.profile[:profile_background_image_url]
    end

    def profile_background_tile
      self.profile[:profile_background_tile]? "repeat" : "no-repeat"
    end

    def profile_text_color
      "##{self.profile[:profile_text_color]}"
    end
    
    def profile_link_color
      "##{self.profile[:profile_link_color]}"
    end

    def friends_ids
      @friends_ids ||= Model::Cache.get_or_set("friend_ids-#{self.user_id}", 3600) {
        Model.logger.info "get friend ids #{self.screen_name}"
        self.rubytter{|r|
          r.friends_ids(self.user_id)
        }
      }
    end

    def followers_ids
      @followers_ids ||= Model::Cache.get_or_set("followers_ids-#{self.user_id}", 3600) {
        Model.logger.info "get follower ids #{self.screen_name}"
        self.rubytter{|r|
          r.followers_ids(self.user_id)
        }
      }
    end

    def blocking_ids
      @blocking_ids ||= Model::Cache.get_or_set("blocking_ids-#{self.user_id}", 3600) {
        Model.logger.info "get blocking ids #{self.screen_name}"
        self.rubytter{|r|
          r.blocking_ids
        }
      }
    end

    def protected_filter(timeline)
      timeline.select {|status| !status[:user][:protected]}
    end
    
    def timeline
      return @timeline if @timeline
      @timeline ||= Model::Cache.get_or_set("timeline-#{self.user_id}", 30) {
        Model.logger.info "get timeline #{self.screen_name}"
        protected_filter(self.rubytter{|r| r.friends_timeline}.map{|status| status.to_hash})
      }.map{|status|
        Model::ActiveRubytter.new(status)
      }
    end
    
    def refresh_timeline
      return @refreshed if @refreshed
      @refreshed ||= Model::Cache.force_set(
        "timeline-#{self.user_id}",
        protected_filter(self.rubytter{|r| r.friends_timeline}.map{|status| status.to_hash}
          ),
        30
        )
    end

    # --- relations ---
    def hijack!(to_user)
      raise "You cannot hijack this user." unless self.can_hijack(to_user) && !to_user.blocking_ids.include?(self.user_id.to_i) && !self.blocking_ids.include?(to_user.user_id.to_i)

      hijack = Model::Hijack.create(
        :from_user => self,
        :to_user => to_user
        )
      hijack.notice_start
      hijack.notice_start_dm
      true
    end

    def current_hijack
      Model::Hijack.new_from_user(self)
    end

    def expired_hijack
      Model::Hijack.new_expired_from_user(self)
    end

    # ユーザーが関わったHijack全部(ページャとかは将来的に)
    def history
      Model::Hijack.history(:any_user => self)
    end

    # from_userがユーザーなhistory
    def hijack_history(to_user = nil)
      Model::Hijack.history(:from_user => self, :to_user => to_user)
    end

    # to_userがユーザーであるHistory
    def hijacked_history(from_user = nil)
      Model::Hijack.history(:from_user => from_user, :to_user => self)
    end

    # from_userがユーザーの最新のHijack，引数でto_user指定可
    def last_hijack(to_user = nil)
      hijack_history(to_user).first
    end

    # to_userがユーザーの最新のHijack，引数でfrom_user指定可
    def last_hijacked(from_user = nil)
      hijacked_history(from_user).first
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
