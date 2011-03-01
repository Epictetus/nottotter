# -*- coding: utf-8 -*-
require 'sinatra'
require 'erb'
require 'model'
require 'rack/flash'

class NottotterApp < Sinatra::Base
  def self.logger
    @logger ||= Logger.new($stdout)
  end

  helpers do
    alias_method :h, :escape_html
    
    def tweet_filter(text)
      escape_html(text).gsub(/@([\w_]+)/){
        m = $1
        "<a href='http://twitter.com/#{m}'>@#{m}</a>"
      }.gsub(/#([\w_]+)/){
        m = $1
        "<a href='http://twitter.com/search?q=##{m}/'>##{m}</a>"
      }
    end
    
    def bg_user
      @bg_user = (@bg_user and defined? @bg_user)? @bg_user : Model::User.admin_user
    end
    
    def background_tag
      return "<style> body { background-color: #{bg_user.profile_background_color};\
background-image: url(#{bg_user.profile_background_image_url});\
background-repeat: #{bg_user.profile_background_tile};}</style>"
    end

    def tweet_style_tag
      return "<style> .tweet { color: #{bg_user.profile_text_color};} \
.tweet a { color: #{bg_user.profile_link_color};}</style>"
    end

    def require_user
      current_user or redirect '/'
    end

    def require_hijack
      expired_hijack and redirect '/timeout'
      current_hijack or redirect '/'
    end

    def current_user
      return unless session[:user_id]
      return @current_user if defined? @current_user

      @current_user = Model::User.new_from_user_id(session[:user_id])
    end

    def current_hijack
      return unless current_user
      return @current_hijack if defined? @current_hijack

      @current_hijack = current_user.current_hijack
    end

    def current_hijacked_user
      return unless current_hijack
      return @current_hijacked_user if defined? @current_hijacked_user

      @current_hijacked_user = current_hijack.to_user
    end

    def require_expired_hijack
      expired_hijack or redirect '/'
    end

    def expired_hijack
      return unless current_user
      return @expired_hijack if defined? @expired_hijack

      @expired_hijack = current_user.expired_hijack
    end

  end

  use Rack::Session::Cookie, :secret => Model::Twitter::CONSUMER_KEY
  use Rack::Flash

  get '/' do
    redirect '/timeline' if current_hijack
    erb :index
  end

  get '/oauth' do
    request_token = Model::Twitter.get_request_token()
    session[:request_token] = request_token.token
    session[:request_secret] = request_token.secret
    redirect request_token.authorize_url
  end

  get '/callback' do
    request_token = Model::Twitter.request_token(
      session[:request_token],
      session[:request_secret]
      )
    
    access_token = request_token.get_access_token(
      {},
      :oauth_token => params[:oauth_token],
      :oauth_verifier => params[:oauth_verifier])
    
    session.delete(:request_token)
    session.delete(:request_secret)
    
    user = Model::User.register({
        :user_id => access_token.params[:user_id],
        :access_token => access_token.params[:oauth_token],
        :access_secret => access_token.params[:oauth_token_secret],
        :screen_name => access_token.params[:screen_name]
      })
    
    if user.profile[:protected]
      Model::User.remove(user)
      return erb :user_protected
    end
    
    session[:user_id] = access_token.params[:user_id]
    redirect '/nottori/'
  end

  get '/logout' do
    session.delete(:user_id)
    redirect '/'
  end

  get '/timeout' do
    require_expired_hijack
    expired_hijack.close!
    erb :timeout
  end

  get "/nottori/" do
    require_user
    @bg_user = current_user
    @users = Model::User.recommends(current_user)
    erb :nottori
  end

  post "/nottori/" do
    require_user
    to_user = Model::User.new_from_user_id(params[:user_id])

    hijack = current_user.hijack!(to_user)

    redirect '/timeline'
  end

  get "/nottori/:user" do
    to_user = Model::User.new_from_screen_name(params[:user])
    unless to_user
      @not_found_to_user = params[:user]
      return erb :user_not_found
    end
    @users = [to_user]
    erb :nottori
  end

  get "/timeline" do
    require_hijack
    @bg_user = current_hijacked_user
    @timeline = current_hijacked_user.timeline
    erb :timeline
  end
  
  post "/timeline" do
    require_hijack
    tweet_params = {}
    
    if params[:reply_id]
      tweet_params[:in_reply_to_status_id] = params[:reply_id]
    end
    
    begin
      current_hijack.tweet params[:tweet], tweet_params
    rescue => error
      flash[:tweet_error] = "投稿に失敗しました。"
      Model.logger.warn "#{error.class}: #{error.message}"
    end
    redirect '/timeline'
  end

  get "/timeline.json" do
    require_hijack
    content_type :json
    JSON.unparse({
        :remin_seconds => current_hijack.remain_seconds,
        :timeline => current_hijacked_user.timeline.map{|status| status.to_hash}
      })
  end

  get "/history" do
    @history = Model::Hijack.history
    erb :history
  end

  post "/delete" do
    begin
      require_user
      halt 400 unless params[:id]
      current_user.delete_status(params[:id])
      redirect params[:location] || '/'
    rescue => error
      Model.logger.warn "#{error.class}: #{error.message}"
      halt 400
    end
  end



  logger.warn "env NO_TWEET is not set. Tweets will be posted." unless ENV['NO_TWEET']
end
