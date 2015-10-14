require 'find'
require 'pathname'
require 'set'
require 'base64'

# -----------------------
# --- functions
# -----------------------

def get_xamarin_ios_api(project_file_path)
  lines = File.readlines(project_file_path)

  return 'mdtool' if lines.grep(/Include="monotouch"/).size > 0
  return 'xbuild' if lines.grep(/Include="Xamarin.iOS"/).size > 0

  nil
end

def get_configuration(solution_file_path)
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

# -----------------------
# --- main
# -----------------------

branch = ARGV[0]
unless branch
  puts "\e[32mBranch not specified\e[0m"
end

xamarin_solutions = []
Dir.glob("**/*.sln", File::FNM_CASEFOLD).each do |solution|
  configuration = get_configuration(solution)
  next if configuration.empty?

  pn = Pathname.new(solution)
  base_directory, solution_file_name = pn.split

  build_tool = nil
  File.readlines(solution).join("\n").scan(/Project\(\"[^\"]*\"\)\s*=\s*\"[^\"]*\",\s*\"([^\"]*.csproj)\"/).each do |match|
    project = match[0].strip.gsub(/\\/,'/')
    project_path = File.join(base_directory, project)

    received_build_tool = get_xamarin_ios_api(project)
    build_tool = received_build_tool if (received_build_tool != nil && build_tool != "monotouch")
    next unless received_build_tool
  end

  xamarin_solutions << {
    file: solution,
    configurations: configuration,
    build_tool: build_tool
  }
end

exit 0 if (xamarin_solutions.count) == 0

puts "\e[32mXamarin project detected\e[0m"

xamarin_solutions.each do |solution|
  puts ""
  puts "Inspecting solution: #{solution[:file]}"

  puts ""
  puts "Build tool:"
  puts solution[:build_tool]

  puts ""
  puts "Configurations:"
  solution[:configurations].each { |configuration| puts configuration }

  base64_configuration = []
  solution[:configurations].each { |configuration| base64_configuration << Base64.strict_encode64(configuration) }

  project_info = []
  project_info << Base64.strict_encode64(branch)
  project_info << Base64.strict_encode64(solution[:file])
  project_info << Base64.strict_encode64(solution[:build_tool])
  project_info << base64_configuration.join(",")
  
  File.open("#{ENV['HOME']}/.configuration.xamarin", 'a') { |f| f.puts project_info.join(',') }
end
