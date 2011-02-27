$:.unshift(File.join(File.dirname(__FILE__),  '..', 'lib'))
require 'model'
require 'pp'

warn 'register'
user_name = 'test_user' + rand.to_s
user_id = rand.to_s
user = Model::User.register({:screen_name => user_name, :user_id => user_id, :access_token => 'at' + rand.to_s, :access_secret => 'as' + rand.to_s})
pp user

warn 'attributes'
p user.key
p user.screen_name
p user.access_token
p user.access_secret

warn 'new_from_screen_name'
pp Model::User.new_from_screen_name(user_name)

warn 'new_from_user_id'
pp Model::User.new_from_user_id(user_id)
