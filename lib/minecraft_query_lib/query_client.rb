require 'socket'
require_relative 'exceptions'
require_relative 'packet_wrappers'

module MinecraftQueryLib

  class QueryClient
    MAGIC_BYTES = [0xFE, 0xFD]
    #SESSION_ID_MASK = [0x0F, 0x0F, 0x0F, 0x0F]

    TYPE_HANDSHAKE = 0x09
    TYPE_STAT = 0x00

    # Number of times we will retry when sending a regular packet fails
    MAX_RESPONSE_RETRIES = 3
    # Number of times we will retry because we suspect our token has expired
    MAX_TOKEN_RETRIES = 1

    MAX_PACKET_LENGTH = 65536

    RECEIVE_DELAY = 1

    def initialize()
      @socket = UDPSocket.new
      @builder = PacketWriter.new
    end

    def connect(host="localhost", port=25565)
      @host = host
      @port = port
      @socket.connect(host, port)
    end

    def close
      @socket.close
    end

    # Performs a basic query and returns a hash containing all properties of the query
    def basic_query
      result = nil
      retries = 0

      begin
        # Perform handshake
        perform_handshake

        # Perform the actual stat request and process the response
        if basic_stat_response = send_basic_stat_request
          result = process_basic_stat_response(basic_stat_response)
        end
      rescue ConnectionTimeoutException
        retries += 1

        # Retry - the token might have expired
        if retries <= MAX_TOKEN_RETRIES
          retry
        else
          raise
        end
      end

      result
    end

    private

    def try_send(data)
      retries = 0

      begin
        # Send the data
        @socket.send(data, 0)

        # TCP-like timeout
        sleep(2**retries)

        # Try to receive response
        response, from = @socket.recvfrom_nonblock(MAX_PACKET_LENGTH)
        return response if from
      rescue Errno::ECONNREFUSED # Connection refused
        raise HostOfflineException, "The host at #{@host}:#{@port} is currently offline"
      rescue StandardError # Timeout
        # Retry, but with a bigger timeout
        retries += 1
        retry if retries <= MAX_RESPONSE_RETRIES
      end

      raise ConnectionTimeoutException, "A timeout occurred while communicating with the host at #{@host}:#{@port}"
    end

    def build_packet_header(type)
      @builder.reset
      @builder << MAGIC_BYTES
      @builder << type
      @builder << session_id
    end

    def send_request(type)
       # Build the packet header
      build_packet_header(type)
      # Add additional data if needed
      yield @builder if block_given?

      # Send the packet to the server
      try_send(@builder.to_s)
    end

    def send_handshake_request
      send_request(TYPE_HANDSHAKE)
    end

    def send_basic_stat_request
      send_request(TYPE_STAT) do |builder|
        # Include the challenge token as content
        builder << @challenge_token
      end
    end

    def process_handshake_response(response)
      reader = PacketReader.new(response)

      type = reader.read
      return nil unless type.first == TYPE_HANDSHAKE

      session_id = reader.read(4)
      return nil unless session_id == session_id()

      # Read the challenge token
      challenge_token = reader.read_string(false)
      # Return the challenge token
      challenge_token
    end

    def process_basic_stat_response(response)
      reader = PacketReader.new(response)

      type = reader.read
      return nil unless type.first == TYPE_STAT

      session_id = reader.read(4)
      return nil unless session_id == session_id()

      resp_hash = {}
      resp_hash[:motd] = reader.read_string
      resp_hash[:gametype] = reader.read_string
      resp_hash[:map] = reader.read_string
      resp_hash[:numplayers] = reader.read_int
      resp_hash[:maxplayers] = reader.read_int
      resp_hash[:port] = reader.read_short
      resp_hash[:ip] = reader.read_string

      resp_hash
    end

    def perform_handshake
      if handshake_response = send_handshake_request
        challenge_token = process_handshake_response(handshake_response)
        @challenge_token = pack_token(challenge_token) if challenge_token
        return !!challenge_token
      end
      false
    end

    def pack_token(token)
      packed_token = token.pack('c*').to_i.to_s(16).scan(/.{2}/).map{|s| s.to_i(16)}

      # Insert number of zeros at the beginning so packed_token contains 4 ints
      nzeros = 4 - packed_token.size
      zeros = []
      (1..nzeros).each { zeros << 0 }
      packed_token.unshift(*zeros)
    end

    def session_id
      @session_id ||= [0x00, 0x00, 0x00, 0x01]
    end
  end

end
