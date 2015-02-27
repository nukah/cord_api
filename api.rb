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
  end
  REDIS ||= Redis.new(host:     opts['redis']['host'],
                     port:     opts['redis']['port'],
                     db:       opts['redis']['db'])
  MONGO ||= MongoClient.new(opts['mongo']['host'], opts['mongo']['port']).db(opts['mongo']['db'])
  CARS = MONGO.collection('cars')
  CARS.ensure_index(location: Mongo::GEO2DSPHERE)

  ##
  # Parameters:
  # Required:
  # Position: <String> ( "lat,long": "38.898, -77.037")
  # Name: <String> ( "Mercedes" )
  # Initial state: <String> ( "true" ) [true,false]
  ##
  post '/car' do
    name = params["name"].slice(0,20)
    position = params["position"].split(',').first(2).map(&:to_f)
    state = (params["active"] == 'true' ? true : false)

    halt(404, json({ error: "Name not provided"})) if name.nil? || name.empty?
    halt(403, json({ error: "Coordinates not provided or malformed" })) unless position.size == 2 && position.all? { |c| c.is_a?(Float) }
    halt(403, json({ error: "Car with such name already exist!"})) if CARS.find({ name: name }).to_a.any?

    CARS.insert({ name: name, location: { type: 'Point', coordinates: position.reverse }, active: state})
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
    name = params["name"]
    position = params["position"].split(',').first(2).map(&:to_f)

    halt(404, json({ error: "Name not provided" })) if name.nil? || name.empty?
    halt(404, json({ error: "Car not found"})) if CARS.find_one(name: name).nil?
    halt(403, json({ error: "Coordinates not provided or malformed" })) unless position.size == 2 && position.all? { |c| c.is_a?(Float) }

    updates = {}
    updates["active"] = (params["active"] == 'true' ? true : false) if params["active"]
    updates["location"] = { type: "Point", coordinates: position.reverse } if params["position"]

    CARS.update({ name: name }, { "$set" => updates })

    json({ success: true })
  end

  get '/cars' do
    results = CARS.find({}).to_a.map do |obj|
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
    position = params["position"].split(',').map(&:to_f)

    halt(403, json({ error: "Coordinates not provided or malformed" })) unless position.size == 2 && position.all? { |c| c.is_a?(Float) }

    client = Components::Client.new(position)

    entries = MONGO.command({
      geoNear: 'cars',
      near: { type: "Point", coordinates: position.reverse },
      spherical: true,
      query: { active: true },
      limit: 3
    })['results']

    accuracy_groups = entries.group_by do |car|
      settings.accuracy.select { |(k,v)| k > car['dis'].to_i }.values.last
    end

    results = entries.map do |obj|
      object = obj['obj']
      location = object['location']['coordinates']
      car = Components::Car.new(location.reverse)
      eta = Components::Cacher.cache("#{car.cache_key}:#{client.cache_key}", 300) do
        Components::Estimator.new(client.lat, client.long, location.last, location.first).eta
      end
      eta
    end
    halt(404, json({ error: "Не найдено подходящих автомобилей"})) if results.empty?
    eta = (results.reduce(:+).to_f / results.size).round(1)
    json({ eta: "Среднее время подачи: #{eta} минут(а)" })
  end
end
