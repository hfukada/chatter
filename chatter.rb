require 'rubygems'
require 'mongo'
require 'sinatra'
require 'time'
require 'json'
require 'yaml'

include Mongo

class Chatter
    def initialize()
        host = ENV['MONGO_RUBY_DRIVER_HOST'] || 'localhost'
        port = ENV['MONGO_RUBY_DRIVER_PORT'] || MongoClient::DEFAULT_PORT

        puts "Connecting to #{host}:#{port}"
        @db = MongoClient.new(host, port).db('mydb')

        users = @db.collection('users')
        users.ensure_index({:gpos => Mongo::GEO2DSPHERE})

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
        @db.collection('users').find({'name' => username}).nil?
    end

    def get_messages(target)
        users = @db.collection('users').find({ 'user' => target })

        if users.count != 1
            return []
        end

        coll = @db.collection('msg_queue')
        messages = coll.find({'user'=>target})
        coll.remove({'user' => target})
        user = users.first
        @db.collection('users').update({'user' => user['user']},{'exp_time' => Time.now.to_i + 300}) 
        messages.map {|m| m.to_json }
    end

    def update_gpos(id, lat, lon)
        @db.collection('users').update({'_id' => id}, { gpos: { type:  'Point', coordinates: [lat, lon] }})
    end

    def broadcast_to(id, users, msg, timestamp)
        users.each{|user|
            send_message(id, user, from, msg, timestamp)
        }
    end

    def broadcast(id, lat, lon, msg, timestamp)
        users = find_local_users(lat, lon).map {|user| user[:id] }
        broadcast_to(id, users, msg, timestamp)
    end

    def send_message(id, to, from, msg, timestamp)
        coll = @db.collection('msg_queue')
        coll.insert({"_id" => id, "to" => to, "msg" => msg, "timestamp"=>timestamp})
    end

    def find_local_users(lat, lon)
        @db.collection('users').find({
            gpos: {
                '$near' => {
                    '$geometry' => {
                        type: 'Point',
                        coordinates: [lat, lon]
                    },

                    '$maxDistance' => 500
                }
            }
        })
    end

    def connect(id, username, lat, lon)
        coll = @db.collection('users')
        if !check_user_exists(username)
            coll.insert({
                'user' => id, 
                'name' => username, 
                'gpos' => { type: 'Point',
                            coordinates: [0, 0]},
                'exp_time' => Time.now.to_i+300})

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
                coll.remove({'_id' => user["_id"]})
            end
        }
        puts "end clean"
    end
end

chat = Chatter.new

def __entry
    Thread.new{
        loop do
            chat.clean_users_collection
            sleep 25
    end
    }
    puts "STARTING GEOCHATTER"
end

configure do
    set :port => 80
    set :public_folder, File.dirname(__FILE__) + '/pub'
end

get '/getmessages/:id' do |id|
    # get list of messages from mongo
    chat.get_messages(id).to_json
end

get '/broadcast/:id/:lat/:lon/:message' do |id, lat, lon, message|
    chat.broadcast(id, lat, lon, message, Time.now)
end

get '/connect/:name/:lat/:long' do |name, latitude, longitude|
    idToken = Digest::SHA256.new.hexdigest "#{name}#{Time.now}"
    e,m = chat.connect(idToken, name, latitude, longitude)

    if e != 0 
        puts m 
        return { status: 'ERR', message: m }.to_json
    end

    return { status: 'OK', token: idToken }.to_json
end

get '/update_gpos/:id/:lat/:long' do |id, lat, lon|
    chat.update_gpos(id, lat, lon)
end

__entry
