require 'sinatra'
require 'erb'
require 'model'

class NottotterApp < Sinatra::Base
  def self.logger
    @logger ||= Logger.new($stdout)
  end

  helpers do
    alias_method :h, :escape_html

    def require_user
      current_user or redirect '/'
    end

    def require_hijack
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

      @current_hijack = Model::Hijack.new_from_user(current_user)
    end

    def current_hijacked_user
      return unless current_hijack
      return @current_hijacked_user if defined? @current_hijacked_user

      @current_hijacked_user = current_hijack.to_user
    end

  end

  use Rack::Session::Cookie, :secret => Model::Twitter::CONSUMER_KEY

  get '/' do
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
    
    Model::User.register({
        :user_id => access_token.params[:user_id],
        :access_token => access_token.params[:oauth_token],
        :access_secret => access_token.params[:oauth_token_secret],
        :screen_name => access_token.params[:screen_name]
      })
    
    session[:user_id] = access_token.params[:user_id]
    session.delete(:request_token)
    session.delete(:request_secret)
    redirect '/nottori/'
  end

  get '/logout' do
    session.delete(:user_id)
    redirect '/'
  end

  get "/nottori/" do
    require_user
    @users = Model::User.recommends(current_user)
    erb :nottori
  end

  post "/nottori/" do
    require_user
    to_user = Model::User.new_from_user_id(params[:user_id])
    from_user = Model::User.new_from_user_id(session[:user_id])
    Model::Hijack.create({
        :from_user => from_user,
        :to_user => to_user
      })
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
    @reply_id = params[:reply_id]
    @reply_user = params[:reply_user]
    erb :timeline
  end
  
  post "/timeline" do
    require_hijack
    user = Model::User.new_from_user_id(session[:user_id])
    @hijack = Model::Hijack.new_from_user(user)
    if params[:reply_id]
      @hijack.to_user.rubytter.update(
        params[:tweet],
        {:in_reply_to_status_id => params[:reply_id]})
    else
      @hijack.to_user.rubytter.update(params[:tweet])
    end
    redirect '/timeline'
  end

  get "/timeline.json" do
    "timeline json"
  end

end
