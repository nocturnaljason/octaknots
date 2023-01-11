require_relative 'octaknots'

class Octaknots::Snap < Octaknots

	def self.terminate(instance_id)
		if instance_id
			response = @@ec2.terminate_instances({
				instance_ids: [instance_id]
			})
		end
	end

	def self.snap_install(knot_instance_id)
		ssm_command_document = 'Documents/SSMChrootInstall.yaml'
		ssm_command_document_name = 'SSMChrootInstall'
		if knot_instance_id
			if Octaknots::verify_ssm_command_document(ssm_command_document_name, ssm_command_document)
				execution = Octaknots::run_ssm_command_document(knot_instance_id, ssm_command_document_name)

				Octaknots::wait_until_command_success(execution, knot_instance_id)
				Octaknots::msg("Executed command document #{ssm_command_document_name} on instance #{knot_instance_id}.", true)
			else
				Octaknots::msg("Unable to verify document #{ssm_command_document_name} in SSM.", false)
			end
		end
	end

	def self.snap_process(instance_id, knot_instance_id)
		if instance_id and knot_instance_id
			
			volume = Octaknots::get_volume(instance_id)

			if volume
				Octaknots::stop_instance(instance_id)
				Octaknots::msg("Stopped instance #{instance_id}", true)

				Octaknots::msg("Moving volume #{volume[:volume_id]} to #{knot_instance_id}", true)
				Octaknots::detach_volume(volume[:volume_id])
				Octaknots::attach_volume(knot_instance_id, volume[:volume_id], '/dev/sdf')
				Octaknots::msg("Waiting 5 secs for volume to ready on knot-instance #{knot_instance_id}.",true)
				sleep 5
				Octaknots::msg("Using SSM to install SSM in chroot on volume #{volume[:volume_id]}", true)
				Octaknots::Snap::snap_install(knot_instance_id)

				Octaknots::msg("Moving volume #{volume[:volume_id]} back to #{instance_id}", true)
				Octaknots::detach_volume(volume[:volume_id])
				Octaknots::attach_volume(instance_id,volume[:volume_id],volume[:device_name])

				Octaknots::start_instance(instance_id)
				Octaknots::msg("Starting instance #{instance_id}", true)

				Octaknots::msg("Waiting for #{instance_id} to be connected to SSM.",false)
				Octaknots::wait_for_ssm(instance_id)
			else
				#Determine what to put here
			end
		end
	end

	def self.deploy_test_instance(ami_id, subnet_id)

		begin
			Octaknots::msg("Launching Test Instance To Subnet #{subnet_id}", false)
			instance_id = Octaknots::create_instance(ami_id, subnet_id)
		rescue
			Octaknots::msg("Error: Launching instance. try again", false)
			exit
		end

		begin
			Octaknots::msg("Verifying Test Instance SSM Status", false)
			status = Octaknots::get_ssm_status(instance_id)
			Octaknots::msg("Instance: #{instance_id} - SSM Status: #{status}", false)
		rescue
			Octaknots::msg("Problem Getting SSM Status, Exiting", false)
			exit
		end
	end

	def self.enable_ssm_endpoints()

		vpcs = Octaknots::get_vpcs()

		vpcs.each do |vpc|

			Octaknots::msg("Checking vpc #{vpc[:vpc_id]} for SSM endpoints", false)
			endpoints = Octaknots::get_vpc_endpoints()

			vpc_endpoint = Hash.new()

			endpoint_identified = false
			endpoints.each do |endpoint|
				if endpoint[:vpc_id] == vpc[:vpc_id]
					vpc_endpoint[:vpc_id] = vpc[:vpc_id]

					if endpoint[:service_name] == "com.amazonaws.#{@@region}.ssm"	
						ssm_endpoint = endpoint 
					end

					if ssm_endpoint.kind_of?(Endpoint)
						endpoint_identified = true
						Octaknots::msg("Endpoint: #{endpoint[:vpc_endpoint_id]}", false)
					end
				end
			end

			if ! endpoint_identified
				Octaknots::msg("Enabling SSM Endpoint in VPC #{vpc[:vpc_id]}", false)
				ssm_endpoint = Octaknots::create_ssm_endpoint(vpc[:vpc_id])
				Octaknots::msg("Endpoint: #{ssm_endpoint.inspect}", false)
			end

		end
	end

	def start()
		instances = Octaknots::get_instances()
		subnets = Octaknots::get_subnets()

		if @@options[:test_instance]
			
			Octaknots::msg("Starting Octaknots::Snap::Deploy_Test_Instance", false)

			if @@options[:test_instance_subnet]
				subnet = @@options[:test_instance_subnet]
			else
				subnet = subnets[0]
			end

			if @@options[:test_instance_centos]
				Octaknots::msg("Using CentOS 7 AMI for Test Instance", false)
				ami_id = 'ami-006219aba10688d0b'
			elsif @@options[:test_instance_ami]
				Octaknots::msg("Using AMI #{@@options[:test_instance_ami]} for Test Instance", false)
				ami_id = @@options[:test_instance_ami]
			elsif @@region == "us-east-1" and ! @@options[:test_instance_ami] or ! @@options[:test_instance_centos]
				Octaknots::msg("Using Default AMI for Test Instance In Region us-east-1", false)
				ami_id = 'ami-006219aba10688d0b'
			else
				Octaknots::msg("Define An AMI To Deploy The Test Instance With --test-instance-ami", false)
				exit
			end

			Octaknots::Snap::deploy_test_instance(ami_id, subnet)
			exit
		end

		if @@options[:enable_endpoints]

			Octaknots::msg("Starting Octaknots::Snap::Endpoint_Deployment", false)
			
			Octaknots::msg("Enabling SSM Service Endpoints In All VPC's In Region #{@@region}", false)
			Octaknots::Snap::enable_ssm_endpoints() # This applies to the whole region

			exit 
		end

		Octaknots::msg("Starting Octaknots::Snap", false)

		Octaknots::msg("Before Snap Process:", false)
		Octaknots::msg("-------------------------------------", false)
		@@ec2_instances.keys.each do |instance|
			Octaknots::msg("#{instance} : #{Octaknots::get_instance_state(instance)} : #{Octaknots::get_instance_name(instance)} : SSM Status: #{Octaknots::get_ssm_status(instance)}", false)
		end
		Octaknots::msg("", false)

		if !@@dryrun
			subnets.each do |subnet|
				if Octaknots::get_ssm_notconnected_by_subnet(subnet).empty?
					Octaknots::msg("No instances found in this subnet #{subnet} that are not connected to SSM.", true)
				else
					Octaknots::msg("Found instances not connected in subnet #{subnet}.", true)
					not_connected = Octaknots::get_ssm_notconnected_by_subnet(subnet)

					not_connected.each do |instance_id|
						if Octaknots::is_autoscale_instance?(instance_id)
							Octaknots::msg("Autoscale: #{instance_id} | Instance will be skipped to avoid respawning by auto_scaling_group.",false)
							next
						else
							
							Octaknots::msg("Verifying knot instance.", true)
							knot_instance = Octaknots::verify_knot_instance(subnet)
							
							Octaknots::msg("List of nonconnected instances in subnet #{subnet}: #{not_connected.inspect}", true)

							Octaknots::msg("Starting snap_process on instance #{instance_id}.", false)
							if !@@dryrun
								Octaknots::Snap::snap_process(instance_id, knot_instance)
							end
							Octaknots::msg("Finished snap_process on instance #{instance_id}.", false)
						end
					end
				end

				knot_instance = Octaknots::get_knot_instance_by_subnet(subnet)
				if knot_instance
					Octaknots::msg("Terminating knot-instance #{knot_instance}",true)
					Octaknots::msg("",true)
					Octaknots::Snap::terminate(knot_instance)
				end
			end
		else
			subnets.each do |subnet|
				if Octaknots::get_ssm_notconnected_by_subnet(subnet).empty?
					Octaknots::msg("No instances found in this subnet #{subnet} that are not connected to SSM.", true)
				else
					Octaknots::msg("Found instances not connected in subnet #{subnet}.", true)
					not_connected = Octaknots::get_ssm_notconnected_by_subnet(subnet)
					Octaknots::msg("List of nonconnected instances in subnet #{subnet}: #{not_connected.inspect}", true)

					not_connected.each do |instance_id|
						if Octaknots::is_autoscale_instance?(instance_id)
							Octaknots::msg("Autoscale: #{instance_id} | Instance will be skipped to avoid respawning by auto_scaling_group.",false)
							next
						else
							Octaknots::msg("Verifying knot instance.", true)
							knot_instance_id = "knot-3107149804"
					
							Octaknots::msg("Starting snap_process on instance #{instance_id}.", false)
							volume = Octaknots::get_volume(instance_id)

							if volume
								Octaknots::msg("Stopped instance #{instance_id}", true)
								Octaknots::msg("Moving volume #{volume[:volume_id]} to #{knot_instance_id}", true)
								Octaknots::msg("Using SSM to install SSM in chroot on volume #{volume[:volume_id]}", true)
								Octaknots::msg("Moving volume #{volume[:volume_id]} back to #{instance_id}", true)
								Octaknots::msg("Starting instance #{instance_id}", true)
								Octaknots::msg("Finished snap_process on instance #{instance_id}.", false)
							end
						end
					end

					knot_instance = Octaknots::get_knot_instance_by_subnet(subnet)
					
					if knot_instance
						Octaknots::msg("Terminating knot-instance #{knot_instance}",true)
						Octaknots::msg("",true)
					end
				end
			end
		end

	
		@@ec2_instances = Octaknots::get_instances()
		Octaknots::msg("", false)
		Octaknots::msg("After Snap Process:", false)
		Octaknots::msg("-------------------------------------", false)
		@@ec2_instances.keys.each do |instance|
			Octaknots::msg("#{instance} : #{Octaknots::get_instance_state(instance)} : #{Octaknots::get_instance_name(instance)} : SSM Status: #{Octaknots::get_ssm_status(instance)}", false)
		end
	
	end
end