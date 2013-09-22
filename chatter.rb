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
        puts users

        if users.count < 1
            return []
        end

        coll = @db.collection('msg_queue')
        messages = coll.find({'to'=>target})
        
        messages.each{|m| m.each{|i|  puts i.to_json}}
        coll.remove({'user' => target})
        user = users.first
        @db.collection('users').update({'user' => user['user']},{'exp_time' => Time.now.to_i + 300}) 
        puts messages
        i = []
        messages.map {|m|  i += m.to_json }
        return i
    end

    def update_gpos(id, lat, lon)
        @db.collection('users').update({'user' => id}, { 'gpos' => { 'type'=>  'Point', 'coordinates' => [lat, lon] }})
    end

    def broadcast_to(id, users, msg, timestamp)
        from = @db.collection('users').find({'user'=>id}).first
        users.each{|user|
            send_message(id, user, from, msg, timestamp)
        }
    end

    def broadcast(id, lat, lon, msg, timestamp)
        users = find_local_users(lat, lon).map {|user| user['user'] }
        puts "wat"
        puts users
        users.map{ |m| puts m.to_json}
        broadcast_to(id, users, msg, timestamp)
    end

    def send_message(id, to, from, msg, timestamp)
        coll = @db.collection('msg_queue')
        coll.insert({"user" => id, "to" => to, "msg" => msg, "timestamp"=>timestamp})
    end

    def find_local_users(lat, lon)
        @db.collection('users').find({
            gpos: {
                '$near' => {
                    '$geometry' => {
                        'type' => 'Point',
                        'coordinates' => [lat, lon]
                    },

                    '$maxDistance' => 500
                }
            }
        })
    end

    def connect(id, username, lat, lon)
        coll = @db.collection('users')
        if !check_user_exists(username)
           # coll.insert({
           #     'user' => id, 
           #     'name' => username, 
           #     'gpos' => { 'type' => 'Point',
           #                 'coordinates' => [lat, lon]},
           #     'exp_time' => Time.now.to_i+300})
            coll.insert({'user' => id, 'name' => username,'gpos' => { 'type' => 'Point', 'coordinates' => [lat, lon]},'exp_time' => Time.now.to_i+300})
            puts "good"
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
                coll.remove({'user' => user["user"]})
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
    set :port => 8080
    set :public_folder, File.dirname(__FILE__) + '/pub'
end

get '/getmessages/:id' do |id|
    # get list of messages from mongo
    chat.get_messages(id).to_json
end

post '/broadcast/:id/:lat/:lon/:message' do |id, lat, lon, message|
    chat.broadcast(id, lat.to_f, lon.to_f, message, Time.now)
end

post '/connect/:name/:lat/:long' do |name, latitude, longitude|
    idToken = Digest::SHA256.new.hexdigest "#{name}#{Time.now}"
    puts "idtoken"
    e,m = chat.connect(idToken, name, latitude.to_f, longitude.to_f)
    puts "what"

    if e != 0 
        puts m 
        return { status: 'ERR', message: m }.to_json
    end

    return { status: 'OK', token: idToken }.to_json
end

post '/update_gpos/:id/:lat/:long' do |id, lat, lon|
    chat.update_gpos(id, lat.to_f, lon.to_f)
end

__entry
