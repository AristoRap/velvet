require "./spec_helper"
require "file_utils"

private def make_tmp_spec_dir : String
  dir = File.join(Dir.tempdir, "velvet-generator-spec-#{Process.pid}-#{Random.rand(1_000_000)}")
  Dir.mkdir_p(dir)
  dir
end

describe Velvet::Parser do
  it "parses string flags" do
    wizard = Velvet::Wizard.new(
      name: "test",
      fields: [Velvet::InputField.new("name", "Name")] of Velvet::Field | Velvet::LetField
    )
    result = Velvet::Parser.parse(wizard, ["--name", "myapp"])
    result["name"].as_s.should eq "myapp"
  end

  it "casts int flags" do
    wizard = Velvet::Wizard.new(
      name: "test",
      fields: [Velvet::InputField.new("replicas", "Replicas", cast: Velvet::Cast::Int)] of Velvet::Field | Velvet::LetField
    )
    result = Velvet::Parser.parse(wizard, ["--replicas", "3"])
    result["replicas"].as_i.should eq 3
  end

  it "raises on missing required flag" do
    wizard = Velvet::Wizard.new(
      name: "test",
      fields: [Velvet::InputField.new("name", "Name", required: true)] of Velvet::Field | Velvet::LetField
    )
    expect_raises(Velvet::ValidationError) do
      Velvet::Parser.parse(wizard, [] of String)
    end
  end

  it "raises on coercion failure when field is required" do
    wizard = Velvet::Wizard.new(
      name: "test",
      fields: [Velvet::InputField.new("replicas", "Replicas", cast: Velvet::Cast::Int, required: true)] of Velvet::Field | Velvet::LetField
    )
    expect_raises(Velvet::ValidationError) do
      Velvet::Parser.parse(wizard, ["--replicas", "not-a-number"])
    end
  end

  it "skips field when coercion fails and field is not required" do
    wizard = Velvet::Wizard.new(
      name: "test",
      fields: [Velvet::InputField.new("replicas", "Replicas", cast: Velvet::Cast::Int, required: false)] of Velvet::Field | Velvet::LetField
    )
    result = Velvet::Parser.parse(wizard, ["--replicas", "not-a-number"])
    result.has_key?("replicas").should be_false
  end

  it "casts select values using field cast" do
    wizard = Velvet::Wizard.new(
      name: "test",
      fields: [Velvet::SelectField.new("replicas", "Replicas", ["1", "2", "4"], cast: Velvet::Cast::Int)] of Velvet::Field | Velvet::LetField
    )

    result = Velvet::Parser.parse(wizard, ["--replicas", "4"])
    result["replicas"].as_i.should eq 4
  end

  it "casts multiselect values using field cast" do
    wizard = Velvet::Wizard.new(
      name: "test",
      fields: [Velvet::MultiSelectField.new("weights", "Weights", ["1.5", "2.0", "3.25"], cast: Velvet::Cast::Float)] of Velvet::Field | Velvet::LetField
    )

    result = Velvet::Parser.parse(wizard, ["--weights", "1.5,3.25"])
    arr = result["weights"].as_a
    arr[0].as_f.should eq 1.5
    arr[1].as_f.should eq 3.25
  end
end

describe Velvet do
  it "parses cast tokens centrally" do
    Velvet.cast_from_token("int").should eq Velvet::Cast::Int
    Velvet.cast_from_token("str").should eq Velvet::Cast::String
    Velvet.cast_from_token(nil).should eq Velvet::Cast::String
  end

  it "formats cast tokens centrally" do
    Velvet.cast_to_token(Velvet::Cast::Float).should eq "float"
    Velvet.cast_to_token(Velvet::Cast::Bool).should eq "bool"
  end

  it "resolves ui aliases centrally" do
    Velvet.ui_from_token("multi", strict: true).should eq Velvet::UIKind::Multi
    Velvet.ui_from_token("multiselect", strict: true).should eq Velvet::UIKind::Multi
    Velvet.ui_from_token("any_of", strict: true).should eq Velvet::UIKind::Multi
    Velvet.ui_to_field_type(Velvet::UIKind::Multi).should eq "multiselect"
  end
end

describe Velvet::DSL do
  it "builds fields with interchangeable ui aliases" do
    wizard = Velvet::DSL.define("Alias test") do |w|
      w.field("environment", "Environment", ui: "one_of", options: ["dev", "prod"])
      w.field("tags", "Tags", ui: "any_of", options: ["cache", "metrics"])
      w.field("tags2", "Tags2", ui: "multiselect", options: ["a", "b"])
    end

    wizard.fields[0].as(Velvet::SelectField)
    wizard.fields[1].as(Velvet::MultiSelectField)
    wizard.fields[2].as(Velvet::MultiSelectField)
  end

  it "rejects numeric bounds for string input fields" do
    expect_raises(Velvet::ConfigError) do
      Velvet::DSL.define("Bad validation") do |w|
        w.input("app_name", "App Name", cast: Velvet::Cast::String, min: 1)
      end
    end
  end

  it "rejects pattern for non-string input fields" do
    expect_raises(Velvet::ConfigError) do
      Velvet::DSL.define("Bad validation") do |w|
        w.input("replicas", "Replicas", cast: Velvet::Cast::Int, pattern: "^\\d+$")
      end
    end
  end

  it "rejects bool-incompatible validation on confirm fields" do
    expect_raises(Velvet::ConfigError) do
      Velvet::DSL.define("Bad validation") do |w|
        w.field("dry_run", "Dry run", ui: "confirm", min: 1)
      end
    end
  end

  it "supports pattern validation on select fields" do
    wizard = Velvet::DSL.define("Select validation") do |w|
      w.field("environment", "Environment", ui: "select", options: ["dev", "prod"], pattern: "^(dev|prod)$")
    end

    expect_raises(Velvet::ValidationError) do
      Velvet::Parser.parse(wizard, ["--environment", "staging"])
    end
  end
end

describe Velvet::Runner do
  it "formats progress labels" do
    Velvet::Runner.progress_label(2, 5, "Number of replicas").should eq "[2/5] Number of replicas"
  end

  it "formats statusbar text with scalar value" do
    Velvet::Runner.statusbar_text(2, 5, "replicas", "3").should eq "[2/5] replicas=3"
  end

  it "formats statusbar text with multiple selected values" do
    Velvet::Runner.statusbar_text(4, 5, "tags", ["cache", "metrics"]).should eq "[4/5] tags=cache,metrics"
  end
end

describe Velvet::Prompts::Menu do
  it "formats footer line" do
    Velvet::Prompts::Menu.footer_line("[2/5] replicas=3").should eq "\e[48;5;238m\e[97m  [2/5] replicas=3\e[0m\r\n"
  end

  it "formats bottom footer line anchored to terminal bottom" do
    Velvet::Prompts::Menu.bottom_footer_line("[2/5] replicas=3", 40).should eq "\e7\e[999;1H\e[2K\e[48;5;238m\e[97m  [2/5] replicas=3\e[0m\e8"
  end

  it "does not trim footer text when it fits columns" do
    Velvet::Prompts::Menu.fit_footer_text("[2/5] replicas=3", 40).should eq "[2/5] replicas=3"
  end

  it "trims footer text with ellipsis when it exceeds columns" do
    Velvet::Prompts::Menu.fit_footer_text("[2/5] replicas=1234567890", 16).should eq "[2/5] repli..."
  end
end

describe Velvet::Loader do
  it "loads a yaml wizard" do
    yaml = <<-YAML
    name: test
    fields:
      - id: environment
        type: select
        label: Environment
        options: [dev, staging, production]
        default: dev
    YAML

    File.write("/tmp/test.velvet.yml", yaml)
    wizard = Velvet::Loader.from_yaml("/tmp/test.velvet.yml")
    wizard.name.should eq "test"
    wizard.fields.size.should eq 1
  end

  it "loads typed scalar defaults for casted fields" do
    yaml = <<-YAML
    name: test
    fields:
      - id: replicas
        type: input
        cast: int
        label: Replicas
        default: 3
      - id: cpu_limit
        type: input
        cast: float
        label: CPU limit
        default: 1.5
      - id: autoscale
        type: input
        cast: bool
        label: Autoscale
        default: false
      - id: priority
        type: select
        cast: int
        label: Priority
        options: [1, 2, 3]
        default: 3
    YAML

    File.write("/tmp/test-typed-defaults.velvet.yml", yaml)
    wizard = Velvet::Loader.from_yaml("/tmp/test-typed-defaults.velvet.yml")

    replicas = wizard.fields[0].as(Velvet::InputField)
    cpu_limit = wizard.fields[1].as(Velvet::InputField)
    autoscale = wizard.fields[2].as(Velvet::InputField)
    priority = wizard.fields[3].as(Velvet::SelectField)

    replicas.default.should eq "3"
    cpu_limit.default.should eq "1.5"
    autoscale.default.should eq "false"
    priority.default.should eq "3"
  end

  it "loads typed multiselect defaults for casted fields" do
    yaml = <<-YAML
    name: test
    fields:
      - id: ports
        type: multiselect
        cast: int
        label: Ports
        options: [8080, 8081, 9090]
        defaults: [8080, 9090]
    YAML

    File.write("/tmp/test-typed-multiselect-defaults.velvet.yml", yaml)
    wizard = Velvet::Loader.from_yaml("/tmp/test-typed-multiselect-defaults.velvet.yml")
    ports = wizard.fields[0].as(Velvet::MultiSelectField)
    ports.defaults.should eq ["8080", "9090"]
  end

  it "rejects invalid scalar default for cast in yaml" do
    yaml = <<-YAML
    name: test
    fields:
      - id: priority
        type: select
        cast: int
        label: Priority
        options: ["1", "2", "3"]
        default: false
    YAML

    File.write("/tmp/test-invalid-default-cast.velvet.yml", yaml)
    expect_raises(Velvet::ConfigError) do
      Velvet::Loader.from_yaml("/tmp/test-invalid-default-cast.velvet.yml")
    end
  end

  it "rejects select default not present in options" do
    yaml = <<-YAML
    name: test
    fields:
      - id: environment
        type: select
        label: Environment
        options: [dev, prod]
        default: staging
    YAML

    File.write("/tmp/test-invalid-select-default-option.velvet.yml", yaml)
    expect_raises(Velvet::ConfigError) do
      Velvet::Loader.from_yaml("/tmp/test-invalid-select-default-option.velvet.yml")
    end
  end

  it "rejects multiselect defaults not present in options" do
    yaml = <<-YAML
    name: test
    fields:
      - id: ports
        type: multiselect
        label: Ports
        options: ["8080", "8081"]
        defaults: ["8080", "9090"]
    YAML

    File.write("/tmp/test-invalid-multiselect-default-option.velvet.yml", yaml)
    expect_raises(Velvet::ConfigError) do
      Velvet::Loader.from_yaml("/tmp/test-invalid-multiselect-default-option.velvet.yml")
    end
  end

  it "rejects numeric bounds for string casts in yaml" do
    yaml = <<-YAML
    name: test
    fields:
      - id: app_name
        type: input
        cast: string
        label: App Name
        validate:
          min: 1
    YAML

    File.write("/tmp/test-invalid-string-validation.velvet.yml", yaml)
    expect_raises(Velvet::ConfigError) do
      Velvet::Loader.from_yaml("/tmp/test-invalid-string-validation.velvet.yml")
    end
  end

  it "rejects pattern for int casts in yaml" do
    yaml = <<-YAML
    name: test
    fields:
      - id: replicas
        type: input
        cast: int
        label: Replicas
        validate:
          pattern: "^[0-9]+$"
    YAML

    File.write("/tmp/test-invalid-int-validation.velvet.yml", yaml)
    expect_raises(Velvet::ConfigError) do
      Velvet::Loader.from_yaml("/tmp/test-invalid-int-validation.velvet.yml")
    end
  end

  it "rejects validate block for confirm fields in yaml" do
    yaml = <<-YAML
    name: test
    fields:
      - id: dry_run
        type: confirm
        label: Dry run
        validate:
          min: 1
    YAML

    File.write("/tmp/test-invalid-confirm-validation.velvet.yml", yaml)
    expect_raises(Velvet::ConfigError) do
      Velvet::Loader.from_yaml("/tmp/test-invalid-confirm-validation.velvet.yml")
    end
  end

  it "loads and applies validate block for select fields in yaml" do
    yaml = <<-YAML
    name: test
    fields:
      - id: environment
        type: select
        label: Environment
        options: [dev, prod]
        validate:
          pattern: "^(dev|prod)$"
    YAML

    File.write("/tmp/test-select-validation.velvet.yml", yaml)
    wizard = Velvet::Loader.from_yaml("/tmp/test-select-validation.velvet.yml")

    expect_raises(Velvet::ValidationError) do
      Velvet::Parser.parse(wizard, ["--environment", "staging"])
    end
  end
end

describe Velvet::Generator do
  it "supports one_of alias for select" do
    wizard = nil
    dir = make_tmp_spec_dir
    begin
      Dir.cd(dir) do
        wizard = Velvet::Generator.run("Deploy", ["frontend@one_of=vanilla,vue"])
      end
    ensure
      FileUtils.rm_rf(dir)
    end

    field = wizard.not_nil!.fields.first.as(Velvet::SelectField)
    field.options.should eq ["vanilla", "vue"]
  end

  it "supports any_of alias for multi" do
    wizard = nil
    dir = make_tmp_spec_dir
    begin
      Dir.cd(dir) do
        wizard = Velvet::Generator.run("Deploy", ["tags@any_of=cache,metrics"])
      end
    ensure
      FileUtils.rm_rf(dir)
    end

    field = wizard.not_nil!.fields.first.as(Velvet::MultiSelectField)
    field.options.should eq ["cache", "metrics"]
  end

  it "allows registering custom ui aliases" do
    wizard = nil
    dir = make_tmp_spec_dir
    begin
      Velvet::Generator.set_ui_alias("pick", "select")
      Dir.cd(dir) do
        wizard = Velvet::Generator.run("Deploy", ["env@pick=dev,prod"])
      end
    ensure
      Velvet::Generator.reset_ui_aliases
      FileUtils.rm_rf(dir)
    end

    field = wizard.not_nil!.fields.first.as(Velvet::SelectField)
    field.options.should eq ["dev", "prod"]
  end

  it "parses shorthand id as string input" do
    wizard = nil
    dir = make_tmp_spec_dir
    begin
      Dir.cd(dir) do
        wizard = Velvet::Generator.run("Deploy", ["app_name"])
      end
    ensure
      FileUtils.rm_rf(dir)
    end

    wizard.not_nil!.fields.size.should eq 1
    field = wizard.not_nil!.fields.first.as(Velvet::InputField)
    field.id.should eq "app_name"
    field.cast.should eq Velvet::Cast::String
  end

  it "parses explicit cast input" do
    wizard = nil
    dir = make_tmp_spec_dir
    begin
      Dir.cd(dir) do
        wizard = Velvet::Generator.run("Deploy", ["replicas:int"])
      end
    ensure
      FileUtils.rm_rf(dir)
    end

    field = wizard.not_nil!.fields.first.as(Velvet::InputField)
    field.cast.should eq Velvet::Cast::Int
  end

  it "parses select with options" do
    wizard = nil
    dir = make_tmp_spec_dir
    begin
      Dir.cd(dir) do
        wizard = Velvet::Generator.run("Deploy", ["replicas:int@select=1,2,4,8"])
      end
    ensure
      FileUtils.rm_rf(dir)
    end

    field = wizard.not_nil!.fields.first.as(Velvet::SelectField)
    field.id.should eq "replicas"
    field.options.should eq ["1", "2", "4", "8"]
  end

  it "parses select with no options as valid stub" do
    wizard = nil
    dir = make_tmp_spec_dir
    begin
      Dir.cd(dir) do
        wizard = Velvet::Generator.run("Deploy", ["frontend@select"])
      end
    ensure
      FileUtils.rm_rf(dir)
    end

    field = wizard.not_nil!.fields.first.as(Velvet::SelectField)
    field.options.should eq [] of String
  end

  it "maps multi to multiselect" do
    wizard = nil
    dir = make_tmp_spec_dir
    begin
      Dir.cd(dir) do
        wizard = Velvet::Generator.run("Deploy", ["tags@multi=cache,metrics"])
      end
    ensure
      FileUtils.rm_rf(dir)
    end

    field = wizard.not_nil!.fields.first.as(Velvet::MultiSelectField)
    field.options.should eq ["cache", "metrics"]
  end

  it "accepts multiselect alias in shorthand" do
    wizard = nil
    dir = make_tmp_spec_dir
    begin
      Dir.cd(dir) do
        wizard = Velvet::Generator.run("Deploy", ["tags@multiselect=cache,metrics"])
      end
    ensure
      FileUtils.rm_rf(dir)
    end

    field = wizard.not_nil!.fields.first.as(Velvet::MultiSelectField)
    field.options.should eq ["cache", "metrics"]
  end

  it "implies bool for confirm" do
    wizard = nil
    dir = make_tmp_spec_dir
    begin
      Dir.cd(dir) do
        wizard = Velvet::Generator.run("Deploy", ["dry_run@confirm"])
      end
    ensure
      FileUtils.rm_rf(dir)
    end

    wizard.not_nil!.fields.first.as(Velvet::ConfirmField)
  end

  it "rejects values on input" do
    expect_raises(Velvet::ConfigError) do
      dir = make_tmp_spec_dir
      begin
        Dir.cd(dir) do
          Velvet::Generator.run("Deploy", ["name@input=foo,bar"])
        end
      ensure
        FileUtils.rm_rf(dir)
      end
    end
  end

  it "rejects values on confirm" do
    expect_raises(Velvet::ConfigError) do
      dir = make_tmp_spec_dir
      begin
        Dir.cd(dir) do
          Velvet::Generator.run("Deploy", ["dry_run@confirm=yes,no"])
        end
      ensure
        FileUtils.rm_rf(dir)
      end
    end
  end

  it "rejects unknown cast" do
    expect_raises(Velvet::ConfigError) do
      dir = make_tmp_spec_dir
      begin
        Dir.cd(dir) do
          Velvet::Generator.run("Deploy", ["score:number"])
        end
      ensure
        FileUtils.rm_rf(dir)
      end
    end
  end

  it "rejects unknown ui" do
    expect_raises(Velvet::ConfigError) do
      dir = make_tmp_spec_dir
      begin
        Dir.cd(dir) do
          Velvet::Generator.run("Deploy", ["frontend@dropdown=a,b"])
        end
      ensure
        FileUtils.rm_rf(dir)
      end
    end
  end

  it "writes valid yaml and round-trips with loader" do
    dir = make_tmp_spec_dir
    begin
      Dir.cd(dir) do
        wizard = Velvet::Generator.run("Deploy Config", [
          "app_name",
          "replicas:int",
          "replicas:int@select=1,2,4,8",
          "frontend@select=vanilla,vue",
          "score:float",
          "dry_run@confirm",
          "tags@multi=cache,metrics",
        ])

        wizard.name.should eq "Deploy Config"

        path = File.join(dir, "deploy_config.yml")
        File.exists?(path).should be_true

        loaded = Velvet::Loader.from_yaml(path)
        loaded.name.should eq "Deploy Config"
        loaded.fields.size.should eq 7
      end
    ensure
      FileUtils.rm_rf(dir)
    end
  end
end
