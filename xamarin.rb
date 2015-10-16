require 'find'
require 'pathname'
require 'set'
require 'base64'

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

  return 'mdtool', configs if lines.grep(/Include="monotouch"/).size > 0
  return 'xbuild', configs if lines.grep(/Include="Xamarin.iOS"/).size > 0

  nil
end

def filter_solution_configs(solution_configs, project_configs)
  configs = []
  (solution_configs).each do |config|
    configs << config if project_configs.include? config
  end
  configs
end

# -----------------------
# --- main
# -----------------------

branch = ARGV[0]
puts "\e[32mBranch not specified\e[0m" unless branch

xamarin_solutions = []
Dir.glob('**/*.sln', File::FNM_CASEFOLD).each do |solution|
  solution_file = Pathname.new(solution).realpath.to_s
  puts "(i) solution_file: #{solution_file}"

  solution_configs = get_solution_configs(solution_file)
  next if solution_configs.empty?

  base_directory = File.dirname(solution_file)

  build_tool = nil
  project_configs = []
  File.readlines(solution).join("\n").scan(/Project\(\"[^\"]*\"\)\s*=\s*\"[^\"]*\",\s*\"([^\"]*.csproj)\"/).each do |match|
    project = match[0].strip.gsub(/\\/, '/')
    project_path = File.join(base_directory, project)

    received_build_tool, configs = get_xamarin_ios_api_and_configs(project_path)
    next unless received_build_tool

    build_tool = received_build_tool if build_tool != 'monotouch'
    project_configs += configs unless configs.nil?
  end

  next unless build_tool

  filtered_configs = filter_solution_configs(solution_configs, project_configs)
  next unless filtered_configs

  xamarin_solutions << {
    file: solution,
    configurations: filtered_configs,
    build_tool: build_tool
  }
end

exit 0 if (xamarin_solutions.count) == 0

puts
puts "\e[32mXamarin project detected\e[0m"

xamarin_solutions.each do |solution|
  puts
  puts "Inspecting solution: #{solution[:file]}"

  puts
  puts 'Build tool:'
  puts solution[:build_tool]

  puts
  puts 'Configurations:'
  solution[:configurations].each { |configuration| puts configuration }

  base64_configuration = []
  solution[:configurations].each { |configuration| base64_configuration << Base64.strict_encode64(configuration) }

  project_info = []
  project_info << Base64.strict_encode64(branch)
  project_info << Base64.strict_encode64(solution[:file])
  project_info << Base64.strict_encode64(solution[:build_tool])
  project_info << base64_configuration.join(',')

  File.open("#{ENV['HOME']}/.configuration.xamarin", 'a') { |f| f.puts project_info.join(',') }
end
