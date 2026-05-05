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
end
