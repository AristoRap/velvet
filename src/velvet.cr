require "yaml"
require "json"
require "argy"

require "./velvet/error"
require "./velvet/schema"
require "./velvet/validator"
require "./velvet/generator"
require "./velvet/loader"
require "./velvet/prompts/menu"
require "./velvet/runner"
require "./velvet/parser"
require "./velvet/output"
require "./velvet/dsl"
require "./velvet/cli"

module Velvet
  VERSION = "0.2.2"
end
