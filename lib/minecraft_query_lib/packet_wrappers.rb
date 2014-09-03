module MinecraftQueryLib

  class PacketWrapper
    def initialize(packet=[])
      if packet.is_a?(String)
        packet = packet.unpack('c*')
      end
      @packet = packet
    end

    def to_a
      @packet
    end

    def to_s
      to_a.pack('c*')
    end
  end

  class PacketReader < PacketWrapper
    def initialize(packet=[])
      super(packet)
    end

    def read(nbytes=1)
      @packet.shift(nbytes)
    end

    def read_string(convert_to_string=true)
      string = @packet.take_while {|c| c != 0}
      @packet = @packet.drop(string.length+1)

      if convert_to_string
        string.pack('c*')
      else
        string
      end
    end

    def read_int
      read_string.to_i
    end

    def read_short
      # shorts are sent as little endian
      read(2).reverse.pack('c*').unpack('n').first
    end
  end

  class PacketWriter < PacketWrapper
    def initialize(packet=[])
      super(packet)
    end

    def reset
      @packet = []
    end

    def <<(value)
      if value.is_a?(Array)
        @packet += value
      else
        @packet << value
      end
    end
  end

end