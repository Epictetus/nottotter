$:.unshift(File.join(File.dirname(__FILE__),  '..', 'lib'))
require 'model'

key = rand.to_s

warn 'get_or_set'
p Model::Cache.get_or_set(key) {
  warn 'block called'
  Time.now
}

warn 'get_or_set'
p Model::Cache.get_or_set(key) {
  warn 'block called'
  Time.now
}
