require "./spec_helper"

describe Velvet::Runner do
  it "formats progress labels" do
    Velvet::Runner.progress_label(2, 5, "Number of replicas").should eq "Number of replicas \e[2m[2/5]\e[0m"
  end

  it "formats statusbar text with scalar value" do
    Velvet::Runner.statusbar_text(2, 5, "replicas", "3").should eq "[2/5] replicas=3"
  end

  it "formats statusbar text with multiple selected values" do
    Velvet::Runner.statusbar_text(4, 5, "tags", ["cache", "metrics"]).should eq "[4/5] tags=cache,metrics"
  end

  it "formats statusbar text with nil as unknown" do
    Velvet::Runner.statusbar_text(2, 5, "replicas", nil).should eq "[2/5] replicas=?"
  end

  it "formats completed statusbar text for empty context" do
    Velvet::Runner.completed_statusbar_text(1, 5, {} of String => JSON::Any).should eq "[1/5] done: none"
  end

  it "formats completed statusbar text with mixed typed values" do
    ctx = {
      "app_name"  => JSON::Any.new("myapp"),
      "replicas"  => JSON::Any.new(3_i64),
      "autoscale" => JSON::Any.new(false),
      "tags"      => JSON::Any.new([
        JSON::Any.new("cache"),
        JSON::Any.new("metrics"),
      ]),
    }

    Velvet::Runner.completed_statusbar_text(4, 5, ctx)
      .should eq "[4/5] done: app_name=myapp | replicas=3 | autoscale=false | tags=cache,metrics"
  end

  it "parses confirm answer using default when empty" do
    Velvet::Runner.parse_confirm_answer("", true).should be_true
    Velvet::Runner.parse_confirm_answer("", false).should be_false
  end

  it "parses confirm answer yes variants" do
    Velvet::Runner.parse_confirm_answer("y", false).should be_true
    Velvet::Runner.parse_confirm_answer("yes", false).should be_true
    Velvet::Runner.parse_confirm_answer("Y", false).should be_true
    Velvet::Runner.parse_confirm_answer("YES", false).should be_true
  end

  it "parses confirm answer non-yes values as false" do
    Velvet::Runner.parse_confirm_answer("n", true).should be_false
    Velvet::Runner.parse_confirm_answer("no", true).should be_false
    Velvet::Runner.parse_confirm_answer("anything", true).should be_false
  end
end

describe Velvet::Prompts::Menu do
  it "formats dim summary line" do
    Velvet::Prompts::Menu.summary_line("[2/5] replicas=3").should eq "\e[2m  [2/5] replicas=3\e[0m\r\n"
  end

  it "formats dim summary line with empty content" do
    Velvet::Prompts::Menu.summary_line("").should eq "\e[2m  \e[0m\r\n"
  end

  it "requires a tty for interactive run" do
    unless STDIN.tty?
      menu = Velvet::Prompts::Menu.new("Environment", ["dev", "prod"])
      expect_raises(Velvet::Error, "Interactive menu requires a TTY.") do
        menu.run
      end
    end
  end
end

describe Velvet::Prompts::MultiMenu do
  it "requires a tty for interactive run" do
    unless STDIN.tty?
      menu = Velvet::Prompts::MultiMenu.new("Tags", ["cache", "metrics"], [] of String)
      expect_raises(Velvet::Error, "Interactive menu requires a TTY.") do
        menu.run
      end
    end
  end
end
