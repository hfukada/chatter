require 'sinatra'
require 'json'
require 'digest'

configure do
	set :port => 80
	set :public_folder, File.dirname(__FILE__) + '/pub'
end

get '/getmessages/:id' do 
	# get list of messages from mongo
	[{ sender: 'jbury', message: 'I r pleb'}].to_json
end

post '/broadcast/:id' do 

end

get '/connect/:name/:lat/:long' do |name, latitude, longtitude|
	idToken = Digest::SHA256.new.hexdigest "#{name}#{Time.now}"
	{ status: 'OK', token: idToken, lat: latitude, long: longtitude}.to_json
end