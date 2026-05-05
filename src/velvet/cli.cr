require "argy"

module Velvet
  module CLI
    def self.run(argv : Array(String))
      root = Argy::Command.new(
        use: "velvet",
        short: "The rope between your terminal and your app",
        long: "Define prompts in YAML. Collect clean typed input. Emit JSON.\nYour app never writes argparse again."
      )

      root.persistent_flags.bool("debug", 'd', false, "print debug info")

      setup_new(root)
      setup_run(root)
      setup_parse(root)
      setup_validate(root)

      root.execute(argv)
    rescue e : ValidationError
      STDERR.puts "Error: #{e.message}"
      exit 1
    rescue e : ConfigError
      STDERR.puts "Config error: #{e.message}"
      exit 2
    rescue e : Abort
      STDERR.puts "\nAborted."
      exit 130
    end

    # Commands

    # velvet new <name> ...
    private def self.setup_new(root : Argy::Command)
      cmd = Argy::Command.new(
        use: "new [name]",
        short: "Scaffold a new velvet config",
      )

      cmd.on_run do |_cmd, args|
        name = args.shift? || abort_with("new requires a name argument")
        abort_with("new requires at least one argument") if args.empty?

        wizard = Generator.run(name, args)
        file = Generator.file_name(name)
        STDERR.puts "✓ generated #{file} (#{wizard.fields.size} fields)"
      end

      root.add_command(cmd)
    end

    # velvet run <file>
    private def self.setup_run(root : Argy::Command)
      cmd = Argy::Command.new(
        use: "run [file]",
        short: "Run an interactive wizard and emit JSON"
      )

      cmd.on_run do |_cmd, args|
        file = args.first? || abort_with("run requires a file argument")
        wizard = load_wizard(file)
        result = Runner.run(wizard)
        Output.emit(result)
      end

      root.add_command(cmd)
    end

    # velvet parse <file> -- [flags]
    private def self.setup_parse(root : Argy::Command)
      cmd = Argy::Command.new(
        use: "parse [file] -- [flags]",
        short: "Parse flags against a schema and emit JSON",
        long: "Non-interactive mode. Validates and coerces flags defined in [file].\n" \
              "Emits clean JSON. Useful for CI or wrapping existing CLIs.\n\n" \
              "Example:\n  velvet parse deploy.yml -- --environment staging --replicas 3 --dry-run"
      )

      cmd.on_run do |_cmd, args|
        file = args.first? || abort_with("parse requires a file argument")

        # Everything after -- are the flags to parse against the schema
        sep = args.index("--")
        raw_flags = sep ? args[(sep + 1)..] : args[1..]

        wizard = load_wizard(file)
        result = Parser.parse(wizard, raw_flags)
        Output.emit(result)
      end

      root.add_command(cmd)
    end

    # velvet validate <file>
    private def self.setup_validate(root : Argy::Command)
      cmd = Argy::Command.new(
        use: "validate [file]",
        short: "Validate a wizard file"
      )

      cmd.on_run do |_cmd, args|
        file = args.first? || abort_with("validate requires a file argument")
        load_wizard(file)
        STDERR.puts "✓ #{file} is valid"
      end

      root.add_command(cmd)
    end

    # Helpers

    private def self.load_wizard(path : String) : Wizard
      raise ConfigError.new("File not found: #{path}") unless File.exists?(path)
      Loader.from_yaml(path)
    end

    private def self.abort_with(msg : String) : NoReturn
      STDERR.puts "Error: #{msg}"
      exit 1
    end
  end
end
