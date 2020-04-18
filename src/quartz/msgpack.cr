require "msgpack"

module Quartz
  struct Duration
    include MessagePack::Serializable
  end

  struct Scale
    include MessagePack::Serializable
  end

  class State
    include MessagePack::Serializable
  end

  class AtomicModel
    def initialize(pull : ::MessagePack::Unpacker)
      pull.read_hash_size
      pull.consume_hash do
        case key = Bytes.new(pull)
        when "name".to_slice
          super(String.new(pull))
        when "state".to_slice
          self.state = {{ (@type.name + "::State").id }}.new(pull)
        when "elapsed".to_slice
          @elapsed = Duration.new(pull)
        else
          raise ::MessagePack::UnpackError.new("unknown msgpack attribute: #{String.new(key)}")
        end
      end
    end

    def to_msgpack(packer : ::MessagePack::Packer)
      packer.write_hash_start(3)
      packer.write("name")
      @name.to_msgpack(packer)
      packer.write("state")
      state.to_msgpack(packer)
      packer.write("elapsed")
      @elapsed.to_msgpack(packer)
    end

    def self.from_msgpack(io : IO)
      self.new(::MessagePack::IOUnpacker.new(io))
    end

    def self.from_msgpack(bytes : Bytes)
      from_msgpack(IO::Memory.new(bytes))
    end
  end
end
