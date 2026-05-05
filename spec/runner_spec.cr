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
end

describe Velvet::Prompts::Menu do
  it "formats dim summary line" do
    Velvet::Prompts::Menu.summary_line("[2/5] replicas=3").should eq "\e[2m  [2/5] replicas=3\e[0m\r\n"
  end

  it "formats dim summary line with empty content" do
    Velvet::Prompts::Menu.summary_line("").should eq "\e[2m  \e[0m\r\n"
  end
end
