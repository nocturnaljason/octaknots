require 'optparse'

Options = Struct.new(	:name,
						:exclude,
						:region,
						:profile,
						:verbose,
						:test_instance,
						:test_instance_subnet,
						:test_instance_ami,
						:test_instance_centos,
						:enable_endpoints,
						:dryrun
					)

Options1 = Struct.new(
						:name,
						:exclude,
						:include,
						:profile,
						:region,
						:disable_scan,
						:disable_install,
						:disable_orca,
						:disable_snapshots,
						:remove_snapshots,
						:print_timings
					)
class Parser
	def self.parse(options)
		args = Options.new('snap')

		opt_parser = OptionParser.new do |opts|
			opts.banner = "Usage: #{File.basename($PROGRAM_NAME)} [options]"

			opts.on("-eEXCLUDE_LIST", "--exclude=EXCLUDE_LIST", Array, "Provide a list of instance_ids seperated by a comma to exclude") do |exclude_list|
				options[:exclude] = exclude_list
			end

			opts.on("-rREGION", "--region=REGION", "AWS region to use like us-east-1") do |r|
				args[:region]=r
			end

			opts.on("-pPROFILE", "--profile=PROFILE", "AWS profile to use like default") do |p|
				args[:profile]=p
			end

			opts.on("-t", "--test-instance" , "Add a test instance specify --test-instance-subnet to deploy to a specific subnet") do |ti|
				args[:test_instance] = ti
			end

			opts.on("-sSUBNET", "--test-instance-subnet=SUBNET", "Use with --test-instance to deploy to a specific subnet") do |tis|
				args[:test_instance_subnet] = tis
			end

			opts.on("-iAMI", "--test-instance-ami=AMI", "Use with --test-instance to deploy using a specific ami-id") do |i|
				args[:test_instance_ami] = i
			end

			opts.on("-c", "--test-instance-centos", "Use with --test-instance to deploy CentOS 7 in the only region that is supported us-east-1") do |c|
				args[:test_instance_centos] = c
			end

			opts.on("-n", "--enable-endpoints", "Enable VPC Amazon Endpoint Services for SSM") do |eps|
				args[:enable_endpoints] = eps 
			end

			opts.on("-v", "--verbose", "Log verbosely on stdout") do |v|
				args[:verbose] = v
			end

			opts.on("-d", "--dryrun", "Perform a dryrun without changing anything") do |dry|
				args[:dryrun] = dry
			end

			opts.on("-h", "--help", "Print help information") do
				puts opts
				exit
			end
		end

		opt_parser.parse!(options)
		return args
	end
end

class OrcaWhaleParser
	def self.parse(options)
		args = Options1.new('orcawhale')

		opt_parser = OptionParser.new do |opts|
			opts.banner = "Usage: #{File.basename($PROGRAM_NAME)} [options]"

			opts.on("-eEXCLUDE_LIST", "--exclude=EXCLUDE_LIST", Array, "Provide a list of instance_ids seperated by a comma to exclude") do |exclude_list|
				args[:exclude] = exclude_list
			end

			opts.on("-aINCLUDE_LIST","--include=INCLUDE_LIST", Array, "Provide a list of instances_ids seperated by a comma to include") do |include_list|
				args[:include] = include_list
			end

			opts.on("-rREGION", "--region=REGION", "AWS region to use like us-east-1") do |r|
				args[:region]=r 
			end

			opts.on("-pPROFILE", "--profile=PROFILE", "AWS profile to use like default") do |p|
				args[:profile]=p
			end

			opts.on("-n", "--disable-scan", "Disables patch scanning") do |n|
				args[:disable_scan]=n
			end

			opts.on("-i", "--disable-install", "Disables patch installation") do |i|
				args[:disable_install]=i
			end

			opts.on("-o", "--disable-orca", "Disables Orca alert display") do |o|
				args[:disable_orca]=o
			end

			opts.on("-s", "--disable-snapshots", "Disables recovery snapshots") do |s|
				args[:disable_snapshots]=s
			end

			opts.on("-t", "--print-timings", "Prints the current time after each step") do |t|
				args[:print_timings]=t
			end

			opts.on("-c", "--remove-snapshots", "Removes all snapshots created by orcawhale in the region") do |c|
				args[:remove_snapshots]=c
			end

			opts.on("-h", "--help", "Print help information") do
				puts opts
				exit
			end
		end

		opt_parser.parse!(options)
		return args
	end
end
