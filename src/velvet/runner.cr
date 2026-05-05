module Velvet
  module Runner
    def self.progress_label(step : Int32, total : Int32, label : String) : String
      "[#{step}/#{total}] #{label}"
    end

    def self.statusbar_text(step : Int32, total : Int32, field_id : String, value : String | Array(String) | Bool | Nil) : String
      formatted = case value
                  when Array(String) then value.join(",")
                  when Nil           then "?"
                  else                    value.to_s
                  end
      "[#{step}/#{total}] #{field_id}=#{formatted}"
    end

    def self.completed_statusbar_text(step : Int32, total : Int32, ctx : Hash(String, JSON::Any)) : String
      return "[#{step}/#{total}] done: none" if ctx.empty?

      summary = ctx.map do |key, value|
        "#{key}=#{status_value(value)}"
      end.join(" | ")

      "[#{step}/#{total}] done: #{summary}"
    end

    def self.run(wizard : Wizard) : Hash(String, JSON::Any)
      result = {} of String => JSON::Any
      total_steps = wizard.fields.select(Field).size
      current_step = 0

      wizard.fields.each do |field|
        case field
        when LetField
          result[field.id.to_s] = field.compute.call(
            result
          )
        when Field
          next unless field.matches?(result.transform_values(&.to_s))
          current_step += 1
          footer = completed_statusbar_text(current_step, total_steps, result)
          value = prompt(field, result, current_step, total_steps, field.label, footer)
          result[field.id.to_s] = value
        end
      end

      result
    end

    private def self.prompt(field : Field, ctx : Hash(String, JSON::Any), step : Int32, total : Int32, display_label : String, footer_text : String) : JSON::Any
      case field
      when InputField
        loop do
          raw = prompt_input(field, display_label, footer_text)
          begin
            coerced = Output.coerce(field.id, raw, field.cast)
            Validator.validate_value!(field.id.to_s, coerced, field.validation)
            return coerced
          rescue err : Velvet::ValidationError
            if field.required
              STDERR.puts "  \e[31m#{err.message}\e[0m"
              next
            end
            raise err
          end
        end
      when SelectField
        raw = prompt_select(field, display_label, footer_text)
        coerced = Output.coerce(field.id, raw, field.cast)
        Validator.validate_value!(field.id.to_s, coerced, field.validation)
        coerced
      when MultiSelectField
        values = prompt_multiselect(field, display_label, footer_text)
        coerced_values = values.map do |v|
          coerced = Output.coerce(field.id, v, field.cast)
          Validator.validate_value!(field.id.to_s, coerced, field.validation)
          coerced
        end
        JSON::Any.new(coerced_values)
      when ConfirmField
        coerced = JSON::Any.new(prompt_confirm(field, display_label, footer_text))
        Validator.validate_value!(field.id.to_s, coerced, field.validation)
        coerced
      else
        raise Error.new("Unknown field type: #{field.class}")
      end
    end

    private def self.prompt_input(field : InputField, display_label : String, footer_text : String) : String
      loop do
        Prompts::Menu.render_bottom_statusbar(footer_text)
        print "\e[36m  #{display_label}\e[0m"
        print " \e[2m(#{field.default})\e[0m" if field.default
        print ": "
        raw = gets.try(&.chomp) || ""

        if raw.empty?
          if (default = field.default)
            return default
          end
          if field.required
            STDERR.puts "  \e[31mrequired\e[0m"
            next
          end
          return ""
        end

        return raw
      end
    end

    private def self.prompt_select(field : SelectField, display_label : String, footer_text : String) : String
      Prompts::Menu.new(display_label, field.options, footer_text).run
    end

    private def self.prompt_multiselect(field : MultiSelectField, display_label : String, footer_text : String) : Array(String)
      Prompts::MultiMenu.new(display_label, field.options, field.defaults, footer_text).run
    end

    private def self.status_value(value : JSON::Any) : String
      if s = value.as_s?
        s
      elsif i = value.as_i?
        i.to_s
      elsif f = value.as_f?
        f.to_s
      elsif b = value.as_bool?
        b ? "true" : "false"
      elsif arr = value.as_a?
        arr.map { |v| status_value(v) }.join(",")
      else
        value.to_json
      end
    end

    private def self.prompt_confirm(field : ConfirmField, display_label : String, footer_text : String) : Bool
      default_hint = field.default ? "Y/n" : "y/N"
      Prompts::Menu.render_bottom_statusbar(footer_text)
      print "\e[36m  #{display_label}\e[0m [\e[2m#{default_hint}\e[0m]: "
      raw = gets.try(&.chomp.downcase) || ""
      return field.default if raw.empty?
      raw == "y" || raw == "yes"
    end
  end
end
