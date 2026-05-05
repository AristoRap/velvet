require "./spec_helper"
require "file_utils"

private def make_tmp_spec_dir : String
  dir = File.join(Dir.tempdir, "velvet-generator-spec-#{Process.pid}-#{Random.rand(1_000_000)}")
  Dir.mkdir_p(dir)
  dir
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
