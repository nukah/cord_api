class CoordAPI < Sinatra::Base
  include Mongo
  configure do
    set(:opts) { YAML.load(File.open('./config.yml'))['application'] }
    set(:app_file, "./api.rb")
    set(:show_exceptions, false)
    set(:accuracy, {
      10000   => 1,
      1000    => 2,
      100     => 3
    })
    set(:db) { MongoClient.new.db('wheely') }
    set(:cars) { db.collection('cars') }
  end
  $redis = Redis.new(host:     opts['redis']['host'],
                     port:     opts['redis']['port'],
                     db:       opts['redis']['db'])
  settings.cars.ensureIndex(location: Mongo::GEO2DSPHERE)

  ##
  # Parameters:
  # Required:
  # Position: <String> ( "lat,long": "38.898, -77.037")
  # Name: <String> ( "Mercedes" )
  # Initial state: <String> ( "true" ) [true,false]
  ##
  post '/car' do
    halt(404, "Coordinates not provided") if params["position"] == ""
    halt(404, "Name not provided") if params["name"] == ""

    name = params["name"].slice(0,20)
    position = params["position"].split(',').first(2).map(&:to_f)
    state = (params["active"] == 'true' ? true : false)

    halt(404, "Car with such name already exist!") if settings.cars.find({ name: name }).to_a.any?
    settings.cars.insert({ name: name, location: { type: 'Point', coordinates: position.reverse }, active: state})
    json({ car: { name: name, position: position, active: state } })
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
  put '/car' do
    halt(404, json({ error: "Name not provided" }) if params["name"] == "" || (/^([\d.,]+)+/ =~ params["position"]).nil?
    name = params["name"]

    updates = {}
    updates["active"] = (params["active"] == 'true' ? true : false) if params["active"]
    updates["location"] = { type: "Point", coordinates: params["position"].split(',').first(2).map(&:to_f).reverse } if params["position"]

    settings.cars.update({ name: name }, { "$set" => updates })

    json({ success: true })
  end

  get '/cars' do
    results = settings.cars.find({}).to_a.map do |obj|
      { name: obj['name'], active: obj['active'], position: obj['location']['coordinates'].reverse }
    end
    json(results)
  end

  ##
  # Parameters:
  # Required:
  # Position: <String> ( "lat,long": "38.898, -77.037")
  ##
  get '/car/arrival' do
    halt(404, "Coordinates not provided") if params["position"] == "" || (/^([\d.,]+)+/ =~ params["position"]).nil?
    position = params["position"].split(',').map(&:to_f)

    begin
      @client = Components::Client.new(position)
    rescue ArgumentError
      halt(403, $!.message)
    end

    entries = settings.db.command({
      geoNear: 'cars',
      near: { type: "Point", coordinates: position.reverse },
      spherical: true,
      maxDistance: 25000,
      query: { active: true }
    })['results']

    accuracy_groups = entries.group_by do |car|
      settings.accuracy.select { |(k,v)| k > car['dis'].to_i }.values.last
    end

    results = entries.map do |obj|
      object = obj['obj']
      location = object['location']['coordinates']
      car = Components::Car.new(location.reverse)
      eta = Components::Cacher.cache("#{car.cache_key}:#{@client.cache_key}", 300) do
        Components::Estimator.new(@client.lat, @client.long, location.last, location.first).eta
      end
      { name: object['name'], active: object['active'], position: car.location, eta: eta }
    end
    json(results)
  end
end
