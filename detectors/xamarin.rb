require 'find'
require 'pathname'
require 'set'
require_relative '../config_helper'

# -----------------------
# --- functions
# -----------------------

def get_solution_configs(solution_file_path)
  configuration_start = 'GlobalSection(SolutionConfigurationPlatforms) = preSolution'
  configuration_end = 'EndGlobalSection'

  is_next_line_scheme = false
  configurations = []
  File.open(solution_file_path).each do |line|
    is_next_line_scheme = false if line.include? configuration_end

    if is_next_line_scheme
      begin
        configurations << line.split('=')[1].strip!
      rescue
        puts "\e[31mFailed to parse configuration: #{line}\e[0m"
      end
    end

    is_next_line_scheme = true if line.include? configuration_start
  end

  configurations
end

def get_xamarin_android_api_and_configs(project_file_path)
  regex = '<PropertyGroup Condition=" \'\$\(Configuration\)\|\$\(Platform\)\' == \'(.*)\' ">'
  configs = []

  lines = File.readlines(project_file_path)
  (lines).each do |line|
    match = line.match(regex)
    next unless match

    config = match.captures[0]
    next unless config

    configs << config
  end

  return 'Mono.Android', configs if lines.grep(/Include="Mono.Android"/).size > 0

  nil
end

def get_xamarin_ios_api_and_configs(project_file_path)
  regex = '<PropertyGroup Condition=" \'\$\(Configuration\)\|\$\(Platform\)\' == \'(.*)\' ">'
  configs = []

  lines = File.readlines(project_file_path)
  (lines).each do |line|
    match = line.match(regex)
    next unless match

    config = match.captures[0]
    next unless config

    configs << config
  end

  return 'monotouch', configs if lines.grep(/Include="monotouch"/).size > 0
  return 'Xamarin.iOS', configs if lines.grep(/Include="Xamarin.iOS"/).size > 0

  nil
end

def filter_solution_configs(solution_configs, project_configs)
  configs = []
  (solution_configs).each do |config|
    configs << config if project_configs.include? config
  end
  configs
end

def save_solutions(branch, solutions)
  config_helper = ConfigHelper.new

  (solutions).each do |solution|
    config_helper.save("xamarin", branch, {
      "name" => solution[:path].to_s,
      "path" => solution[:path].to_s,
      "schemes" => solution[:configs],
      "ios" => solution[:ios],
      "android" => solution[:android]
    })
  end
end

# -----------------------
# --- main
# -----------------------

branch = ARGV[0]
unless branch
  puts "\e[31mBranch not specified\e[0m"
  exit 0
end

xamarin_solutions = []
Dir.glob('**/*.sln', File::FNM_CASEFOLD).each do |solution|
  solution_file = Pathname.new(solution).realpath.to_s

  solution_configs = get_solution_configs(solution_file)
  next if solution_configs.empty?

  base_directory = File.dirname(solution_file)

  solution_config = {
    path: solution,
    configs: solution_configs,
    ios: false,
    android: false
  }

  File.readlines(solution).join("\n").scan(/Project\(\"[^\"]*\"\)\s*=\s*\"[^\"]*\",\s*\"([^\"]*.csproj)\"/).each do |match|
    project = match[0].strip.gsub(/\\/, '/')
    project_path = File.join(base_directory, project)

    received_ios_api, configs = get_xamarin_ios_api_and_configs(project_path)
    solution_config[:ios] = true unless received_ios_api.nil?

    received_android_api, configs = get_xamarin_android_api_and_configs(project_path)
    solution_config[:android] = true unless received_android_api.nil?
  end

  xamarin_solutions << solution_config
end

exit 0 if (xamarin_solutions.count) == 0

puts
puts "\e[32mXamarin project detected\e[0m"

xamarin_solutions.each do |solution|
  puts ""
  puts "\e[32m#{solution[:path]} found with configuration:\e[0m"

  solution[:configs].each { |config| puts " - #{config}" }
end

save_solutions(branch, xamarin_solutions)
