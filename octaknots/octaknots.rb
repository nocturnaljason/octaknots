require 'aws-sdk'
require_relative 'parser'


VPC = Struct.new(   :cidr_block,
					:dhcp_options_id,
					:state,
					:vpc_id,
					:owner_id,
					:instance_tenancy,
					:is_default,
					:tags 
				)

Endpoint = Struct.new( :vpc_endpoint_id,
					   :vpc_endpoint_type,
					   :vpc_id,
					   :service_name,
					   :state,
					   :policy_document,
					   :route_table_ids,
					   :subnet_ids,
					   :groups,
					   :private_dns_enabled,
					   :requester_managed,
					   :network_interface_ids,
					   :dns_entries,
					   :creation_timestamp,
					   :tags,
					   :owner_id,
					   :last_error
					)

class Octaknots


	def self.msg(message, verbose)
		if @@verbose
			if verbose || !verbose
				puts message
			end
		else
			if !verbose
				puts message
			end
		end
	end

	def self.get_vpc(vpc_id)
		resp = @@ec2.describe_vpcs({
			vpc_ids: [vpc_id]
		})

		vpc = VPC.new 
		vpc[:vpc_id] = resp.vpcs[0][:vpc_id]
		vpc[:cidr_block] = resp.vpcs[0][:cidr_block]
		vpc[:dhcp_options_id] = resp.vpcs[0][:dhcp_options_id]
		vpc[:state] = resp.vpcs[0][:state]
		vpc[:owner_id] = resp.vpcs[0][:owner_id]
		vpc[:instance_tenancy] = resp.vpcs[0][:instance_tenancy]
		vpc[:is_default] = resp.vpcs[0][:is_default]
		vpc[:tags] = resp.vpcs[0][:tags]


		return vpc
	end

	def self.get_vpcs()
		resp = @@ec2.describe_vpcs()

		vpcs = Array.new()

		resp.vpcs.each do |vpc|
			vpcs << Octaknots::get_vpc(vpc[:vpc_id])
		end

		return vpcs
	end

	def self.get_vpc_endpoint(endpoint_id)
		resp = @@ec2.describe_vpc_endpoints({
			vpc_endpoint_ids: [endpoint_id]
		})

		vpc_endpoint = Endpoint.new 

		vpc_endpoint[:vpc_endpoint_id] = resp.vpc_endpoints[0][:vpc_endpoint_id]
		vpc_endpoint[:vpc_endpoint_type] = resp.vpc_endpoints[0][:vpc_endpoint_type]
		vpc_endpoint[:vpc_id] = resp.vpc_endpoints[0][:vpc_id]
		vpc_endpoint[:service_name] = resp.vpc_endpoints[0][:service_name]
		vpc_endpoint[:state] = resp.vpc_endpoints[0][:state]
		vpc_endpoint[:policy_document] = resp.vpc_endpoints[0][:policy_document]
		vpc_endpoint[:route_table_ids] = resp.vpc_endpoints[0][:route_table_ids]
		vpc_endpoint[:subnet_ids] = resp.vpc_endpoints[0][:subnet_ids]
		vpc_endpoint[:groups] = resp.vpc_endpoints[0][:groups]
		vpc_endpoint[:private_dns_enabled] = resp.vpc_endpoints[0][:private_dns_enabled]
		vpc_endpoint[:requester_managed] = resp.vpc_endpoints[0][:requester_managed]
		vpc_endpoint[:network_interface_ids] = resp.vpc_endpoints[0][:network_interface_ids]
		vpc_endpoint[:dns_entries] = resp.vpc_endpoints[0][:dns_entries]
		vpc_endpoint[:creation_timestamp] = resp.vpc_endpoints[0][:creation_timestamp]
		vpc_endpoint[:tags] = resp.vpc_endpoints[0][:tags]
		vpc_endpoint[:owner_id] = resp.vpc_endpoints[0][:owner_id]
		vpc_endpoint[:last_error] = resp.vpc_endpoints[0][:last_error]

		return vpc_endpoint 
	end

	def self.get_vpc_endpoints()
		resp = @@ec2.describe_vpc_endpoints()

		vpcs_endpoints = Array.new()

		resp.vpc_endpoints.each do |endpoint|
			vpcs_endpoints << Octaknots::get_vpc_endpoint(endpoint[:vpc_endpoint_id])
		end

		return vpcs_endpoints
	end

	def self.get_instances()
		resp = @@ec2.describe_instances()

		instances = Hash.new()
		resp.reservations.each do |cinstance|
			cinstance.instances.each do |instance|
				if @@exclude_list.kind_of?(Array)
					exclude_instance = @@exclude_list.include?(instance.instance_id)
				else
					exclude_instance = nil
				end
				if !exclude_instance
					if instance.state[:name] == "running" or instance.state[:name] == "stopped"
						instances[instance[:instance_id]] = instance
					end
				end
			end
		end
		return instances
	end

	def self.get_instance(instance_id)
		if instance_id
			instance = @@ec2_instances[instance_id]
		else
			instance = nil
		end
		return instance
	end

	def self.get_instance_name(instance_id)
		instance_name = nil
		if instance_id
			@@ec2_instances[instance_id].tags.each do |tag|
				if tag.key == "Name"
					instance_name = tag.value
				end
			end
			return instance_name
		end
	end

	def self.get_instance_state(instance_id)
		instance_state = nil
		if instance_id
			instance_state = @@ec2_instances[instance_id].state[:name]
		end

		return instance_state 
	end

	def self.get_subnets()
		subnet = Hash.new
		subnets = Array.new
		
		@@ec2.describe_subnets()[:subnets].each do |sub|
			subnet[sub[:subnet_id]]=sub[:subnet_id]
		end 

		subnet.keys.each do |sub|
			subnets << sub
		end
		return subnets
	end

	def self.get_subnet_from_instance(instance_id)
		subnet = nil
		if instance_id
			subnet = @@ec2_instances[instance][:subnet_id]
		end
		return subnet
	end

	def self.get_ssm_status(instance_id)
		if instance_id
			ssm_status = @@ssm.get_connection_status({target: instance_id})
			return ssm_status['status']
		else
			return nil
		end
	end

	def self.get_ssm_notconnected_by_subnet(subnet_id)
		notconnected_by_subnet = Array.new
		@@ec2_instances = Octaknots::get_instances()
		if subnet_id
			@@ec2_instances.keys.each do |instance_id|
				if @@ec2_instances[instance_id].subnet_id == subnet_id
					skip = false
					ssm_status = Octaknots::get_ssm_status(instance_id)
					if ssm_status == 'notconnected' and @@ec2_instances[instance_id].state[:name] == 'running'
						notconnected_by_subnet << instance_id
					end
				end
			end
		end
		return notconnected_by_subnet
	end

	def self.get_amazon_ami()
		images = @@ec2.describe_images(:owners => ['amazon'],filters:
		[
			{ name: 'name', values: ['amzn2-ami-kernel-5.10-hvm-2.0.20220121.0-x86_64-gp2']}
		])

		image_id = images[:images][0].image_id
		return image_id
	end
	
	def self.get_ssh_keyname()
		keys = @@ec2.describe_key_pairs()
		key_name = keys.key_pairs[0].key_name
		return key_name
	end

	def self.get_iam_instance_profile_for_ssm()
		iam_instance_profile = @@iam.get_instance_profile({
			instance_profile_name: 'AmazonSSMRoleForInstancesQuickSetup'
		})

		return iam_instance_profile
	end

	def self.wait_for_running_instance(instance_id)
		if instance_id
			begin
				@@ec2.wait_until(:instance_running, {:instance_ids => [instance_id]})
			rescue
				Octaknots::msg("Unexpected proglem starting instance #{instance_id}", false)
			end
		end
	end

	def self.wait_for_stopped_instance(instance_id)
		if instance_id 
			begin
				@@ec2.wait_until(:instance_stopped, {:instance_ids => [instance_id]})
			rescue
				Octaknots::msg("Unexpected problem stopping instance #{instance_id}", false)
			end
		end
	end

	def self.wait_for_in_use_volume(volume_id)
		if volume_id
			begin
				@@ec2.wait_until(:volume_in_use, {:volume_ids => [volume_id]})
			rescue
				Octaknots::msg("Unexpected problem attaching volume #{volume_id}", false)
			end
		end
	end

	def self.wait_for_available_volume(volume_id)
		if volume_id
			begin
				@@ec2.wait_until(:volume_available, {:volume_ids => [volume_id]})
			rescue
				Octaknots::msg("Unexpected problem detaching volume #{volume_id}", false)
			end
		end
	end

	def self.wait_for_image_available(ami_id)
		if ami_id
			begin
				@@ec2.wait_until(:image_available, {:image_ids => [ami_id]})
			rescue
				Octaknots::msg("Unexpected problem with ami_id #{ami_id}", false)
			end
		end
	end

	def self.get_vpc_cidr(vpc_id)
		if vpc_id
			vpcs = @@ec2.describe_vpcs({vpc_ids: [vpc_id]})
			vpc_cidr = vpcs[:vpcs][0][:cidr_block]
		end
		return vpc_cidr
	end 

	def self.create_knot_instance(subnet)
		if subnet
			knot_instance = @@ec2.run_instances({
				image_id: Octaknots::get_amazon_ami(),
				instance_type: "t2.micro",
				key_name: Octaknots::get_ssh_keyname(),
				max_count: 1,
				min_count: 1,
				subnet_id: subnet,
				iam_instance_profile: {
		   			arn: Octaknots::get_iam_instance_profile_for_ssm()[:instance_profile][:arn]
		  		},

				block_device_mappings: [
					{
						device_name: '/dev/xvda',
						ebs: {
							volume_size: 20,
						}
					}
				],
				tag_specifications: [
				{
					resource_type: 'volume',
					tags: 
					[
						{
							key: "Name",
							value: "SSM_Installer #{subnet}"
						},
						{
							key: "dbi:Application",
							value: "Infra-Security"
						},
						{
							key: "dbi:Creator",
							value: "Jason Miller"
						},
						{
							key: "dbi:Name",
							value: "SSM_Installer #{subnet}"
						},
						{
							key: "dbi:Pod",
							value: "Infrastructure"
						},
						{
							key: "dbi:Team",
							value: "DevOps"
						},
						{
							key: "dbi:StartStop",
							value: "3am-2pm"
						}
					],
				},
				{
					resource_type: 'instance',
					tags: 
					[
						{
						 	key: "Name",
						 	value: "dbi:SSM_Installer #{subnet}"
						 },
						{
							key: "dbi:Application",
							value: "Infra-Security"
						},
						{
							key: "dbi:Creator",
							value: "Jason Miller"
						},
						{
							key: "dbi:Name",
							value: "SSM_Installer #{subnet}"
						},
						{
							key: "dbi:Pod",
							value: "Infrastructure"
						},
						{
							key: "dbi:Team",
							value: "DevOps"
						},
						{
							key: "dbi:StartStop",
							value: "3am-2pm"
						}
					],
				}
			]
		})
		end

		instance_id = knot_instance.instances[0][:instance_id]
		Octaknots::wait_for_running_instance(instance_id)
		max_seconds = 60
		curr_seconds = 0
		while(Octaknots::get_ssm_status(instance_id) == "notconnected" and curr_seconds <= max_seconds)
			Octaknots::msg("Waiting for knot-instance #{instance_id} to connect to SSM. #{curr_seconds} secs",false)
			sleep 1
			curr_seconds += 1
		end

		if Octaknots::get_ssm_status(instance_id) == "connected"
			Octaknots::msg("knot-instance #{instance_id} is ready to execute commands.", false)
		else
			Octaknots::msg("knot-instance #{instance_id} unable to connect to SSM, aborting.", false)
			exit
		end

		return instance_id
	end

	def self.get_knot_instance_by_subnet(subnet)
		knot_instances = nil
		if subnet
			@@ec2_instances.keys.each do |instance|
				@@ec2_instances[instance].tags.each do |tag|
					if tag.key == "dbi:Name" && tag.value == "SSM_Installer #{subnet}" && Octaknots::get_ssm_status(instance) == 'connected'
						if @@ec2_instances[instance][:subnet_id] == subnet
							knot_instances = @@ec2_instances[instance][:instance_id]
						end
					end
				end
			end
		end

		return knot_instances
	end

	def self.verify_knot_instance(subnet)
		if subnet 
			if Octaknots::get_knot_instance_by_subnet(subnet)
				instance = Octaknots::get_knot_instance_by_subnet(subnet)
			else
				instance = Octaknots::create_knot_instance(subnet)
			end
		else
			instance = nil
		end
		return instance
	end

	def self.create_instance(ami_id,subnet_id)

		# Code to spin up a new instance
		if subnet_id and ami_id
			instance = @@ec2.run_instances({
				image_id: ami_id,
				instance_type: "t2.micro",
				key_name: Octaknots::get_ssh_keyname(),
				max_count: 1,
				min_count: 1,
				subnet_id: subnet_id,
				iam_instance_profile: {
		   			arn: Octaknots::get_iam_instance_profile_for_ssm()[:instance_profile][:arn]
		  		},

				block_device_mappings: [
					{
						device_name: '/dev/xvda',
						ebs: {
							volume_size: 20,
						}
					}
				],
				tag_specifications: [
				{
					resource_type: 'volume',
					tags: 
					[
						{
							key: "Name",
							value: "dbi:SSM_Test #{ami_id} - #{subnet_id}"
						},
						{
							key: "dbi:Application",
							value: "Infra-Security"
						},
						{
							key: "dbi:Creator",
							value: "Jason Miller"
						},
						{
							key: "dbi:Name",
							value: "dbi:SSM_Test #{ami_id} - #{subnet_id}"
						},
						{
							key: "dbi:Pod",
							value: "Infrastructure"
						},
						{
							key: "dbi:Team",
							value: "DevOps"
						},
						{
							key: "dbi:StartStop",
							value: "3am-2pm"
						}
					],
				},
				{
					resource_type: 'instance',
					tags: 
					[
						{
						 	key: "Name",
						 	value: "dbi:SSM_Test #{ami_id} - #{subnet_id}"
						 },
						{
							key: "dbi:Application",
							value: "Infra-Security"
						},
						{
							key: "dbi:Creator",
							value: "Jason Miller"
						},
						{
							key: "dbi:Name",
							value: "dbi:SSM_Test #{ami_id} - #{subnet_id}"
						},
						{
							key: "dbi:Pod",
							value: "Infrastructure"
						},
						{
							key: "dbi:Team",
							value: "DevOps"
						},
						{
							key: "dbi:StartStop",
							value: "3am-2pm"
						}
					],
				}
			]
		})
		end
		Octaknots::wait_for_running_instance(instance[:instances][0][:instance_id])
		return instance[:instances][0][:instance_id]
	end

	def self.get_volume(instance_id)
		volume = Hash.new()

		@@ec2_instances = Octaknots::get_instances()

		if instance_id
			@@ec2_instances[instance_id][:block_device_mappings].each do |ebs|
				if ebs[:device_name] == '/dev/sda1'
					volume[:device_name]= ebs[:device_name]
					volume[:volume_id]= ebs[:ebs][:volume_id]
					volume[volume[:volume_id]] = ebs[:ebs]
				end
			end
		end
		return volume
	end

	def self.detach_volume(volume_id)
		if volume_id
			response = @@ec2.detach_volume({
				volume_id: volume_id
			})
			Octaknots::wait_for_available_volume(volume_id)
		else
			response = nil
		end

		return response
	end

	def self.attach_volume(instance_id, volume_id, device)
		if instance_id and volume_id and device
			begin
				response = @@ec2.attach_volume({
					device: device,
					instance_id: instance_id,
					volume_id: volume_id 
				})
			rescue
				Octaknots::msg("Problem attaching volume #{volume_id} to instance #{instance_id} on device #{device}", false)
				response = nil
			end

			Octaknots::wait_for_in_use_volume(volume_id)
		else
			response = nil
		end

		return response
	end

	def self.stop_instance(instance_id)
		if instance_id
			@@ec2.stop_instances(instance_ids: [instance_id])
			Octaknots::wait_for_stopped_instance(instance_id)
		end
	end

	def self.start_instance(instance_id)
		if instance_id
			@@ec2.start_instances(instance_ids: [instance_id])
			Octaknots::wait_for_running_instance(instance_id)
		end
	end

	def self.get_document_content(file_location)
		if File.exists?(file_location)
			file = File.open(file_location)
			file_content = file.read()
		else
			file_content = nil
		end
		return file_content
	end

	# We assume you are using yaml document_format
	def self.create_ssm_command_document(file_location, document_name)
		
		if Octaknots::get_document_content(file_location)
			document_content = Octaknots::get_document_content(file_location)
			doc = @@ssm.create_document({
				content: document_content,
				name: document_name,
				document_type: 'Command',
				document_format: 'YAML'
			})
		else
			doc = nil
			Octaknots::msg("Unable to locate #{file_location}", false)
		end
		return doc
	end

	def self.verify_ssm_command_document(document_name, file_location)
		verified = false
		if document_name
			doc = @@ssm.list_documents({
				document_filter_list: [
					{
						key: "Name",
						value: document_name
					}]
			})

			if !doc[:document_identifiers].empty?()
				full_document = nil
				full_document = @@ssm.get_document({
					name: doc[:document_identifiers][0][:name]
				})

				Octaknots::msg("Located SSM Command Document #{document_name}: #{full_document[:name]}", true)
				verified = true
			else
				Octaknots::msg("Document #{document_name} needs to be added to SSM.", true)
				ssm_document = Octaknots::create_ssm_command_document(file_location, document_name)
				Octaknots::msg("Added Document #{document_name} to SSM.", true)
				verified = true 
			end
		end

		return verified
	end

	def self.wait_until_command_success(command_id, instance_id)
		if command_id and instance_id
			response = @@ssm.list_commands({
				command_id: command_id,
				instance_id: instance_id,
				max_results: 1,
				filters: [
					{
						key: "DocumentName",
						value: "SSMChrootInstall"
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
							value: "SSMChrootInstall"
						}]
					})

				if response.commands[0].status == "Success"
			 		Octaknots::msg("Command executed sucessfully.", true)
			 		break
			 	end
			end

			begin
				document_invo = @@ssm.get_command_invocation({
					command_id: command_id,
					instance_id: instance_id
				})

				Octaknots::msg("Command Output STDERROR: #{document_invo.standard_error_content}", true)
				Octaknots::msg("Command Output STDOUT: #{document_invo.standard_output_content}", true)
			rescue
				Octaknots::msg("Unable To Get Command Invocation for #{command_id} on #{instance_id}", true)
			end
		end
	end			

	def self.run_ssm_command_document(instance_id, document_name)
		response = Hash.new
		if instance_id and document_name

			Octaknots::msg("Running document #{document_name} on instance #{instance_id}.", true)
			response = @@ssm.send_command({
				instance_ids: [instance_id],
				document_name: document_name
			})

		end
		return response[:command][:command_id]
	end

	def self.create_ssm_endpoint_security_group(vpc_id)

		sg = nil
		random_number = Random.rand(1...99999999)

		if vpc_id

			sg = @@ec2.create_security_group({
				description: "dbi:SSM Security Group For VPC #{vpc_id}",
				group_name: "dbi:#{random_number}.#{vpc_id}.com.amazonaws.#{@@region}.ssm",
				vpc_id: vpc_id,
				tag_specifications: [
					{
						resource_type: "security-group",
						tags: [
							{
								key: 'dbi:Application',
								value: "Infra-Security"
							},
							{
								key: 'dbi:Creator',
								value: 'Jason Miller'
							},
							{
								key: 'dbi:Name',
								value: "dbi:security_group:#{random_number}.#{vpc_id}.com.amazonaws.#{@@region}.ssm"
							},
							{
								key: 'Name',
								value: "dbi:security_group:#{random_number}.#{vpc_id}.com.amazonaws.#{@@region}.ssm"
							},
							{
								key: 'dbi:Team',
								value: "DevOps"
							},
							{
								key: 'dbi:Pod',
								value: "Infrastructure"
							}
						]
					}
				]
			})

			resp = @@ec2.authorize_security_group_ingress({
				group_id: sg.group_id,
				ip_permissions: [
					{
						ip_protocol: "TCP",
						from_port: 443,
						to_port: 443,
						ip_ranges: [
							{
								cidr_ip: Octaknots::get_vpc_cidr(vpc_id),
								description: "Allow HTTPS from VPC #{vpc_id}: #{Octaknots::get_vpc_cidr(vpc_id)}"
							}
						]
						
					}
				]
			})
		end

		if sg 
			security_group = sg.group_id 
		else
			security_group = nil
		end

		return security_group

	end

	def self.get_subnets_by_vpc(vpc_id)
		subnet = []
		begin
			subnets = @@ec2.describe_subnets({
				filters: [
					{
						name: "vpc-id",
						values: [ vpc_id ]
					}
				]
			})
		rescue
			Octaknots::msg("Problem Getting VPC Subnets For VPC #{vpc_id}", false)
			subnets = nil
		end

		if subnets
			subnets.subnets.each do |vpc_subnet|
				subnet << vpc_subnet[:subnet_id]
			end
		end

		return subnet
	end

	def self.create_ssm_endpoint(vpc_id)
		security_group = Octaknots::create_ssm_endpoint_security_group(vpc_id)
		subnets = Octaknots::get_subnets_by_vpc(vpc_id)

		begin 
			dns_support = @@ec2.modify_vpc_attribute({
				enable_dns_support: {
					value: true
				},
				vpc_id: vpc_id
			})

			dns_hostname = @@ec2.modify_vpc_attribute({
				enable_dns_hostnames: {
					value: true
				},
				vpc_id: vpc_id
			})
		rescue => error 
			Octaknots::msg("Error: #{error}", false)
		end

		ssm_endpoint = nil

		begin
			ssm_endpoint = @@ec2.create_vpc_endpoint({
				vpc_endpoint_type: "Interface",
				vpc_id: vpc_id,
				service_name: "com.amazonaws.#{@@region}.ssm",
				subnet_ids: subnets,
				security_group_ids: [security_group],
				private_dns_enabled: true,
				tag_specifications: [
					{
						resource_type: "vpc-endpoint",
						tags: [
							{
								key: "Name",
								value: "#{vpc_id}.com.amazonaws.#{@@region}.ssm",
							},
							{
								key: "dbi:Name",
								value: "dbi:vpc_endpoint:#{vpc_id}.com.amazonaws.#{@@region}.ssm",
							},
							{
								key: "dbi:Application",
								value: "Infra-Security",
							},
							{
								key: "dbi:Creator",
								value: "Jason Miller"
							},
							{
								key: "dbi:Team",
								value: "DevOps"
							},
						]
					}
				]
			})

		rescue => error
			Octaknots::msg("Problem Creating SSM Endpoint For VPC #{vpc_id}.", false)
			Octaknots::msg("ERROR: #{error}", false)
		end

		if ssm_endpoint
			vpc_endpoint = Octaknots::get_vpc_endpoint(ssm_endpoint.vpc_endpoint.vpc_endpoint_id)
		else
			Octaknots::msg("No SSM Endpoint Enabled.", false)
		end

		return vpc_endpoint 
	end

	def self.get_vpc_from_endpoint(vpc_endpoint_id)
		endpoint = Octaknots::get_vpc_endpoint(vpc_endpoint_id)

		if endpoint
			vpc_id = endpoint[:vpc_id]
		else
			vpc_id = nil
		end

		return vpc_id
	end

	def self.get_security_group_from_endpoint(vpc_endpoint_id)
		endpoint = Octaknots::get_vpc_endpoint(vpc_endpoint_id)

		if endpoint[:groups].kind_of(Array)
			security_group = endpoint[:groups][0][:group_id]
		else
			security_group = nil
		end

		return security_group
	end

	def self.parse_arguments()
		@@options = Parser.parse(ARGV)
	end

	def self.wait_for_ssm(instance_id)

		current_seconds = 0
		max_seconds = 60

		while ( Octaknots::get_ssm_status(instance_id) == "notconnected" and current_seconds <= max_seconds )
			Octaknots::msg("#{instance_id} not connected. #{current_seconds} secs", true)
			current_seconds += 1
			sleep 1
		end

		if Octaknots::get_ssm_status(instance_id) == "connected"
			Octaknots::msg("#{instance_id} connected.", true)
		else
			Octaknots::msg("#{instance_id} is unable to connect to SSM.", false)
		end

	end

	def self.get_instance_subnet(instance_id)

		subnet = nil 

		if @@ec2_instances[instance_id][:subnet_id]
			subnet = @@ec2_instances[instance_id][:subnet_id]
		end

		return subnet 
	end


	def self.get_autoscale_instances_by_subnet(subnet)

		autoscale_groups = @@ec2_autoscale.describe_auto_scaling_groups()

		autoscale_instances = []

		autoscale_groups.auto_scaling_groups.each do |auto|
			auto.instances.each do |instance|
				
				if subnet == Octaknots::get_instance_subnet(instance.instance_id)
					autoscale_instances << instance.instance_id
				end

			end
		end

		return autoscale_instances

	end

	def self.get_autoscale_instances()

		autoscale_groups = @@ec2_autoscale.describe_auto_scaling_groups()

		autoscale_instances = []

		autoscale_groups.auto_scaling_groups.each do |auto|
			auto.instances.each do|instance|
				
				autoscale_instances << instance.instance_id
	
			end
		end

		return autoscale_instances
	end

	def self.is_autoscale_instance?(instance_id)

		autoscale_instances = Octaknots::get_autoscale_instances()
		autoscale = false

		if instance_id and !autoscale_instances.empty?()
			if autoscale_instances.include?(instance_id)
				autoscale = true
			else
				autoscale = false
			end
		end

		return autoscale

	end

	def self.get_autoscale_groups()
		autoscale_groups = @@ec2_autoscale.describe_auto_scaling_groups()
		groups = []

		autoscale_groups.auto_scaling_groups.each do |auto|
			groups << auto.auto_scaling_group_name
		end

		return groups 
	end

	def initialize()
		Octaknots::parse_arguments()

		if @@options[:region]
			@@region = @@options[:region]
		else
			@@region = 'us-east-1'
		end

		if @@options[:profile]
			@@profile = @@options[:profile]
		else
			@@profile = 'default'
		end

		@@exclude_list = @@options[:exclude]

		@@verbose = @@options[:verbose]

		@@test_instance = @@options[:test_instance]

		@@enable_endpoints = @@options[:enable_endpoints]

		if @@options[:dryrun]
			@@dryrun = @@options[:dryrun]
		else
			@@dryrun = false
		end

		@@ec2 = Aws::EC2::Client.new(
			region: @@region,
			profile: @@profile
		)

		@@ssm = Aws::SSM::Client.new(
			region: @@region,
			profile: @@profile
		)

		@@iam = Aws::IAM::Client.new (
			{
				region: @@region,
				profile: @@profile
			}
		)

		@@ec2_autoscale = Aws::AutoScaling::Client.new (
			{
				region: @@region,
				profile: @@profile
			}
		)

		@@ec2_instances = Octaknots::get_instances()
		
	end
end

