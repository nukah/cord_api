module Components
  class Cacher
    class << self
      def cache(key, expire)
        if (value = CoordAPI::REDIS.get(key)).nil?
          puts "Cache miss"
          value = yield

          CoordAPI::REDIS.set(key, Marshal.dump(value))
          CoordAPI::REDIS.expire(key, expire)
          value
        else
          puts "Cache hit"
          Marshal.load(value)
        end
      end
    end
  end
end
