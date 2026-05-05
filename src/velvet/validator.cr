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
  end
end