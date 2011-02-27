require 'oauth'

module Model
  class Oauth
    CONSUMER_KEY, CONSUMER_SECRET = open(File.expand_path("~/.nottotter_token")).read.split("\n")

    def self.consumer
      OAuth::Consumer.new(
        CONSUMER_KEY,
        CONSUMER_SECRET,
        :site => 'http://api.twitter.com',
        )
    end
    
    def self.access_token(consumer, token, secret)
      OAuth::AccessToken.new(
        consumer, 
        token,
        secret)
    end
  end
end
