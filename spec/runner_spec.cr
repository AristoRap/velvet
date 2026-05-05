require "./spec_helper"

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
