require 'rubygems'
require 'mongo'
require 'sinatra'
require 'time'

include Mongo

class Chatter
    def initialize()
        host = ENV['MONGO_RUBY_DRIVER_HOST'] || 'localhost'
        port = ENV['MONGO_RUBY_DRIVER_PORT'] || MongoClient::DEFAULT_PORT

        puts "Connecting to #{host}:#{port}"
        @db = MongoClient.new(host, port).db('mydb')

        # Erase all records from collection, if any
        # coll.remove

        # Insert 3 records
        # 3.times { |i| coll.insert({'a' => i+1}) }

        # puts "There are #{coll.count()} records in the test collection. Here they are:"

    end
    def get_users()
        coll = @db.collection('users')
        coll.find().each { |doc|
            puts doc.inspect
        }
    end

    # check if the username has been taken already
    def check_user_exists(username)
        @db.collection('users').find({name => username}).nil?
    end

    def get_messages(id)
        coll = @db.collection('msg_queue')
        coll.find({'user'=>target})
        coll.remove({'user' => target})
        @db.collection('users').update({'user'=>targeti},{'exp_time' => Time.now.to_i + 300}) 
    end

    def broadcast(id, users, from, msg, timestamp)
        users.each{|user|
            send_message(id, user, from, msg, timestamp)
        }
    end

    def send_message(id, to, from, msg, timestamp)
        coll = @db.collection('msg_queue')
        coll.insert({"_id" => id, "to" => to, "from" => from, "msg" => msg, "timestamp"=>timestamp})
    end

    def connect(id, username, lat, lon)
        coll = @db.collection('users')
        if !check_user_exists(username)
            coll.insert({'_id' => id, 'name' => username, 'lat' => lat, 'lon' => lon, 'exp_time' => Time.now.to_i+300})
            return 0,"#{username} is ready to go"
        else
            puts "#{username} already exists"
            return  1,"#{username} already exists"
        end
    end

    def clean_users_collection()
        puts "cleaning"
        coll = @db.collection('users')
        users = coll.find()
        puts "got users"
        users.each{|user|
            if  user.inspect['exp_time'] < Time.now.to_i
                puts "4cleaning..."
                coll.remove({'_id' => user["_id"]})
                puts "5cleaning..."
            end
        }
        puts "end clean"
    end
end

chat = Chatter.new
Thread.new{
    loop do
        chat.clean_users_collection
        sleep 2
    end
}
puts "STARTING GEOCHATTER"
