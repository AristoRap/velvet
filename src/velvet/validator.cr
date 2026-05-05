module Velvet
  module Validator
    def self.from_yaml(node : YAML::Any?) : Validation?
      return nil unless node

      validation = Validation.new(
        min: node["min"]?.try(&.as_f?),
        max: node["max"]?.try(&.as_f?),
        pattern: node["pattern"]?.try { |p| Regex.new(p.as_s) }
      )

      return nil if validation.min.nil? && validation.max.nil? && validation.pattern.nil?
      validation
    end

    def self.from_args(min, max, pattern : String?) : Validation?
      validation = (min || max || pattern) ? Validation.new(
        min: min.try(&.to_f64),
        max: max.try(&.to_f64),
        pattern: pattern.try { |p| Regex.new(p) }
      ) : nil

      validation
    end

    def self.ensure_constraints!(field_id : String, cast : Cast, validation : Validation?) : Nil
      return unless validation

      has_numeric_bounds = !validation.min.nil? || !validation.max.nil?
      if has_numeric_bounds && cast != Cast::Int && cast != Cast::Float
        raise ConfigError.new("field '#{field_id}': min/max are only valid for int/float casts")
      end

      if !validation.pattern.nil? && cast != Cast::String
        raise ConfigError.new("field '#{field_id}': pattern is only valid for string cast")
      end
    end

    def self.validate_value!(field_id : String, value : JSON::Any, validation : Validation?) : Nil
      return unless validation

      if (min = validation.min) && value.as_f? && value.as_f < min
        raise ValidationError.new(field_id, "must be >= #{min}")
      end

      if (max = validation.max) && value.as_f? && value.as_f > max
        raise ValidationError.new(field_id, "must be <= #{max}")
      end

      if (pat = validation.pattern) && value.as_s? && !value.as_s.matches?(pat)
        raise ValidationError.new(field_id, "must match #{pat.source}")
      end
    end

    def self.ensure_default_for_cast!(field_id : String, cast : Cast, default_value : String?, validation : Validation?) : Nil
      return unless default_value

      coerced = coerce_default_for_cast(field_id, cast, default_value)
      begin
        validate_value!(field_id, coerced, validation)
      rescue err : ValidationError
        raise ConfigError.new("field '#{field_id}': default #{err.message}")
      end
    end

    def self.ensure_select_default_in_options!(field_id : String, default_value : String?, options : Array(String)) : Nil
      return unless default_value
      return if options.includes?(default_value)

      raise ConfigError.new("field '#{field_id}': default #{default_value.inspect} is not in options")
    end

    def self.ensure_multiselect_defaults_in_options!(field_id : String, defaults : Array(String), options : Array(String)) : Nil
      invalid = defaults.reject { |d| options.includes?(d) }
      return if invalid.empty?

      raise ConfigError.new("field '#{field_id}': defaults not in options: #{invalid}")
    end

    private def self.coerce_default_for_cast(field_id : String, cast : Cast, default_value : String) : JSON::Any
      case cast
      when Cast::String
        JSON::Any.new(default_value)
      when Cast::Int
        JSON::Any.new(default_value.to_i64)
      when Cast::Float
        JSON::Any.new(default_value.to_f64)
      when Cast::Bool
        token = default_value.downcase
        case token
        when "true", "1", "yes"
          JSON::Any.new(true)
        when "false", "0", "no"
          JSON::Any.new(false)
        else
          raise ConfigError.new("field '#{field_id}': default expected bool, got #{default_value.inspect}")
        end
      else
        raise ConfigError.new("field '#{field_id}': unsupported cast '#{cast}'")
      end
    rescue err : ArgumentError
      raise ConfigError.new("field '#{field_id}': default expected #{cast}, got #{default_value.inspect}")
    end
  end
end
