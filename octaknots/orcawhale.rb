require_relative 'orca'
require_relative 'parser'
require 'aws-sdk'
require 'time'
require 'colorize'
require 'socket'

Instance = Struct.new(
	:instance_id,
	:image_id,
	:instance_type,
	:key_name,
	:monitoring,
	:private_dns_name,
	:private_ip_address,
	:public_dns_name,
	:public_ip_address,
	:platform,
	:state,
	:subnet_id,
	:vpc_id,
	:block_device_mappings,
	:ebs_optimized,
	:architecture,
	:security_groups,
	:tags,
	:virtualization_type,
	:requester_id,
	:reservation_id,
	:iam_instance_profile,
	:ssm_status
)

class OrcaWhale

	# Verifies the status of SSM using SSM to check if it is connected
	def self.get_ssm_status(instance_id)
		
		if instance_id

			ssm_status = @@ssm.get_connection_status({target: instance_id})
			return ssm_status['status']
		
		else
		
			return nil
		
		end
	
	end

	# Returns an array of all instances in a region
	def self.get_instances(instance_ids = nil)

		instances = []
		

		if instance_ids.is_a?(Array)

			response = @@ec2.describe_instances({
				instance_ids: instance_ids
			})

		else

			response = @@ec2.describe_instances()

		end

		response.reservations.each do |reservation|
		
			reservation.instances.each do |instance|
		
				aws_instance = Instance.new
				aws_instance[:instance_id] = instance[:instance_id]
				aws_instance[:image_id] = instance[:image_id]
				aws_instance[:instance_type] = instance[:instance_type]
				aws_instance[:key_name] = instance[:key_name]
				aws_instance[:monitoring] = instance[:monitoring][:state]
				aws_instance[:private_ip_address] = instance[:private_ip_address]
				aws_instance[:private_dns_name] = instance[:private_dns_name]
				aws_instance[:public_ip_address] = instance[:public_ip_address]
				aws_instance[:public_dns_name] = instance[:public_dns_name]
				aws_instance[:platform] = instance[:platform]
				aws_instance[:state] = instance[:state]
				aws_instance[:subnet_id] = instance[:subnet_id]
				aws_instance[:vpc_id] = instance[:vpc_id]
				aws_instance[:block_device_mappings] = instance[:block_device_mappings]
				aws_instance[:ebs_optimized] = instance[:ebs_optimized]
				aws_instance[:architecture] = instance[:architecture]
				aws_instance[:security_groups] = instance[:security_groups]
				aws_instance[:tags] = instance[:tags]
				aws_instance[:virtualization_type] = instance[:virtualization_type]
				aws_instance[:iam_instance_profile] = instance[:iam_instance_profile]
				aws_instance[:ssm_status] = OrcaWhale::get_ssm_status(instance[:instance_id])

				instances << aws_instance
		
			end
		
		end

		return instances 
	end

	def self.get_instance(instance_id)

		aws_instance = Instance.new

		response = @@ec2.describe_instances({
			instance_ids: [instance_id]
		})

		begin
		
			instance = response.reservations[0].instances[0]
			
			aws_instance[:instance_id] = instance[:instance_id]
			aws_instance[:image_id] = instance[:image_id]
			aws_instance[:instance_type] = instance[:instance_type]
			aws_instance[:key_name] = instance[:key_name]
			aws_instance[:monitoring] = instance[:monitoring][:state]
			aws_instance[:private_ip_address] = instance[:private_ip_address]
			aws_instance[:private_dns_name] = instance[:private_dns_name]
			aws_instance[:public_ip_address] = instance[:public_ip_address]
			aws_instance[:public_dns_name] = instance[:public_dns_name]
			aws_instance[:platform] = instance[:platform]
			aws_instance[:state] = instance[:state]
			aws_instance[:subnet_id] = instance[:subnet_id]
			aws_instance[:vpc_id] = instance[:vpc_id]
			aws_instance[:block_device_mappings] = instance[:block_device_mappings]
			aws_instance[:ebs_optimized] = instance[:ebs_optimized]
			aws_instance[:architecture] = instance[:architecture]
			aws_instance[:security_groups] = instance[:security_groups]
			aws_instance[:tags] = instance[:tags]
			aws_instance[:virtualization_type] = instance[:virtualization_type]
			aws_instance[:iam_instance_profile] = instance[:iam_instance_profile]
			aws_instance[:ssm_status] = OrcaWhale::get_ssm_status(instance[:instance_id])
		
		rescue
		
			return nil
		
		end

		return aws_instance
	end

	# Scans for patches that need to be applied using a command document that sends the information to SSM
	def self.patch_scan(instance_id)
		
		status = false

		response = @@ssm.send_command ({
			instance_ids: [instance_id],
			document_name: 'AWS-RunPatchBaseline',
			parameters: {
				'Operation' => ['Scan'],
				'RebootOption' => ['NoReboot']
			}
		})

		command_id = response[:command][:command_id]

		response = @@ssm.list_commands({
				command_id: command_id,
				instance_id: instance_id,
				max_results: 1,
				filters: [
					{
						key: "DocumentName",
						value: "AWS-RunPatchBaseline"
					}]
			})

		while response.commands[0].status == "Pending" or response.commands[0].status == "InProgress"
		
			sleep 1
		 
		 	response = @@ssm.list_commands({
				command_id: command_id,
				instance_id: instance_id,
				max_results: 1,
				filters: [
					{
						key: "DocumentName",
						value: "AWS-RunPatchBaseline"
					}]
				})

			if response.commands[0].status == "Success"
		 		
		 		status = true
		 		break
		 	
		 	elsif response.commands[0].status == "Failed"
		 	
		 		break
		 	
		 	end
		 
		 end

		return status

	end

	# Executes a command document in SSM to install all available patches for an instance
	def self.patch_instance(instance_id)

		status = false

		# Execute the command document on the desired instance with Install and RebootIfNeeded parameters to install the patches
		response = @@ssm.send_command ({
			instance_ids: [instance_id],
			document_name: 'AWS-RunPatchBaseline',
			parameters: {
				'Operation' => ['Install'],
				'RebootOption' => ['RebootIfNeeded']
			}
		})

		# Get the command_id returned by the send_command method to we can check its status later
		command_id = response[:command][:command_id]

		# Check the status of the command document execution using the command_id we get previously
		response = @@ssm.list_commands({
				command_id: command_id,
				instance_id: instance_id,
				max_results: 1,
				filters: [
					{
						key: "DocumentName",
						value: "AWS-RunPatchBaseline"
					}]
			})

		if response
			# Loop while the command is still executing and wait until we hit a final status before exiting
			while response.commands[0].status == "Pending" or response.commands[0].status == "InProgress"

				# Wait 1 second between loops to give it time to complete
				sleep 1

				# Retrieve information on the state of the SSM command document execution
			 	response = @@ssm.list_commands({
					command_id: command_id,
					instance_id: instance_id,
					max_results: 1,
					filters: [
						{
							key: "DocumentName",
							value: "AWS-RunPatchBaseline"
						}]
					})

			 	# Check the status of the SSM command document execution
				if response.commands[0].status == "Success"

			 		# We return a true states meaning it was a success and break the loop when we get this status
			 		status = true
			 		break
			 
			 	elsif response.commands[0].status == "Failed"
			 		# If we hit this status we exit the while loop
			 		break
			 
			 	end
			end
		end

		return status

	end

	# Displays the state of patches using SSM to retrieve the information to print
	def self.print_patch_status(instance_id)

		# This gets the states of patches by calling SSM to get the information and retrieving the information provided by the command document
		response = @@ssm.describe_instance_patch_states(
		{
			instance_ids: [instance_id]
		})

		begin
		# Print a pretty format summary of patch states of the instance
		puts ""
		puts "  Patch Summary"
		puts "    baseline_id:    #{response.instance_patch_states[0].baseline_id}"
		puts "    snapshot_id:    #{response.instance_patch_states[0].snapshot_id}"
		puts "    missing_count:  #{response.instance_patch_states[0].missing_count}"
		puts "    failed_count:   #{response.instance_patch_states[0].failed_count}"
		puts "    operation:      #{response.instance_patch_states[0].operation}"
		puts "    reboot_options: #{response.instance_patch_states[0].reboot_option}"
		puts "    critical_count: #{response.instance_patch_states[0].critical_non_compliant_count}"
		puts "    security_count: #{response.instance_patch_states[0].security_non_compliant_count}"
		puts "    other_count:    #{response.instance_patch_states[0].other_non_compliant_count}"
		puts ""
		rescue
			puts "Unable to print patch status."
		end

	end

	# Gets the root_volume by checking the block_device_mappings returned by OrcaWhale::get_instance()
	def self.get_root_volume(instance_id)

		volume_id = nil 

		# Get the instance structure for the instance_id passed to this method
		instance = OrcaWhale::get_instance(instance_id)


		if instance

			# Loop through the block devices mapped to the instance
			instance[:block_device_mappings].each do |ebs|
				
				# Check if we have the root_volume and get its id
				if ebs[:device_name] == '/dev/sda1'

					# Get the volume id from the block_device_mappings for /dev/sda1
					volume_id = ebs[:ebs][:volume_id]
				
				elsif ! volume_id and ebs[:device_name] == '/dev/xvda'

					# Get the volume id from the block_device_mappings for /dev/xvda which could also be the root_volume
					volume_id = ebs[:ebs][:volume_id]
				
				end
			
			end
		
		end

		# Return the volume_id or nil if we don't have one
		return volume_id

	end

	def self.create_recovery_snapshot(instance_id)

		# Get the root_volume of the instance passed to this method
		root_volume = OrcaWhale::get_root_volume(instance_id)
		
		snapshot_id = nil 
		response = nil 

		# Make sure we have a volume to work with
		if root_volume

			# Create a snapshot from the root_volume of the instance which should include everything we care about
			response = @@ec2.create_snapshot({
				description: "#{instance_id} - /dev/sda1 - timestamp: #{Time.now.to_i}",
				volume_id: root_volume,
				tag_specifications: [
					{
						resource_type: 'snapshot',
						tags: [
							{
								key: 'source_ebs_volume',
								value: root_volume
							},
							{
								key: 'epoch_timestamp',
								value: "#{Time.now.to_i}"
							},
							{
								key: 'source_instance',
								value: instance_id
							},
							{
								key: 'dbi:Application',
								value: 'orcawhale'
							},
							{
								key: 'dbi:Team',
								value: 'DevOps'
							}

						]
					}
				]
			})

		end

		if response
			
			if response[:snapshot_id]
				
				snapshot_id = response[:snapshot_id]
				
				begin
					@@ec2.wait_until(:snapshot_completed, {:snapshot_ids => [snapshot_id]})
				rescue
					snapshot_id = nil
				end
			
			end

		end

		return snapshot_id

	end

	# Display orca alerts in a specific format based on what we get back from Orca::get_alerts_by_instance()
	def self.print_orca_alerts(instance_id)

		# Call Orca::get_alerts_by_instance() to get the alerts for the instance
		alerts = @@orca.get_alerts_by_instance(instance_id)

		# Verify we have an array and not nil
		if alerts.kind_of?(Array)
			
			# Check we got alerts back from Orca
			if !alerts.empty?()

				# Print the number of alerts we found
				puts "  alerts: -(#{alerts.size})-".colorize(:red)

				alerts.each do |alert|
					
					# Print information regarding the alert formatted to look pretty
					puts ""
					puts "    alert_id:             #{alert['state']['alert_id']}"
					puts "    severity:             #{alert['state']['severity']}"
					puts "    score:                #{alert['state']['score']}"
					puts "    distribution_name:    #{alert['asset_distribution_name']}"
					puts "    distribution_version: #{alert['asset_distribution_version']}"
					puts "    vm_id:                #{alert['vm_id']}"
					puts "    image_id:             #{alert['asset_image_id']}"
					puts "    type:                 #{alert['type']}"
					puts "    rule_id:              #{alert['rule_id']}"
					puts "    subject_type:         #{alert['subject_type']}"
					puts "    description:          #{alert['description']}" 
					puts "    details:              #{alert['details']}"
					puts "    cve_list:             #{alert['cve_list']}"	
					puts "    recommendation:       #{alert['recommendation']}"	
					puts ""
				
				end

			else
				puts "  No Orca alerts found".colorize(:red)
			end
		else
			puts "  Unknown error while retrieving Orca alerts".colorize(:red)
		end

		puts ""

	end

	def start()

		if @@options[:remove_snapshots]
			OrcaWhale::remove_snapshots()
			exit 
		end


		if @@options[:include].is_a?(Array)
		
			instances = OrcaWhale::get_instances(@@options[:include])
		else

			# get the list of instances so we can iterator through the ones that are connected to SSM
			instances = OrcaWhale::get_instances()
		
		end


		not_connected = []

		failed = []
		
		excluded = []

		# loop through the array looking for ssm_status == connected to ensure we can use command documents in SSM 
		instances.each do |instance|

			if @@options[:exclude].is_a?(Array)
				if @@options[:exclude].include?(instance[:instance_id])

					excluded << instance

					next
				end
			end

			# checks to see if we are connected to SSM and adds the ones that are not to a not_connected array to display afterwards
			if instance[:ssm_status] == "connected"
				
				# run a command document to scan for the patches that are missing
				OrcaWhale::print_time()
				status = OrcaWhale::patch_scan(instance[:instance_id])

				if status
					
					puts "-+<[ Instance : #{instance[:instance_id]} ]>+-".colorize(:green)
					puts "     +[ VPC   : #{instance[:vpc_id]} ]+".colorize(:blue)
					
					if !@@options[:disable_orca]
						
						puts ""
						OrcaWhale::print_time()
						puts "-[Orca Alerts]-".colorize(:green)
						puts ""
						
						# displays the orca alerts in a specific format
						OrcaWhale::print_orca_alerts(instance[:instance_id])
					
					end
 	
 					if !@@options[:disable_snapshots]
	 					OrcaWhale::print_time()
						puts "-[Recovery Information]-".colorize(:green)
						puts ""
						
						# takes an ebs snapshot of /dev/sda1 or /dev/xvda
						snapshot_id = OrcaWhale::create_recovery_snapshot(instance[:instance_id])
						
						# verify we actually got a snapshot back from create_recovery_snapshot					
						if snapshot_id
							puts "  recovery_snapshot_id: #{snapshot_id}".colorize(:yellow)
							puts ""
						else
							puts "  unable to create recovery snapshot skipping patch".colorize(:red)
							puts ""
							next
						end
					end

					if !@@options[:disable_scan]

						# display the patch summary in a specific format using information sent by the command document
						OrcaWhale::print_time()
						puts "-[Before Patch]-".colorize(:green)
						OrcaWhale::print_patch_status(instance[:instance_id])
					
					end

					if !@@options[:disable_install]
					
						OrcaWhale::print_time()
						puts "-[Installing Patches]-".colorize(:green)
						puts ""
						puts "  * | #{instance[:instance_id]} | - (vpc: #{instance[:vpc_id]}) | *".colorize(:yellow)
						puts ""
					
						# this actual performs the patching of the instance by calling a SSM command document
						OrcaWhale::patch_instance(instance[:instance_id])
						
						# display the patch summary after calling the command document with parameter "Install" and prints in a specific format
						OrcaWhale::print_time()
						puts "-[After Patch]-".colorize(:green)
						OrcaWhale::print_patch_status(instance[:instance_id])
						puts ""
					
					end


				else
					
					# if we get this it means we could run a command document with parameter scan
					# there could be possible three reasons it fails
					# 1. The operating system has a problem with python
					# 2. It can not reach the OS repos to install or check updates
					# 3. Missing the required iam_instance_profile needed for SSM to update the amazon data
					puts "-+<[ Instance: #{instance[:instance_id]} ]>+-".colorize(:green) + " -[ Failed ]- ".colorize(:red)
					puts ""
					failed << instance
				
				end
			else

				not_connected << instance
			
			end
		end

		# display the instances not connected to SSM as we were not able to patch them
		OrcaWhale::print_time()
		puts "==[Instances Not Patched]==".colorize(:red)
		puts ""
		not_connected.each do |nc|
			puts "  * | #{nc[:instance_id]} | - (vpc: #{nc[:vpc_id]}) | *".colorize(:yellow)
		end

		puts "" 

		# display the instances that failed during scan
		OrcaWhale::print_time()
		puts "==[Instances Failed]==".colorize(:red)
		puts ""
		failed.each do |failure|
			puts "  * | #{failure[:instance_id]} | - (vpc: #{failure[:vpc_id]}) | *".colorize(:yellow)
		end

		puts ""

		# display the instances that failed during scan
		OrcaWhale::print_time()
		puts "==[Instances Excluded]==".colorize(:red)
		puts ""
		excluded.each do |exclude|
			puts "  * | #{exclude[:instance_id]} | - (vpc: #{exclude[:vpc_id]}) | *".colorize(:yellow)
		end

		# print the time the script reaches the end for operational value and when it finished just in case anyone asks
		puts ""
		puts "OrcaWhile Patch End: #{Time.now}".colorize(:blue)
		puts ""

	end

	def self.print_time()
		if @@options[:print_timings]
			puts "#{Time.now}".colorize(:blue)
		end
	end

	def self.remove_snapshots()
		
		snapshot_id = nil 

		snapshots = @@ec2.describe_snapshots({
			filters: [
				{
					name: "tag:dbi:Application",
					values: ["orcawhale"]
				}
			]
		})

		puts "-[Remvoing Snapshots]-".colorize(:green)
		puts ""
		snapshots.snapshots.each do |snapshot|
			snapshot_id = snapshot[:snapshot_id]
		
			puts "  * | #{snapshot_id} | *".colorize(:yellow)
			response = @@ec2.delete_snapshot({
				snapshot_id: snapshot_id
			})
		end
		if !snapshot_id
			puts "  No snapshots found".colorize(:red)
		end
		puts ""

	end

	def self.commandline_arguments()
		@@options = OrcaWhaleParser.parse(ARGV)
	end

	# define the code that OrcaWhale.new executes to create an OrcaWhale object as it populates the Class variables and sets up Amazon clients
	def initialize()

		OrcaWhale::commandline_arguments()

		if @@options[:region]
			region = @@options[:region]
		else
			region = 'us-east-1'
		end

		if @@options[:profile]
			profile = @@options[:profile]
		else
			profile = 'default'
		end

		# is the client for Amazon EC2 and used to manage resources in a vpc
		@@ec2 = Aws::EC2::Client.new (
		{
			profile: profile,
			region: region
		})

		# is the client for Amazon SSM and used to execute command documents and verify instances are connected to the service
		@@ssm = Aws::SSM::Client.new (
		{
			profile: profile,
			region: region
		})

		# print some useful information about the execution environment for operational value
		puts "==[ OrcaWhale Security Patch Management ]==".colorize(:green)
		puts ""
		puts "OrcaWhale Patch Time: #{Time.now}".colorize(:blue)
		puts "OrcaWhale Hostname:   #{Socket.gethostname}".colorize(:blue)
		puts "OrcaWhale ID:         orcawhale-#{Time.now.to_i}".colorize(:blue)
		puts ""

		if !@@options[:disable_orca]
			# Create an Orca object to use the Orca Security api to verify security alerts for an instance
			@@orca = Orca.new
		end

	end

end
