module Velvet
  module Parser
    # Parse raw CLI args against a wizard schema, emit clean typed result.
    # Accepts args like: --environment staging --replicas 3 --dry-run
    def self.parse(wizard : Wizard, args : Array(String)) : Hash(String, JSON::Any)
      flags = parse_flags(args)
      result = {} of String => JSON::Any

      wizard.fields.each do |field|
        next if field.is_a?(LetField)
        field = field.as(Field)

        key = field.id.to_s
        flag_key = key.gsub("_", "-")
        raw = flags[key]? || flags[flag_key]?

        if raw.nil?
          if field.is_a?(ConfirmField)
            # --flag presence = true, absence = default
            result[key] = JSON::Any.new(flags.has_key?(key) || flags.has_key?(flag_key) || field.as(ConfirmField).default)
            next
          end

          if field.required
            raise ValidationError.new(key, "missing required flag --#{flag_key}")
          end

          next
        end

        begin
          result[key] = compute_coerced(key, field, raw)
        rescue err : ValidationError
          if field.required
            raise err
          end
          # If not required, silently skip the field
        end
      end

      # Compute let fields
      wizard.fields.select(LetField).each do |let_field|
        result[let_field.id.to_s] = let_field.compute.call(result)
      end

      result
    end

    # Turns ["--foo", "bar", "--baz", "--qux", "1"] into {"foo" => "bar", "baz" => "true", "qux" => "1"}
    private def self.parse_flags(args : Array(String)) : Hash(String, String)
      flags = {} of String => String
      i = 0
      while i < args.size
        arg = args[i]
        if arg.starts_with?("--")
          key = arg.lchop("--")
          if i + 1 < args.size && !args[i + 1].starts_with?("--")
            flags[key] = args[i + 1]
            i += 2
          else
            flags[key] = "true"
            i += 1
          end
        else
          i += 1
        end
      end
      flags
    end

    private def self.compute_coerced(key : String, field : Field, raw : String) : JSON::Any
      case field
      when InputField
        coerced = Output.coerce(field.id, raw, field.cast)
        Output.validate!(coerced, field)
        coerced
      when SelectField
        raise ValidationError.new(key, "#{raw.inspect} not in #{field.options}") unless field.options.includes?(raw)
        Output.coerce(field.id, raw, field.cast)
      when MultiSelectField
        vals = raw.split(",").map(&.strip)
        invalid = vals.reject { |v| field.options.includes?(v) }
        raise ValidationError.new(key, "invalid options: #{invalid}") unless invalid.empty?
        JSON::Any.new(vals.map { |v| Output.coerce(field.id, v, field.cast) })
      when ConfirmField
        JSON::Any.new(raw == "true" || raw == "1" || raw == "yes")
      else
        JSON::Any.new(raw)
      end
    end
  end
end
