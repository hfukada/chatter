require 'rubygems'
require 'mongo'
require 'sinatra'

include Mongo

class chatter
    def initialize()
        host = ENV['MONGO_RUBY_DRIVER_HOST'] || 'localhost'
        port = ENV['MONGO_RUBY_DRIVER_PORT'] || MongoClient::DEFAULT_PORT

        puts "Connecting to #{host}:#{port}"
        db = MongoClient.new(host, port).db('mydb')

        # Erase all records from collection, if any
        # coll.remove

        # Insert 3 records
        # 3.times { |i| coll.insert({'a' => i+1}) }

        # puts "There are #{coll.count()} records in the test collection. Here they are:"

    end
    def get_users()
        coll = db.collection('users')
        coll.find().each { |doc|
            puts doc.inspect
        }
        coll.drop
    end

    # check if the username has been taken already
    def check_user_exists(username)
        db.collection('users').find({name => username}).nil?
    end

    get '/check_user:username' do
        check_users_exists(username)
    end
end
