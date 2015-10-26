require 'timeout'
require 'base64'

branch = ARGV[0]
unless branch
  puts "\e[32mBranch not specified\e[0m"
  exit 0
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

	scheme_pathes = Dir[File.join(project, "xcshareddata/xcschemes/*.xcscheme")]
	schemes = []
	scheme_pathes.each do |scheme_path|
		scheme_name = File.basename(scheme_path, ".*")

		puts scheme_name
		schemes << Base64.strict_encode64(scheme_name)
	end

	if schemes.empty?
		puts "\e[33mNo shared scheme found\e[0m"
		next
	end

	project_info = []
	project_info << Base64.strict_encode64(branch)
	project_info << Base64.strict_encode64(project)
	project_info.concat(schemes)

	File.open("#{ENV['HOME']}/.configuration.ios", 'a') { |f| f.puts project_info.join(',') }
end