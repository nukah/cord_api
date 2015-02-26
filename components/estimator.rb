module Components
  class Estimator
    RPD = Math::PI/180
    ER = 6371
    def initialize(lat1, lng1, lat2, lng2)
      @lat1 = lat1
      @lng1 = lng1
      @lat2 = lat2
      @lng2 = lng2
    end

    def distance
      dlat = @lat2 - @lat1
      dlong = @lng2 - @lng1

      dr = (Math.sin((RPD*dlat))/2) ** 2 + Math.cos(RPD*@lat2) *
           Math.cos(RPD*@lat1) * (Math.sin((RPD*dlong)/2)) ** 2
      dist = 2 * Math.atan2(Math.sqrt(dr), Math.sqrt(1-dr))
      dist * ER
    end

    def eta
      distance * 1.5
    end
  end
end
