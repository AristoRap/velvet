require "../src/velvet"

wizard = Velvet::DSL.define "Deploy config" do |w|
  w.select "environment", "Target environment",
    options: %w[dev staging production],
    default: "dev"

  w.input "replicas", "Number of replicas",
    cast: Velvet::Cast::Int,
    required: true,
    min: 1,
    max: 20

  w.confirm "dry_run", "Dry run?", default: false

  w.multiselect "tags", "Feature flags",
    options: %w[cache metrics tracing],
    required: false
end

result = Velvet::Runner.run(wizard)
Velvet::Output.emit(result)
