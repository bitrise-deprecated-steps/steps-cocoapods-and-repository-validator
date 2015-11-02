require_relative '../config_helper'

branch = ARGV[0]
unless branch
  puts "\e[31mBranch not specified\e[0m"
  exit 0
end

gradle_files = Dir.glob(File.join("**/build.gradle"), File::FNM_CASEFOLD)

exit 0 if gradle_files.count == 0

puts "\e[32mAndroid gradle project detected\e[0m"

config_helper = ConfigHelper.new

gradle_files.each do |gradle_file|
	configurations = []

	puts ""
	puts "\e[32mInspecting gradle file at path: #{gradle_file}\e[0m"
	IO.popen "gradle tasks --all" do |io|
	  io.each do |line|
	    if match = line.match(/^(?<configuration>\S+:\S*)(\s*-\s*.*)*/)
	    	(configurations ||= []) << match.captures[0]	
	    end
	  end
	end

	puts "Configurations found:"
	if configurations.count > 0
		configurations.each { |configuration| puts configuration }
		puts "#{configurations.count} in total"
		
		config_helper.save("android", branch, {
			name: gradle_file,
			path: gradle_file,
			schemes: configurations
		})
	else
		puts "\e[31mNo configuration found\e[0m"
	end
end