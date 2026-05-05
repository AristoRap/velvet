require "./spec_helper"
require "file_utils"

ROOT_DIR    = File.expand_path("..", __DIR__)
BIN_CR_PATH = File.join(ROOT_DIR, "bin", "velvet.cr")

private def make_tmp_cli_spec_dir : String
  dir = File.join(Dir.tempdir, "velvet-cli-spec-#{Process.pid}-#{Random.rand(1_000_000)}")
  Dir.mkdir_p(dir)
  dir
end

private def write_valid_wizard(path : String)
  yaml = <<-YAML
  name: test
  fields:
    - id: app_name
      type: input
      label: App name
      required: true
  YAML

  File.write(path, yaml)
end

record CliResult, exit_code : Int32, stdout_text : String, stderr_text : String

private def run_cli(args : Array(String), cwd : String = ROOT_DIR) : CliResult
  stdout_io = IO::Memory.new
  stderr_io = IO::Memory.new

  status = Process.run(
    "crystal",
    ["run", BIN_CR_PATH, "--"] + args,
    output: stdout_io,
    error: stderr_io,
    chdir: cwd
  )

  CliResult.new(status.exit_code, stdout_io.to_s, stderr_io.to_s)
end

describe Velvet::CLI do
  it "routes validate via alias v" do
    dir = make_tmp_cli_spec_dir
    begin
      file = File.join(dir, "wizard.yml")
      write_valid_wizard(file)
      result = run_cli(["v", file])
      result.exit_code.should eq 0
      result.stderr_text.should contain("is valid")
    ensure
      FileUtils.rm_rf(dir)
    end
  end

  it "routes validate via alias check" do
    dir = make_tmp_cli_spec_dir
    begin
      file = File.join(dir, "wizard.yml")
      write_valid_wizard(file)
      result = run_cli(["check", file])
      result.exit_code.should eq 0
      result.stderr_text.should contain("is valid")
    ensure
      FileUtils.rm_rf(dir)
    end
  end

  it "routes new via alias n and writes a yaml file" do
    name = "CLI Alias Deploy #{Random.rand(1_000_000)}"
    generated = File.join(ROOT_DIR, Velvet::Generator.file_name(name))
    begin
      result = run_cli(["n", name, "app_name", "replicas:int"])
      result.exit_code.should eq 0
      File.exists?(generated).should be_true
    ensure
      File.delete(generated) if File.exists?(generated)
    end
  end

  it "routes parse via alias p" do
    dir = make_tmp_cli_spec_dir
    begin
      file = File.join(dir, "wizard.yml")
      write_valid_wizard(file)
      result = run_cli(["p", file, "--", "--app-name", "myapp"])
      result.exit_code.should eq 0
      result.stdout_text.should contain("\"app_name\":\"myapp\"")
    ensure
      FileUtils.rm_rf(dir)
    end
  end

  it "exits with code 1 when run is missing file argument" do
    result = run_cli(["run"])
    result.exit_code.should eq 1
    result.stderr_text.should contain("run requires a file argument")
  end

  it "exits with code 1 when parse is missing file argument" do
    result = run_cli(["parse"])
    result.exit_code.should eq 1
    result.stderr_text.should contain("parse requires a file argument")
  end

  it "exits with code 1 when new is missing shorthand fields" do
    result = run_cli(["new", "Deploy Config"])
    result.exit_code.should eq 1
    result.stderr_text.should contain("new requires at least one field argument")
  end

  it "exits with code 2 for missing validate file" do
    result = run_cli(["validate", "/tmp/does-not-exist.velvet.yml"])
    result.exit_code.should eq 2
    result.stderr_text.should contain("Config error")
  end
end
