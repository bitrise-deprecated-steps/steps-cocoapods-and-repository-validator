require_relative '../config_helper'

branch = ARGV[0]
unless branch
  puts "\e[31mBranch not specified\e[0m"
  exit 0
end

exit 0 unless File.exists?("build.gradle")

puts "\e[32mAndroid gradle project detected\e[0m"

configurations = {}
config_helper = ConfigHelper.new

puts ""
puts "gradle tasks --all"
IO.popen "gradle tasks --all" do |io|
  io.each do |line|
    puts line

    if match = line.match(/^(?<project>\S+):(?<configuration>\S*)(\s*-\s*.*)*/)
    	(configurations[match.captures[0]] ||= []) << match.captures[1]
    end
  end
end

puts ""
puts "Configurations found:"
if configurations.count > 0
	configurations.each do |project, configurations|
		configurations.each do |config|
			puts "#{project}:#{config}"
		end
	
		config_helper.save("android", branch, {
			name: project,
			path: project,
			schemes: configurations
		})
	end
else
	puts "\e[31mNo configuration found\e[0m"
end