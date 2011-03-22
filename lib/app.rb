# -*- coding: utf-8 -*-
require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'erb'
require 'model'

class NottotterApp < Sinatra::Base
  def self.logger
    @logger ||= Logger.new($stderr)
  end

  helpers do
    alias_method :h, :escape_html
    
    def tweet_filter(text)
      escape_html(text).gsub(/@([\w_]+)/){ 
        "<a href='http://twitter.com/#!/#{$1}'>@#{$1}</a>"
      }.gsub(/#([\w_]+)/){
        "<a href='http://twitter.com/#!/search?q=%23#{$1}'>##{$1}</a>"
      }
    end
    
    def tweet_tag(status, location = nil, hijacked_from = nil)
      erb :tweet, :locals => { 
        :status => status, 
        :location => location,
        :hijacked_from => hijacked_from
      }
    end

    def ymd(time)
      time.strftime('%Y年%m月%d日')
    end
    
    def icon_list_tag(users, count = 7)
      erb :icon_list, :locals => {:users => users , :count => count}
    end

    def user_profile_tag(user)
      hijack = Model::Hijack.history({:from_user => user})
      hijacked = Model::Hijack.history({:to_user => user}) 
      hijack_users = hijack.map{|h| h.to_user }.uniq
      hijacked_users = hijacked.map{|h| h.from_user }.uniq
      erb :user_profile , :locals => {
        :user => user,
        :hijack => hijack,
        :hijack_users => hijack_users,
        :hijacked => hijacked,
        :hijacked_users => hijacked_users
      }
    end

    def user_style_tag(user)
      user = Model::User.admin_user if user.nil? or !(defined? user)
      erb :user_style, :locals => { :user => user }
    end

    def require_user
      current_user or redirect '/'
    end

    def require_token
      params[:token] or halt 400, 'token required'
      params[:token] == current_user.token or halt 400, 'token not match'
    end

    def require_hijack
      expired_hijack and redirect '/timeout'
      current_hijack or redirect '/'
    end

    def current_user
      return @current_user if defined? @current_user
      return unless session[:user_id]

      @current_user = Model::User.new_from_user_id(session[:user_id])
      @current_user = nil unless @current_user.open?
      @current_user
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

  set :show_exceptions, false
  set :logging, true

  error Model::User::OAuthRevoked do
    error = request.env['sinatra.error']
    error.user.close!

    hijack = current_hijack || expired_hijack
    hijack.close!

    session.delete(:user_id) if error.user.screen_name == current_user.screen_name
    
    halt 401, error.user.screen_name if request.xhr?

    if error.user.screen_name == current_user.screen_name
      redirect "/revoked"
    else
      redirect "/nottori/#{error.user.screen_name}"
    end
  end

  before do
    if request.request_method == "POST"
      current_user.verify_credentials if current_user
    end
  end

  error do
    status 500
    Model.logger.warn request.env['sinatra.error'].message
    'sorry... '
  end

  use Rack::Session::Cookie, :secret => Model::Twitter::CONSUMER_KEY

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
    
    begin
      access_token = request_token.get_access_token(
        {},
        :oauth_token => params[:oauth_token],
        :oauth_verifier => params[:oauth_verifier])
    rescue => error
      Model.logger.warn "#{error.class}: #{error.message}"
      halt 400
    end
    session.delete(:request_token)
    session.delete(:request_secret)
    
    user = Model::User.register({
        :user_id => access_token.params[:user_id],
        :access_token => access_token.params[:oauth_token],
        :access_secret => access_token.params[:oauth_token_secret],
        :screen_name => access_token.params[:screen_name],
        :open => true
      })
    
    if user.admin_user?
      user.update_admin
    end

    if user.profile[:protected]
      Model::User.remove(user) unless user.admin_user?
      return erb :user_protected
    end
    
    session[:user_id] = access_token.params[:user_id]
    redirect current_hijack ? '/timeline' : '/nottori'
  end

  get '/revoked' do
    erb :revoked
  end

  get '/logout' do
    current_hijack and current_hijack.close!
    session.delete(:user_id)
    redirect '/'
  end

  get '/timeout' do
    erb :timeout
  end

  post '/timeout' do
    hijack = current_hijack || expired_hijack
    hijack or halt 400
    hijack.close!
    'OK'
  end

  get "/nottori/?" do
    require_user
    @users = Model::User.recommends(current_user)
    erb :nottori
  end

  post "/nottori" do
    require_user
    require_token
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
    @timeline = current_hijacked_user.timeline
    erb :timeline
  end
  
  get "/get_timeline" do
    require_hijack
    erb :get_timeline
  end

  post "/timeline" do
    require_hijack
    require_token
    tweet_params = {}
    
    if params[:reply_id]
      tweet_params[:in_reply_to_status_id] = params[:reply_id]
    end
    
    error_message = false

    begin
      tweet = params[:tweet]
      raise if tweet =~ /^d\s/i
      raise if tweet =~ /^set\slocation\s/i
      tweet = params[:tweet].gsub(/^[dD] /, "")
      tweet = tweet + " #nottotterJP"

      current_hijack.tweet tweet, tweet_params
    rescue => error
      error_message = "投稿に失敗しました。"
      Model.logger.warn "#{error.class}: #{error.message}"
      halt 400, error.message
    end
    
    erb :get_timeline
  end

  get "/history" do
    @history = Model::Hijack.history.select{ |h| h.avail_tweets.length > 0 }
    erb :history
  end

  post "/delete" do
    require_user
    require_token
    begin
      halt 400 unless params[:id]
      current_user.delete_status(params[:id])
      "ok"
    rescue => error
      Model.logger.warn "#{error.class}: #{error.message}"
      halt 400
    end
  end

end
