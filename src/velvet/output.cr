module Velvet
  module Output
    # Coerce a raw string value to the correct JSON type based on cast.
    def self.coerce(field_id : String, value : String, cast : Cast) : JSON::Any
      case cast
      when Cast::Int   then JSON::Any.new(value.to_i64)
      when Cast::Float then JSON::Any.new(value.to_f64)
      when Cast::Bool  then JSON::Any.new(parse_bool_string(value) || false)
      else                  JSON::Any.new(value)
      end
    rescue ArgumentError
      raise ValidationError.new(field_id, "expected #{cast}, got #{value.inspect}")
    end

    # Parses a string to Bool?, returning nil for unrecognised tokens.
    # Canonical truthy: "true", "1", "yes". Canonical falsy: "false", "0", "no".
    def self.parse_bool_string(s : String) : Bool?
      case s.downcase
      when "true", "1", "yes" then true
      when "false", "0", "no" then false
      end
    end

    def self.emit(result : Hash(String, JSON::Any))
      puts result.to_json
    end
  end
end
