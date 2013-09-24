require 'rubygems'
require 'mongo'
require 'sinatra'
require 'time'
require 'json'

include Mongo

class Chatter
  def initialize()
    host = ENV['MONGO_RUBY_DRIVER_HOST'] || 'localhost'
    port = ENV['MONGO_RUBY_DRIVER_PORT'] || MongoClient::DEFAULT_PORT

    puts "Connecting to #{host}:#{port}"
    @db = MongoClient.new(host, port).db('mydb')

    users = @db.collection('users')
    users.ensure_index({:gpos => Mongo::GEO2DSPHERE})

  end
    def get_messages(target, lat, lon)
    user = @db.collection('users').find_one({ '_id' => target })

    unsentMessages = @db.collection('msg_queue').find({ 'to' => target})
    if unsentMessages.nil? or unsentMessages == 'nil'
      return {}
    end

    @db.collection('users').update({'_id' => user['_id']},{'name' => user['name'], 'gpos' => {'type'=>  'Point', 'coordinates' => [lat, lon] } ,'exp_time' => Time.now.to_i + 30})


    i = {}
    unsentMessages.each {|row|
                         username = get_username(row['from'])
                         msg = row['msg']
                         i[row['_id']] = {'from' => username, 'msg' => msg+"\n"}
    }
    @db.collection('msg_queue').remove({'to' => target})
    return i
  end
  def get_username(target)
    @db.collection('users').find_one('_id'=> target)['name']
  end

  def broadcast(id, lat, lon, msg, timestamp)
    users = find_local_users(lat, lon).map{|user| user['_id']}
    users.map{ |m| puts m.to_json}
    users.each{|user|
      send_message(user, id, msg, timestamp)
    }
  end

  def send_message(to, from, msg, timestamp)
    coll = @db.collection('msg_queue')
    doc = {"to" => to, "from" => from, "msg" => msg, "timestamp"=>timestamp}
    coll.insert(doc)
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
    if check_user_safe(username)
      coll = @db.collection('users')
      doc = {'_id' => id, 'name' => username,'gpos' => { 'type' => 'Point', 'coordinates' => [lat, lon]},'exp_time' => Time.now.to_i+30}
      coll.insert(doc)
      return 0,"#{username} is ready to go"
    else
      return  1,"#{username} already exists"
    end
  end

  # check if the username has been taken already
  def check_user_safe(username)
    result = @db.collection('users').find_one({'name' => username})
    return result.inspect == 'nil'
  end


  def clean_users_collection()
    puts "cleaning"
    coll = @db.collection('users')
    users = coll.find()
    puts "got users"
    users.each{|user|
      if  user.inspect['exp_time'] < Time.now.to_i
        coll.remove({'_id' => user["user"]})
      end
    }
    puts "end clean"
  end
end

chat = Chatter.new

def __entry(chat)
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

get '/getmessages/:id/:lat/:lon' do |id,lat,lon|
  # get list of messages from mongo
  chat.get_messages(id,lat.to_f, lon.to_f).to_json
end

post '/broadcast/:id/:lat/:lon/:message' do |id, lat, lon, message|
  chat.broadcast(id, lat.to_f, lon.to_f, message, Time.now.to_i)
end

post '/connect/:name/:lat/:long' do |name, latitude, longitude|
  idToken = Digest::SHA256.new.hexdigest "#{name}#{Time.now}"
  e,m = chat.connect(idToken, name, latitude.to_f, longitude.to_f)

  if e != 0 
    puts m 
    return { status: 'ERR', message: m }.to_json
  end

  return { status: 'OK', token: idToken }.to_json
end


__entry(chat)
