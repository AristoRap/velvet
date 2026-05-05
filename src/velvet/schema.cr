module Velvet
  # Cast target types
  enum Cast
    String
    Int
    Float
    Bool
  end

  enum UIKind
    Input
    Select
    Multi
    Confirm
  end

  @@ui_aliases : Hash(String, UIKind) = {
    "input"       => UIKind::Input,
    "text"        => UIKind::Input,
    "select"      => UIKind::Select,
    "one_of"      => UIKind::Select,
    "multi"       => UIKind::Multi,
    "multiselect" => UIKind::Multi,
    "any_of"      => UIKind::Multi,
    "confirm"     => UIKind::Confirm,
  }

  def self.cast_from_token(token : String?, strict : Bool = false, context : String? = nil) : Cast
    normalized = token.try(&.strip)

    case normalized
    when nil, "", "str", "string" then Cast::String
    when "int"                    then Cast::Int
    when "float"                  then Cast::Float
    when "bool"                   then Cast::Bool
    else
      if strict
        prefix = context ? "#{context}: " : ""
        raise ConfigError.new("#{prefix}unknown cast '#{normalized}'")
      end
      Cast::String
    end
  end

  def self.cast_to_token(cast : Cast) : String
    case cast
    when Cast::String then "str"
    when Cast::Int    then "int"
    when Cast::Float  then "float"
    when Cast::Bool   then "bool"
    else
      raise ConfigError.new("unsupported cast '#{cast}'")
    end
  end

  def self.ui_from_token(token : String?, strict : Bool = false, context : String? = nil) : UIKind?
    normalized = token.try(&.strip)
    return nil if normalized.nil? || normalized.empty?

    ui = @@ui_aliases[normalized]?
    return ui if ui

    if strict
      prefix = context ? "#{context}: " : ""
      raise ConfigError.new("#{prefix}unknown ui '#{normalized}'")
    end

    nil
  end

  def self.ui_to_field_type(ui : UIKind) : String
    case ui
    when UIKind::Input   then "input"
    when UIKind::Select  then "select"
    when UIKind::Multi   then "multiselect"
    when UIKind::Confirm then "confirm"
    else
      raise ConfigError.new("unsupported ui '#{ui}'")
    end
  end

  def self.set_ui_alias(alias_token : String, canonical_ui : String)
    token = alias_token.strip
    raise ConfigError.new("UI alias token cannot be empty") if token.empty?

    ui = ui_from_token(canonical_ui, strict: true, context: "Unknown canonical ui")
    @@ui_aliases[token] = ui.not_nil!
  end

  def self.reset_ui_aliases
    @@ui_aliases = {
      "input"       => UIKind::Input,
      "text"        => UIKind::Input,
      "select"      => UIKind::Select,
      "one_of"      => UIKind::Select,
      "multi"       => UIKind::Multi,
      "multiselect" => UIKind::Multi,
      "any_of"      => UIKind::Multi,
      "confirm"     => UIKind::Confirm,
    }
  end

  # Validation constraints
  record Validation,
    min : Float64? = nil,
    max : Float64? = nil,
    pattern : Regex? = nil

  # A single prompt field — the core unit
  abstract class Field
    getter id : String
    getter label : String
    getter required : Bool
    getter condition : (Hash(String, String) -> Bool)?

    def initialize(@id, @label, @required = true, @condition = nil)
    end

    def matches?(ctx : Hash(String, String)) : Bool
      cond = @condition
      cond.nil? || cond.call(ctx)
    end
  end

  class InputField < Field
    getter default : String?
    getter cast : Cast
    getter validation : Validation?

    def initialize(id, label, @default = nil, @cast = Cast::String,
                   @validation = nil, required = true, condition = nil)
      super(id, label, required, condition)
    end
  end

  class SelectField < Field
    getter options : Array(String)
    getter default : String?
    getter cast : Cast

    def initialize(id, label, @options, @default = nil, @cast = Cast::String, required = true, condition = nil)
      super(id, label, required, condition)
    end
  end

  class MultiSelectField < Field
    getter options : Array(String)
    getter defaults : Array(String)
    getter cast : Cast

    def initialize(id, label, @options, @defaults = [] of String, @cast = Cast::String, required = false, condition = nil)
      super(id, label, required, condition)
    end
  end

  class ConfirmField < Field
    getter default : Bool

    def initialize(id, label, @default = false, required = true, condition = nil)
      super(id, label, required, condition)
    end
  end

  class LetField
    getter id : String
    getter compute : Hash(String, JSON::Any) -> JSON::Any

    def initialize(@id, @compute)
    end
  end

  # The full wizard definition
  record Wizard,
    name : String,
    fields : Array(Field | LetField)
end
