$:.unshift(File.dirname(__FILE__))
$:.unshift(File.dirname(__FILE__) + '/lib')

require 'sinatra/base'
require 'logger'
require 'app'

# Thread.new {
#   Downloader.new.run
# }

run NottotterApp
