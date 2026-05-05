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
                  InputField.new(id, label,
                    default: s["default"]?.try(&.as_s),
                    cast: cast,
                    validation: validation,
                    required: req)
                when "select"
                  options = s["options"].as_a.map(&.as_s)
                  cast = Velvet.cast_from_token(s["cast"]?.try(&.as_s))
                  validation = Validator.from_yaml(s["validate"]?)
                  Validator.ensure_constraints!(id, cast, validation)
                  SelectField.new(id, label,
                    options: options,
                    default: s["default"]?.try(&.as_s),
                    cast: cast,
                    validation: validation,
                    required: req)
                when "multiselect"
                  options = s["options"].as_a.map(&.as_s)
                  defaults = s["defaults"]?.try(&.as_a.map(&.as_s)) || [] of String
                  cast = Velvet.cast_from_token(s["cast"]?.try(&.as_s))
                  validation = Validator.from_yaml(s["validate"]?)
                  Validator.ensure_constraints!(id, cast, validation)
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
  end
end
