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
                  validation = parse_validation(s["validate"]?)
                  InputField.new(id, label,
                    default: s["default"]?.try(&.as_s),
                    cast: cast,
                    validation: validation,
                    required: req)
                when "select"
                  options = s["options"].as_a.map(&.as_s)
                  cast = Velvet.cast_from_token(s["cast"]?.try(&.as_s))
                  SelectField.new(id, label,
                    options: options,
                    default: s["default"]?.try(&.as_s),
                    cast: cast,
                    required: req)
                when "multiselect"
                  options = s["options"].as_a.map(&.as_s)
                  defaults = s["defaults"]?.try(&.as_a.map(&.as_s)) || [] of String
                  cast = Velvet.cast_from_token(s["cast"]?.try(&.as_s))
                  MultiSelectField.new(id, label, options: options, defaults: defaults, cast: cast, required: req)
                when "confirm"
                  default = s["default"]?.try(&.as_bool) || false
                  ConfirmField.new(id, label, default: default, required: req)
                else
                  raise ConfigError.new("Unknown field type: #{s["type"]}")
                end

        fields << field
      end

      Wizard.new(name: name, fields: fields)
    end

    private def self.parse_validation(node : YAML::Any?) : Validation?
      return nil unless node
      Validation.new(
        min: node["min"]?.try(&.as_f?),
        max: node["max"]?.try(&.as_f?),
        pattern: node["pattern"]?.try { |p| Regex.new(p.as_s) }
      )
    end
  end
end
