require "./spec_helper"

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

  it "rejects string options for int-cast select in yaml" do
    yaml = <<-YAML
    name: test
    fields:
      - id: priority
        type: select
        cast: int
        label: Priority
        options: ["1", "2", "3"]
        default: 1
    YAML

    File.write("/tmp/test-invalid-int-select-options-type.velvet.yml", yaml)
    expect_raises(Velvet::ConfigError) do
      Velvet::Loader.from_yaml("/tmp/test-invalid-int-select-options-type.velvet.yml")
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

  it "rejects bool options for int-cast multiselect in yaml" do
    yaml = <<-YAML
    name: test
    fields:
      - id: port_pool
        type: multiselect
        label: Allowed ports
        options: [false, 8081, 9090]
        cast: int
    YAML

    File.write("/tmp/test-invalid-int-multiselect-options-type.velvet.yml", yaml)
    expect_raises(Velvet::ConfigError) do
      Velvet::Loader.from_yaml("/tmp/test-invalid-int-multiselect-options-type.velvet.yml")
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
