require "./spec_helper"

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

  it "supports kebab-case flags for underscore field ids" do
    wizard = Velvet::Wizard.new(
      name: "test",
      fields: [Velvet::InputField.new("app_name", "App name")] of Velvet::Field | Velvet::LetField
    )

    result = Velvet::Parser.parse(wizard, ["--app-name", "velvet"])
    result["app_name"].as_s.should eq "velvet"
  end

  it "uses default for confirm field when flag is absent" do
    wizard = Velvet::Wizard.new(
      name: "test",
      fields: [Velvet::ConfirmField.new("dry_run", "Dry run", default: true)] of Velvet::Field | Velvet::LetField
    )

    result = Velvet::Parser.parse(wizard, [] of String)
    result["dry_run"].as_bool.should be_true
  end

  it "treats present confirm flag without value as true" do
    wizard = Velvet::Wizard.new(
      name: "test",
      fields: [Velvet::ConfirmField.new("dry_run", "Dry run", default: false)] of Velvet::Field | Velvet::LetField
    )

    result = Velvet::Parser.parse(wizard, ["--dry-run"])
    result["dry_run"].as_bool.should be_true
  end

  it "parses explicit false for confirm flags" do
    wizard = Velvet::Wizard.new(
      name: "test",
      fields: [Velvet::ConfirmField.new("dry_run", "Dry run", default: true)] of Velvet::Field | Velvet::LetField
    )

    result = Velvet::Parser.parse(wizard, ["--dry-run", "false"])
    result["dry_run"].as_bool.should be_false
  end

  it "applies select default when flag is omitted" do
    wizard = Velvet::Wizard.new(
      name: "test",
      fields: [Velvet::SelectField.new("environment", "Environment", ["dev", "staging"], default: "staging")] of Velvet::Field | Velvet::LetField
    )

    result = Velvet::Parser.parse(wizard, [] of String)
    result["environment"].as_s.should eq "staging"
  end

  it "computes let fields from parsed values" do
    wizard = Velvet::Wizard.new(
      name: "test",
      fields: [
        Velvet::InputField.new("app_name", "App name"),
        Velvet::LetField.new("slug", ->(ctx : Hash(String, JSON::Any)) {
          JSON::Any.new(ctx["app_name"].as_s.downcase)
        }),
      ] of Velvet::Field | Velvet::LetField
    )

    result = Velvet::Parser.parse(wizard, ["--app-name", "MyApp"])
    result["slug"].as_s.should eq "myapp"
  end

  it "trims whitespace in multiselect values" do
    wizard = Velvet::Wizard.new(
      name: "test",
      fields: [Velvet::MultiSelectField.new("tags", "Tags", ["cache", "metrics", "tracing"])] of Velvet::Field | Velvet::LetField
    )

    result = Velvet::Parser.parse(wizard, ["--tags", "cache, tracing"])
    result["tags"].as_a.map(&.as_s).should eq ["cache", "tracing"]
  end

  it "raises for invalid multiselect options" do
    wizard = Velvet::Wizard.new(
      name: "test",
      fields: [Velvet::MultiSelectField.new("tags", "Tags", ["cache", "metrics"], required: true)] of Velvet::Field | Velvet::LetField
    )

    expect_raises(Velvet::ValidationError) do
      Velvet::Parser.parse(wizard, ["--tags", "cache,unknown"])
    end
  end
end
