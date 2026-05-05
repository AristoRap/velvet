module Velvet
  class Error < Exception; end

  class ConfigError < Error; end

  class ValidationError < Error
    getter field : String
    getter reason : String

    def initialize(@field, @reason)
      super("#{field}: #{reason}")
    end
  end

  # Raised by interactive menus on Ctrl+C; caught in CLI to print "Aborted." and exit 130.
  class Abort < Error; end
end
