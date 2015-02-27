module Components
  class Cacher
    class << self
      def cache(key, expire)
        if (value = $redis.get(key)).nil?
          puts "Cache miss"
          value = yield

          $redis.set(key, Marshal.dump(value))
          $redis.expire(key, expire)
          value
        else
          puts "Cache hit"
          Marshal.load(value)
        end
      end
    end
  end
end
