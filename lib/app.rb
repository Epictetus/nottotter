require 'sinatra'
require 'erb'
require 'model'

class NottotterApp < Sinatra::Base
  def self.logger
    @logger ||= Logger.new($stdout)
  end

  helpers do
    alias_method :h, :escape_html

    def current_user
      return unless session[:user_id]
      return @current_user if defined? @current_user

      begin
        @current_user = Model::User.new_from_user_id(session[:user_id])
        return @current_user
      rescue => error
        p error
        session.delete[:user_id]
        return nil
      end
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
    @users = Model::User.all
    erb :nottori
  end

  post "/nottori/" do
    to_user = Model::User.new_from_user_id(params[:user_id])
    from_user = Model::User.new_from_user_id(session[:user_id])
    Model::Hijack.create({
        :from_user => from_user,
        :to_user => to_user
      })
    redirect '/timeline'
  end

  get "/nottori/:user" do
    "nottori #{params[:user]}"
  end

  get "/timeline" do
    p session[:user_id]
    user = Model::User.new_from_user_id(session[:user_id])
    @hijack = Model::Hijack.new_from_user(user)
    @to_user = @hijack.to_user.rubytter
    @timeline = @to_user.friends_timeline
    erb :timeline
  end

  post "/timeline" do
    "timeline post"
  end

  get "/timeline.json" do
    "timeline json"
  end

end
