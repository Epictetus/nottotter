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
          :open => true,
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

    def remain_seconds
      finish_on - Time.now
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
      self.class.collection.update({:_id => self._id}, {:$set => {:open => false}})
      @data['open'] = false
      # notice_close
    end

    # --- notification ---
    def notice_close
      to_user.rubytter.update("@#{from_user.screen_name} さんののっとりが終了しました. (#{finish_on.localtime.strftime("%H時%M分")}) #nottotterJP")
    rescue => error
      Model.logger.warn error
    end

  end
end
