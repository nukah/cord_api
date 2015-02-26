require 'sinatra'
require 'yaml'
require 'yajl'
require 'mongo'

include Mongo

configure do
  set(:settings) { YAML.load(File.open('./config.yml')).with_indifferent_access[:application] }
  set(:app_file, "./api.rb")
  set(:accuracy, {
    '1km'   => 2,
    '100m'  => 3,
    '10m'   => 4,
    '1m'    => 5
  })
  set(:redis) { Redis.new(host:     settings[:redis][:host],
                          port:     settings[:redis][:host],
                          db:       settings[:redis][:db],
                          password: settings[:redis][:password]) }
  set(:db) { MongoClient.new.db('wheely') }
  set(:cars) { db['cars'] }
end

helpers do
  def required(parameters)
    missing_attributes = (parameters - params)
    halt(404, "Missing attributes in request: #{missing_attributes.map(&:to_s)}") if missing_attributes.any?
    parameters.each { |name| self.instance_variable_set("@#{name.to_s}", params[name]) }
  end

  def present(object)
    Yajl::Encoder.encode(object)
  end
end

##
# Parameters:
# Required:
# Position: <String> ( "lat,long": "38.898, -77.037")
# Name: <String> ( "Mercedes" )
# Initial state: <String> ( "true" ) [true,false]
##
post '/car/add' do
  halt!(404, "Coordinates not provided") unless params.include?(:position)
  halt!(404, "Name not provided") unless params.include?(:name)

  name = params[:name].slice(0,20)
  position = params[:position].split(',')
  state = params[:state] == 'true' ? true : false

  halt!(404, "Car with such name already exist!") if Car.where(name: @name).exists?
  car = cars.insert({ name: @name, location: { type: 'Point', coordinates: @position.reverse }, state: state})
  present({ car: car })
end
##
# Parameters:
# Required:
# Id: <Integer> ( 1513993 )
# Optional:
# Position: <String> ( "lat,long": "38.898, -77.037")
# Name: <String> ( "Mercedes" )
# Initial state: <String> ( "false" ) [true,false]
##
put '/car/:name' do
  halt!(404, "Name not provided") unless params.include?(:name)
  name = params[:name]

  updates = {}
  updates[:state] = params[:state] if params[:state]
  updates[:position] = params[:position].split(',').reverse if params[:position]

  cars.update({ name: name }, updates)

  present({ success: true })
end

get '/car/:id/arrival' do
  halt!(404, "Coordinates not provided") unless params.include?(:position)
  position = params[:position].split(',')
  begin
    @client = Client.new(@position)
  rescue ArgumentError
    halt(403, $!.message)
  end
  results = db.command({ geoNear: 'cars', near: { type: "Point", coordinates: position.reverse }, spherical: true, query: { active: true }})
  # limit(3).map { |c| Estimate.calc(@client.lat,@client.long, car.location.last, car.location.first) }
  #result = Estimate.calc()
  present(result)
end
