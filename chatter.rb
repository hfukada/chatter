require 'mongo'
require 'pp'

include Mongo

host = ENV['MONGO_RUBY_DRIVER_HOST'] || 'localhost'
port = ENV['MONGO_RUBY_DRIVER_PORT'] || MongoClient::DEFAULT_PORT

puts "Connecting to #{host}:#{port}"
client  = MongoClient.new(host, port)
db   = client.db('ruby-mongo-examples')
coll = db.create_collection('test')

# Erase all records from collection, if any
coll.remove

admin = client['admin']

# Profiling level set/get
puts "Profiling level: #{admin.profiling_level}"

# Start profiling everything
admin.profiling_level = :all

# Read records, creating a profiling event
coll.find().to_a

# Stop profiling
admin.profiling_level = :off

# Print all profiling info
pp admin.profiling_info

# Validate returns a hash if all is well and
# raises an exception if there is a problem.
info = db.validate_collection(coll.name)
puts "valid = #{info['ok']}"
puts info['result']

# Destroy the collection
coll.drop

