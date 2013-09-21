require 'rubygems'
require 'mongo'

include Mongo

host = ENV['MONGO_RUBY_DRIVER_HOST'] || 'localhost'
port = ENV['MONGO_RUBY_DRIVER_PORT'] || MongoClient::DEFAULT_PORT

puts "Connecting to #{host}:#{port}"
db = MongoClient.new(host, port).db('local')
coll = db.collection('users')
# Erase all records from collection, if any
# coll.remove

# Insert 3 records
# 3.times { |i| coll.insert({'a' => i+1}) }

# puts "There are #{coll.count()} records in the test collection. Here they are:"
coll.find().each { |doc|
  puts doc.inspect
}

# Destroy the collection
coll.drop
