# src/velvet/dsl.cr

module Velvet
  class DSL
    getter fields : Array(Field | LetField)

    def initialize(@name : String)
      @fields = [] of Field | LetField
    end

    def self.define(name : String, &block : DSL ->) : Wizard
      dsl = new(name)
      block.call(dsl)
      Wizard.new(name: name, fields: dsl.fields)
    end

    def input(id : String, label : String, default : String? = nil,
              cast : Cast = Cast::String, required : Bool = true,
              min = nil, max = nil, pattern : String? = nil)
      validation = (min || max || pattern) ? Validation.new(min: min.try(&.to_f64), max: max.try(&.to_f64),
        pattern: pattern.try { |p| Regex.new(p) }) : nil
      Velvet.validate_constraints_for_cast!(id, cast, validation)
      @fields << InputField.new(id, label,
        default: default, cast: cast,
        validation: validation, required: required)
    end

    def text(id : String, label : String, default : String? = nil,
             cast : Cast = Cast::String, required : Bool = true,
             min = nil, max = nil, pattern : String? = nil)
      input(id, label, default: default, cast: cast, required: required, min: min, max: max, pattern: pattern)
    end

    def field(id : String, label : String,
              *,
              ui : String,
              options : Array(String) = [] of String,
              cast : Cast = Cast::String,
              required : Bool = true,
              default : String? = nil,
              defaults : Array(String) = [] of String,
              default_confirm : Bool = false,
              min = nil, max = nil, pattern : String? = nil)
      kind = Velvet.ui_from_token(ui, strict: true, context: "DSL field '#{id}'").not_nil!

      case kind
      when Velvet::UIKind::Input
        raise ConfigError.new("DSL field '#{id}': options are only valid for select/multi") if options.any?
        input(id, label, default: default, cast: cast, required: required, min: min, max: max, pattern: pattern)
      when Velvet::UIKind::Select
        self.select(id, label, options, default: default, cast: cast, required: required)
      when Velvet::UIKind::Multi
        self.multiselect(id, label, options, defaults: defaults, cast: cast, required: required)
      when Velvet::UIKind::Confirm
        raise ConfigError.new("DSL field '#{id}': options are only valid for select/multi") if options.any?
        self.confirm(id, label, default: default_confirm)
      else
        raise ConfigError.new("DSL field '#{id}': unsupported ui '#{ui}'")
      end
    end

    def select(id : String, label : String, options : Array(String),
               default : String? = nil, cast : Cast = Cast::String, required : Bool = true)
      @fields << SelectField.new(id, label,
        options: options, default: default, cast: cast, required: required)
    end

    def one_of(id : String, label : String, options : Array(String),
               default : String? = nil, cast : Cast = Cast::String, required : Bool = true)
      self.select(id, label, options, default: default, cast: cast, required: required)
    end

    def multiselect(id : String, label : String, options : Array(String),
                    defaults : Array(String) = [] of String, cast : Cast = Cast::String, required : Bool = false)
      @fields << MultiSelectField.new(id, label,
        options: options, defaults: defaults, cast: cast, required: required)
    end

    def multi(id : String, label : String, options : Array(String),
              defaults : Array(String) = [] of String, cast : Cast = Cast::String, required : Bool = false)
      self.multiselect(id, label, options, defaults: defaults, cast: cast, required: required)
    end

    def any_of(id : String, label : String, options : Array(String),
               defaults : Array(String) = [] of String, cast : Cast = Cast::String, required : Bool = false)
      self.multiselect(id, label, options, defaults: defaults, cast: cast, required: required)
    end

    def confirm(id : String, label : String, default : Bool = false)
      @fields << ConfirmField.new(id, label, default: default)
    end

    def let(id : String, &block : Hash(String, JSON::Any) -> String)
      @fields << LetField.new(id, ->(ctx : Hash(String, JSON::Any)) {
        JSON::Any.new(block.call(ctx))
      })
    end
  end
end
