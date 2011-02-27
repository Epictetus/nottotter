$:.unshift(File.join(File.dirname(__FILE__),  '..', 'lib'))
require 'model'
require 'pp'

warn 'register 2 user'
from_user = Model::User.register({:screen_name => 'from_user' + rand.to_s, :access_token => 'at' + rand.to_s, :access_secret => 'as' + rand.to_s})
to_user = Model::User.register({:screen_name => 'to_user' + rand.to_s, :access_token => 'at' + rand.to_s, :access_secret => 'as' + rand.to_s})

warn 'create hijack'
hijack1 = Model::Hijack.create({:from_user => from_user, :to_user => to_user})
pp hijack1

warn 'attributes'
p hijack1.key
p hijack1.from_user
p hijack1.to_user
p hijack1.start_on
p hijack1.finish_on
p hijack1.alive?


warn 'new_from_user'
hijack2 = Model::Hijack.new_from_user(from_user)
p hijack2.key

warn 'new_from_user with bad user should be nil'
hijack3 = Model::Hijack.new_from_user(to_user)
p hijack3
