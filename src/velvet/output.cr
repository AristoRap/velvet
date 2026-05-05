module Velvet
  module Output
    # Coerce a raw string value to the correct JSON type based on cast
    def self.coerce(field_id : String, value : String, cast : Cast) : JSON::Any
      case cast
      when Cast::Int
        JSON::Any.new(value.to_i64)
      when Cast::Float
        JSON::Any.new(value.to_f64)
      when Cast::Bool
        JSON::Any.new(value == "true" || value == "1" || value == "yes")
      else
        JSON::Any.new(value)
      end
    rescue ArgumentError
      raise ValidationError.new(field_id, "expected #{cast}, got #{value.inspect}")
    end

    def self.validate!(value : JSON::Any, field : InputField)
      Validator.validate_value!(field.id.to_s, value, field.validation)
    end

    def self.emit(result : Hash(String, JSON::Any))
      puts result.to_json
    end
  end
end
