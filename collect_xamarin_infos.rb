require 'find'
require 'pathname'
require 'set'
require 'base64'

# -----------------------
# --- functions
# -----------------------

def get_xamarin_ios_api(project_file_path)
  lines = File.readlines(project_file_path)

  return 'Xamarin.iOS' if lines.grep(/Include="Xamarin.iOS"/).size > 0
  return 'monotouch' if lines.grep(/Include="monotouch"/).size > 0
end

def get_schemes(solution_file_path)
  scheme_start = 'GlobalSection(SolutionConfigurationPlatforms) = preSolution'
  scheme_end = 'EndGlobalSection'
  is_next_line_scheme = false
  schemes = Set.new

  File.open(solution_file_path).each do |line|
    if line.include? scheme_start
      is_next_line_scheme = true
      next
    end

    if line.include? scheme_end
      is_next_line_scheme = false
      next
    end

    next if is_next_line_scheme == false

    splits = line.split(' = ')
    if splits.count == 2
      scheme = splits[1]
      schemes.add(scheme)
    else
      puts "  (error) faild to get scheme from line: #{line}"
    end
  end

  schemes
end

def write_infos(solutions, branch)
  branch_base_64 = Base64.strict_encode64(branch)

  content = ''
  apis_str = ''
  schemes_str = ''

  (solutions).each do |solution|
    solution_path_base_64 = Base64.strict_encode64(solution['path'])
    api_base_64 = Base64.strict_encode64(solution['api'])

    (solution['schemes']).each do |scheme|
      scheme_base_64 = Base64.strict_encode64(scheme)
      schemes_str = schemes_str + scheme_base_64 + ','
    end

    content += branch_base_64 + ',' + solution_path_base_64 + ',' + api_base_64 + ',' + schemes_str + "\n"
  end

  path = File.expand_path('~/.configuration.xamarin')
  File.open(path, 'a') { |file| file.write(content) }
end

# -----------------------
# --- main
# -----------------------

# Parse parameters
branch = ARGV[0]
puts "Branch: #{branch}"

# Check solution files
solutions = []
Dir['**/*.sln'].each do |solution_file_path|
  schemes = get_schemes(solution_file_path)

  pn = Pathname.new(solution_file_path)
  solution_base_dir_path, _solution_file_name = pn.split

  xamarin_ios_api = ''
  xamarin_ios_project_file_paths = Set.new

  query = 'Project\\(\"[^\"]*\"\\)\\s*=\\s*\"[^\"]*\",\\s*\"([^\"]*.csproj)\"'
  matches = File.readlines("#{solution_file_path}").select { |n| n[/#{query}/i] }
  (matches).each do |match|
    splits = match.split(', ')
    if splits.count == 3
      project_file_name = splits[1].gsub(/\\/, '/').delete! '""'
      project_file_path = File.join(solution_base_dir_path, project_file_name)

      api = get_xamarin_ios_api(project_file_path)

      if api.to_s != '' && xamarin_ios_api != 'monotouch'
        xamarin_ios_api = api
        xamarin_ios_project_file_paths.add(project_file_path)
      end
    else
      puts "  (error) unhandled solution content line: #{match}"
    end
  end

  next if xamarin_ios_project_file_paths.count == 0

  solution = {}
  solution['path'] = solution_file_path
  solution['schemes'] = schemes
  solution['api'] = xamarin_ios_api
  solutions.push(solution)
end

if solutions.count > 0
  (solutions).each do |solution|
    puts
    puts "Solution found at: #{solution['path']}"

    puts
    puts ' schemes:'
    (solution['schemes']).each do |scheme|
      puts "   #{scheme}"
    end

    puts
    puts " api: #{solution['api']}"
  end

  write_infos(solutions, branch)
end

exit(solutions.count > 0 ? 0 : 1)
