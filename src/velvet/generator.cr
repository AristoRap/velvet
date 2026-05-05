module Velvet
  module Generator
    def self.set_ui_alias(alias_token : String, canonical_ui : String)
      Velvet.set_ui_alias(alias_token, canonical_ui)
    end

    def self.reset_ui_aliases
      Velvet.reset_ui_aliases
    end

    def self.run(name : String, args : Array(String)) : Wizard
      file_name = self.file_name(name)
      fields = [] of Field | LetField

      # puts "Creating #{file_name}..."
      args.each do |arg|
        field = parse_field(arg)
        fields << field
      end

      wizard = Wizard.new(name: name, fields: fields)
      write_yaml(file_name, wizard)
      # puts "Wrote #{file_name}"
      wizard
    end

    def self.file_name(name : String) : String
      "#{name.downcase.gsub(/[^a-z0-9]+/, "_")}.yml"
    end

    private def self.parse_field(arg : String) : Field
      raise ConfigError.new("Invalid field declaration: empty value") if arg.strip.empty?

      if arg.count('@') > 1
        raise ConfigError.new("Invalid field declaration '#{arg}': too many '@'")
      end

      meta, ui_token = parse_meta_and_ui(arg)
      id, cast_token = parse_id_and_cast(meta, arg)
      cast = Velvet.cast_from_token(cast_token, strict: true, context: "Invalid field declaration '#{arg}'")
      ui, options = parse_ui_and_options(ui_token, arg)

      label = id
      field = case ui
              when Velvet::UIKind::Input
                if options.any?
                  raise ConfigError.new("Invalid field declaration '#{arg}': options are only valid for select/multi")
                end
                InputField.new(id, label, cast: cast)
              when Velvet::UIKind::Select
                SelectField.new(id, label, options: options, cast: cast)
              when Velvet::UIKind::Multi
                MultiSelectField.new(id, label, options: options, cast: cast)
              when Velvet::UIKind::Confirm
                if options.any?
                  raise ConfigError.new("Invalid field declaration '#{arg}': options are only valid for select/multi")
                end
                if !cast_token.empty? && cast != Cast::Bool
                  raise ConfigError.new("Invalid field declaration '#{arg}': confirm only supports bool cast")
                end
                ConfirmField.new(id, label)
              else
                raise ConfigError.new("Unsupported ui kind")
              end

      # puts "  #{id}:#{cast_name(cast)} -> #{ui_name(ui)}"
      field
    end

    private def self.parse_meta_and_ui(arg : String) : Tuple(String, String)
      parts = arg.split("@", 2)
      {parts[0], parts[1]? || ""}
    end

    private def self.parse_id_and_cast(meta : String, raw : String) : Tuple(String, String)
      if meta.count(':') > 1
        raise ConfigError.new("Invalid field declaration '#{raw}': too many ':'")
      end

      parts = meta.split(":", 2)
      id = parts[0].strip
      cast = (parts[1]? || "").strip

      raise ConfigError.new("Invalid field declaration '#{raw}': missing id") if id.empty?
      {id, cast}
    end

    private def self.parse_ui_and_options(token : String, raw : String) : Tuple(Velvet::UIKind, Array(String))
      return {Velvet::UIKind::Input, [] of String} if token.empty?

      ui_parts = token.split("=", 2)
      ui_token = ui_parts[0].strip
      options_token = ui_parts[1]?

      ui = Velvet.ui_from_token(ui_token, strict: true, context: "Invalid field declaration '#{raw}'")

      options = parse_options(options_token, raw)
      {ui.not_nil!, options}
    end

    private def self.parse_options(token : String?, raw : String) : Array(String)
      return [] of String unless token
      return [] of String if token.strip.empty?

      vals = token.split(",").map(&.strip)
      if vals.any?(&.empty?)
        raise ConfigError.new("Invalid field declaration '#{raw}': options cannot contain empty values")
      end
      vals
    end

    private def self.ui_name(ui : Velvet::UIKind) : String
      Velvet.ui_to_field_type(ui)
    end

    private def self.cast_name(cast : Cast) : String
      Velvet.cast_to_token(cast)
    end

    private def self.write_yaml(path : String, wizard : Wizard)
      fields_data = wizard.fields.compact_map do |field|
        next nil if field.is_a?(LetField)

        row = {
          "id"    => field.id,
          "type"  => type_for(field),
          "label" => field.label,
        } of String => String | Bool | Array(String) | Array(Int64) | Array(Float64) | Array(Bool)

        case field
        when InputField
          row["cast"] = cast_name(field.cast)
        when SelectField
          row["options"] = options_for_yaml(field.options, field.cast)
          if field.cast != Cast::String
            row["cast"] = cast_name(field.cast)
          end
        when MultiSelectField
          row["options"] = options_for_yaml(field.options, field.cast)
          if field.cast != Cast::String
            row["cast"] = cast_name(field.cast)
          end
        when ConfirmField
          row["default"] = field.default
        end

        row
      end

      data = {
        "name"   => wizard.name,
        "fields" => fields_data,
      }

      File.write(path, data.to_yaml)
    end

    private def self.options_for_yaml(options : Array(String), cast : Cast) : Array(String) | Array(Int64) | Array(Float64) | Array(Bool)
      case cast
      when Cast::Int
        options.map do |opt|
          opt.to_i64
        rescue err : ArgumentError
          raise ConfigError.new("Generator option #{opt.inspect} cannot be cast to int")
        end
      when Cast::Float
        options.map do |opt|
          opt.to_f64
        rescue err : ArgumentError
          raise ConfigError.new("Generator option #{opt.inspect} cannot be cast to float")
        end
      when Cast::Bool
        options.map do |opt|
          token = opt.downcase
          case token
          when "true", "1", "yes" then true
          when "false", "0", "no" then false
          else
            raise ConfigError.new("Generator option #{opt.inspect} cannot be cast to bool")
          end
        end
      else
        options
      end
    end

    private def self.type_for(field : Field) : String
      ui = case field
           when InputField       then Velvet::UIKind::Input
           when SelectField      then Velvet::UIKind::Select
           when MultiSelectField then Velvet::UIKind::Multi
           when ConfirmField     then Velvet::UIKind::Confirm
           else
             raise ConfigError.new("Unsupported field type in generator")
           end

      Velvet.ui_to_field_type(ui)
    end
  end
end
