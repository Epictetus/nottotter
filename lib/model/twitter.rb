require 'oauth'

module Model
  class Twitter
    CONSUMER_KEY, CONSUMER_SECRET = open(File.expand_path("~/.nottotter_token")).read.split("\n")

    def self.consumer
      OAuth::Consumer.new(
        CONSUMER_KEY,
        CONSUMER_SECRET,
        :site => 'http://api.twitter.com'
        )
    end
    
    def self.access_token(consumer, token, secret)
      OAuth::AccessToken.new(
        consumer, 
        token,
        secret
        )
    end
    
    def self.request_token(token, secret)
      request_token = OAuth::RequestToken.new(
        self.consumer,
        token,
        secret
        )
    end

    def self.get_request_token
      self.consumer.get_request_token(
        :oauth_callback =>
        "http://localhost:9393/callback"
        )
    end
  end
end
