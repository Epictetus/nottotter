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
    @users = Model::User.all
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
    require_user
    "nottori #{params[:user]}"
  end

  get "/timeline" do
    require_hijack
    user = Model::User.new_from_user_id(session[:user_id])
    @hijack = Model::Hijack.new_from_user(user)
    @to_user = @hijack.to_user.rubytter
    @timeline = @to_user.friends_timeline
    erb :timeline
  end
  
  post "/timeline" do
    require_hijack
    user = Model::User.new_from_user_id(session[:user_id])
    @hijack = Model::Hijack.new_from_user(user)
    @hijack.to_user.rubytter.update(params[:tweet])
    redirect '/timeline'
  end

  get "/timeline.json" do
    "timeline json"
  end

end
