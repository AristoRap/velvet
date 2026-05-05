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
  class Abort < Error; end
end
