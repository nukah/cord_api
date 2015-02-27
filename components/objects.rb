module Components
  class BaseObject
    attr_reader :lat, :long
    def initialize(*position)
      @lat = nil
      @long = nil
      if position.size == 2 && position.all? { |a| a.is_a?(Float) }
        @lat = position.shift
        @long = position.shift
      elsif position.size == 1 && position.first.is_a?(Array)
        arguments = position.flatten
        raise ArgumentError.new("Invalid attributes for #{self.class.name}: #{arguments}") if arguments.size != 2

        @lat = arguments.shift.to_f
        @long = arguments.shift.to_f
      else
        raise ArgumentError.new("Invalid attributes for #{self.class.name}: #{position}")
      end
    end

    def location
      [@lat, @long]
    end

    def sharpen
      location.map { |coord| coord.round(3) }
    end

    def cache_key
      "#{sharpen.first}_#{sharpen.last}"
    end
  end

  class Client < BaseObject
  end

  class Car < BaseObject
  end
end
