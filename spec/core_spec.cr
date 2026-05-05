require "./spec_helper"

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
