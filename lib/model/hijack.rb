# -*- coding: utf-8 -*-

# 乗っ取りを表わすモデル
# from_userに対して，closed=falseなレコードは0個か1個
# レコードは履歴表示などに使うかもしれないので，終わっても消さない

# スキーマ
# to_user_id   : 乗っ取り元ユーザーid
# from_user_id : 乗っ取り先ユーザーid
# start_on     : ハイジャック開始時刻
# finish_on    : ハイジャック終了時刻
# open         : 乗っ取り有効か？ アプリケーションが良いタイミングで更新する
#              : openだけど，finish_onは過ぎているレコードをcloseして，ユーザーに通知
#              : 別のユーザーを乗っ取りに行ったときに，古いハイジャックをcloseする


module Model
  class Hijack
    # --- constants ---
    EXPIRE = 60 * 5             # 5 minutes
    # --- class method ---

    # タイムアウトにすべき(should_closeな)Hijackがあれば返す
    def self.new_expired_from_user(user) # user is from user
      raise "#user must be kind of Model::User" unless user.kind_of? Model::User
      found = self.collection.find({:from_user_id => user.user_id, :open => true}, {:sort => [:start_on, :desc], :limit => 1}).to_a.first
      return unless found
      me = self.new(found)
      return unless me.should_close?
      me
    end

    # 有効なHijackを1つ返す
    # タイムアウト処理がなされてないopenなHijackは返さない
    def self.new_from_user(user) # user is from user
      raise "#user must be kind of Model::User" unless user.kind_of? Model::User
      found = self.collection.find({:from_user_id => user.user_id, :open => true}, {:sort => [:start_on, :desc], :limit => 1}).to_a.first
      return unless found
      me = self.new(found)
      return if me.should_close?
      me
    end

    def self.new_from_status_id(status_id)
      found = self.collection.find_one({:tweets => {:$elemMatch => {:id_str => status_id.to_s, :deleted => { :$exists =>  false }}}})
      return unless found
      self.new(found)
    end

    def self.create(data)
      %w{from_user to_user}.map(&:to_sym).each{|key|
        raise "data must have #{key}" unless data.has_key? key
        raise "#{key} must be kind of Model::User" unless data[key].kind_of? Model::User
      }

      from_user = data[:from_user]
      to_user = data[:to_user]

      old_hijack = self.new_from_user(from_user)
      old_hijack.close! if old_hijack

      self.collection.insert({
          :from_user_id => from_user.user_id,
          :to_user_id => to_user.user_id,
          :start_on => Time.now,
          :finish_on => Time.now + EXPIRE,
          :open => true,
        })

      me = self.new_from_user(from_user)
      Model.logger.info "#{me.from_user.screen_name} start hijack #{me.to_user.screen_name}"
      me

    end

    def initialize(data)        # private
      @data = data
    end

    def self.collection # private
      Model::Database.collection('hijack')
    end

    # --- history ---
    def self.history(params = {})
      # params: :to_user, :from_user, :any_user
      if params[:any_user]
        user = params[:any_user]
        query = {:$or => [{:from_user_id => user.user_id}, {:to_user_id => user.user_id}]}
      else
        query = {}
        from_user = params[:from_user]
        to_user = params[:to_user]
        query[:from_user_id] = from_user.user_id if from_user
        query[:to_user_id] = to_user.user_id if to_user
      end

      self.collection.find(query, {:sort => [:start_on, :desc]}).to_a.map{|found|
        self.new(found)
      }
    end

    # --- instance method ---

    def verify_credentials
      from_user.verify_credentials
      to_user.verify_credentials
    end

    # --- attributes ---

    def _id
      @data['_id']
    end


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

    def avail_tweets
      tweets.delete_if{|s| s.deleted }
    end

    def tweets
      @tweets ||= (@data['tweets'] || []).map{|status|
        Model::ActiveRubytter.new(status)
      }
    end

    def delete_status(status_id)
      begin
        status_id = status_id.to_s
        Model.logger.warn "delete status #{status_id}"
        to_user.rubytter{|r| r.remove_status(status_id) }
        self.class.collection.update({'tweets.id_str' => status_id}, {:$set => {'tweets.$.deleted' => 1}})
      rescue => error
        Model.logger.warn "#{error.class}: #{error.message}"
      end
    end

    def finish_on_milliseconds
      finish_on.to_i * 1000
    end

    def remain_seconds
      finish_on - Time.now
    end

    def any_user?(user)
      from_user.user_id == user.user_id || to_user.user_id == user.user_id
    end

    # --- tweet ---
    def tweet(text, params)
      tweet = to_user.tweet text, params
      return if ENV['NO_TWEET'] 
      self.update(:$push => {:tweets => tweet})
      to_user.refresh_timeline
    end

    def tweet_count
      tweets.length
    end

    # --- session ---
    def open?
      @data['open']
    end

    def should_close?
      open? && finish_on < Time.now
    end

    def close!
      return unless open?
      self.update(:$set => {:open => false})
      @data['open'] = false
      notice_close
    end

    def update(params)
      self.class.collection.update({:_id => self._id}, params)
    end

    # --- notification ---
    def notice_start
      history = from_user.hijack_history(to_user)
      if history.length > 1
        duration = seconds_to_duration(history[0].start_on - history[1].start_on)
        count = history.length
        status = "#{duration}ぶり#{count}回目"
      else
        status = "1回目"
      end

      [Model::User::ADMIN_USER, to_user].each{|user|
        user.tweet "@#{from_user.screen_name} さんが @#{to_user.screen_name} さんを乗っ取りましたl. (#{status}) #nottotterJP"
      }
    rescue => error
      Model.logger.warn "#{error.class}: #{error.message}"
    end

    def notice_start_dm
      to_user.send_direct_message(
        :user => to_user.user_id,
        :text => "【緊急】@#{to_user.screen_name}さんのTwitterアカウントが@#{to_user.screen_name}さんに乗っ取られました.  こちらのURLより乗っ取り返しましょう. http://nottotter.com/nottori/#{to_user.screen_name} #{Model::AAMaker.make}"
        )
    rescue => error
      Model.logger.warn "#{error.class}: #{error.message}"
    end

    def notice_close
      [Model::User::ADMIN_USER, to_user].each{|user|
        user.tweet "@#{from_user.screen_name} さんの乗っ取りが終了しました. #{Model::AAMaker.make} #nottotterJP"
      }
    rescue => error
      Model.logger.warn "#{error.class}: #{error.message}"
    end

    def seconds_to_duration(seconds)
      seconds = seconds.to_i
      if seconds < 60
        "#{seconds}秒"
      elsif seconds < 60 * 60
        minutes = seconds / 60
        "#{minutes}分"
      elsif seconds < 60 * 60 * 24
        hours = seconds / (60 * 60)
        "#{hours}時間"
      else
        days = seconds / (60 * 60 * 24)
        "#{days}日"
      end
    end

  end
end
