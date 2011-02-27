$:.unshift(File.join(File.dirname(__FILE__),  '..', 'lib'))
require 'model'
require 'pp'

warn 'register'
pp Model::User.register({:screen_name => 'test_user', :access_token => 'at' + Time.now.to_s, :access_secret => 'ac' + Time.now.to_s})

warn 'new_from_screen_name'
user = Model::User.new_from_screen_name('test_user')
pp user


warn 'attributes'
p user.key
p user.screen_name
p user.access_token
p user.access_secret

warn 'new_from_key'
user2 = Model::User.new_from_key(user.key)
pp user2

