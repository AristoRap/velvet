module Velvet
  module Loader
    def self.from_yaml(path : String) : Wizard
      raw = YAML.parse(File.read(path))
      name = raw["name"]?.try(&.as_s) || File.basename(path, File.extname(path))
      fields = [] of Field | LetField

      raw["fields"].as_a.each do |s|
        id = s["id"].as_s
        label = s["label"]?.try(&.as_s) || s["id"].as_s
        req = s["required"]?.try(&.as_bool) != false

        field = case s["type"].as_s
                when "input"
                  cast = Velvet.cast_from_token(s["cast"]?.try(&.as_s))
                  validation = Validator.from_yaml(s["validate"]?)
                  Validator.ensure_constraints!(id, cast, validation)
                  default = scalar_default_as_string(s["default"]?, id, cast)
                  Validator.ensure_default_for_cast!(id, cast, default, validation)
                  InputField.new(id, label,
                    default: default,
                    cast: cast,
                    validation: validation,
                    required: req)
                when "select"
                  cast = Velvet.cast_from_token(s["cast"]?.try(&.as_s))
                  options = array_scalars_as_strings(s["options"]?, id, "options", cast)
                  validation = Validator.from_yaml(s["validate"]?)
                  Validator.ensure_constraints!(id, cast, validation)
                  default = scalar_default_as_string(s["default"]?, id, cast)
                  Validator.ensure_default_for_cast!(id, cast, default, validation)
                  Validator.ensure_select_default_in_options!(id, default, options)
                  SelectField.new(id, label,
                    options: options,
                    default: default,
                    cast: cast,
                    validation: validation,
                    required: req)
                when "multiselect"
                  cast = Velvet.cast_from_token(s["cast"]?.try(&.as_s))
                  options = array_scalars_as_strings(s["options"]?, id, "options", cast)
                  defaults = array_default_as_strings(s["defaults"]?, id, cast)
                  validation = Validator.from_yaml(s["validate"]?)
                  Validator.ensure_constraints!(id, cast, validation)
                  defaults.each do |d|
                    Validator.ensure_default_for_cast!(id, cast, d, validation)
                  end
                  Validator.ensure_multiselect_defaults_in_options!(id, defaults, options)
                  MultiSelectField.new(id, label, options: options, defaults: defaults, cast: cast, validation: validation, required: req)
                when "confirm"
                  default = s["default"]?.try(&.as_bool) || false
                  validation = Validator.from_yaml(s["validate"]?)
                  Validator.ensure_constraints!(id, Velvet::Cast::Bool, validation)
                  ConfirmField.new(id, label, default: default, validation: validation, required: req)
                else
                  raise ConfigError.new("Unknown field type: #{s["type"]}")
                end

        fields << field
      end

      Wizard.new(name: name, fields: fields)
    end

    private def self.scalar_default_as_string(node : YAML::Any?, field_id : String, cast : Cast) : String?
      return nil unless node

      scalar_node_as_string(node, field_id, "default", cast)
    end

    private def self.scalar_node_as_string(node : YAML::Any, field_id : String, node_name : String, cast : Cast) : String
      case cast
      when Cast::String
        s = node.as_s?
        raise ConfigError.new("field '#{field_id}': #{node_name} must be a string for cast string") unless s
        s
      when Cast::Int
        i = node.as_i?
        raise ConfigError.new("field '#{field_id}': #{node_name} must be an int for cast int") unless i
        i.to_s
      when Cast::Float
        if f = node.as_f?
          f.to_s
        elsif i = node.as_i?
          i.to_s
        else
          raise ConfigError.new("field '#{field_id}': #{node_name} must be numeric for cast float")
        end
      when Cast::Bool
        b = node.as_bool?
        raise ConfigError.new("field '#{field_id}': #{node_name} must be a bool for cast bool") if b.nil?
        b ? "true" : "false"
      else
        raise ConfigError.new("field '#{field_id}': unsupported cast '#{cast}'")
      end
    end

    private def self.array_scalars_as_strings(node : YAML::Any?, field_id : String, node_name : String, cast : Cast) : Array(String)
      arr = node.try(&.as_a?)
      raise ConfigError.new("field '#{field_id}': #{node_name} must be an array") unless arr

      arr.map do |item|
        scalar_node_as_string(item, field_id, node_name, cast)
      end
    end

    private def self.array_default_as_strings(node : YAML::Any?, field_id : String, cast : Cast) : Array(String)
      return [] of String unless node

      arr = node.as_a?
      raise ConfigError.new("field '#{field_id}': defaults must be an array") unless arr

      arr.map do |item|
        scalar_node_as_string(item, field_id, "defaults", cast)
      end
    end
  end
end
