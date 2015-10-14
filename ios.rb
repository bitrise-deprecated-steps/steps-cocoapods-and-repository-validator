require 'timeout'
require 'base64'

branch = ARGV[0]
unless branch
  puts "\e[32mBranch not specified\e[0m"
end

# Check for project files
ios_projects = Dir.glob("**/*.xcodeproj", File::FNM_CASEFOLD)
ios_projects.concat(Dir.glob("**/*.xcworkspace", File::FNM_CASEFOLD))
ios_projects.delete_if { |workspace| workspace.include?(".xcodeproj/") || workspace.include?(".xcworkspace") }

exit 0 if (ios_projects.count) == 0

puts "\e[32miOS project detected\e[0m"

# Check for Podfiles
puts "Checking for Podfile"
podfiles = Dir.glob("**/Podfile", File::FNM_CASEFOLD)
podfiles.delete_if { |podfile| podfile.include? ".git/" }

if podfiles.count > 0
	# Update cocoapods if needed
	if ENV['is_update_cocoapods'] != "false"
		puts "Updating CocoaPods version..."
		system("bash \"#{ENV['THIS_SCRIPTDIR']}/_steps-cocoapods-update/step.sh\"")
		exit 1 if $?.exitstatus != 0
	end

	# Run `pod install`
	puts "Installing Podfile"
	system("bash \"#{ENV['THIS_SCRIPTDIR']}/_steps-cocoapods-install/run_pod_install.sh\"")
	exit 1 if $?.exitstatus != 0
else
	puts "No Podfile found"
end

ios_projects.each do |project|
	puts ""
	puts "Inspecting project: #{project}"
	puts ""
	puts "Schemes:"

	xcodebuild_output = nil
	begin
		Timeout.timeout(20) do
			xcodebuild_output = `xcodebuild -list -project #{project}`.split("\n") if project.include? ".xcodeproj"
			xcodebuild_output = `xcodebuild -list -workspace #{project}`.split("\n") if project.include? ".xcworkspace"
		end
	rescue Timeout::Error
		puts "\e[31mTimeout: Failed to get schemes from #{project}\e[0m"
		exit 1
	end

	if xcodebuild_output.empty?
		puts "No shared scheme found"
		next
	end

	schemes = nil
	xcodebuild_output.each do |line|
		stripped_line = line.strip

		if schemes
			puts stripped_line
			schemes << Base64.strict_encode64(stripped_line)
		end
		schemes = [] if stripped_line.eql? "Schemes:"
	end

	project_info = []
	project_info << Base64.strict_encode64(branch)
	project_info << Base64.strict_encode64(project)
	project_info.concat(schemes)

	File.open("#{ENV['HOME']}/.configuration.ios", 'a') { |f| f.puts project_info.join(',') }
end