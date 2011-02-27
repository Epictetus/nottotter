require 'sinatra'
require 'erb'
require 'model'

class NottotterApp < Sinatra::Base
  def self.logger
    @logger ||= Logger.new($stdout)
  end

  get '/' do
    erb :index
  end

  get "/nottori/" do
    "select nottori user"
  end

  post "/nottori/" do
    "post nottori"
  end

  get "/nottori/:user" do
    "nottori #{params[:user]}"
  end

  get "/timeline" do
    "timeline"
  end

  post "/timeline" do
    "timeline post"
  end

  get "/timeline.json" do
    "timeline json"
  end

end
