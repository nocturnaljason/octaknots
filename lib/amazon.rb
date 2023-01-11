require 'aws-sdk'

class Amazon

	def initialize(profile='default',region='us-east-1')

		@ec2_client = Aws::EC2::Client.new({
			profile: profile,
			region: region
		})

		@ssm_client = Aws::SSM::Client.new({
			profile: profile,
			region: region
		})

		@autoscaling_client = Aws::AutoScaling::Client.new({
			profile: profile,
			region: region
		})

		@iam_client = Aws::IAM::Client.new({
			profile: profile,
			region: region
		})

	end

	def get_vpcs()
		vpcs = []

		response = @ec2_client.describe_vpcs()

		response.vpcs.each do |vpc|

			vpcs << vpc

		end

		return vpcs
	end

	def get_vpc_subnets(vpc_id)

		response = @ec2_client.describe_subnets(
		{
			filters: [
				{
					name: 'vpc-id',
					values: [ vpc_id ]
				}]
		})

		subnets = response.subnets

		return subnets

	end

	def get_ec2_instances(options={})

		instances = []

		if options[:without_ssm]

			response = @ec2_client.describe_instances({})

			response.reservations.each do |reservation|

				reservation.instances.each do |instance|

					ssm_status = @ssm_client.get_connection_status({target: instance.instance_id})

					if ssm_status['status'] == 'notconnected' and instance.state.name == "running"
						instances += [instance]
					end

				end

			end

		end

		if options[:with_ssm]
			
			response = @ec2_client.describe_instances({})

			response.reservations.each do |reservation|

				reservation.instances.each do |instance|

					ssm_status = @ssm_client.get_connection_status({target: instance.instance_id})

					if ssm_status['status'] == 'connected'
						instances += [instance]
					end

				end

			end

		end

		if !options[:ssm_only] and !options[:without_ssm]
			response = @ec2_client.describe_instances({})

			response.reservations.each do |reservation|

				reservation.instances.each do |instance|

					if instance.state.name == "running"
						instances += [instance]
					end

				end

			end

		end

		return instances
	
	end

	def get_ssm_status(instance_id)

		ssm_status = @ssm_client.get_connection_status({target: instance_id})

		return ssm_status['status']

	end

	def get_iam_profile(instance_id)

		return 'unknown'
	end

	def autoscaling_instance?(instance_id)

		autoscale = false

		response = @autoscaling_client.describe_auto_scaling_instances({
			instance_ids: [instance_id]
		})

		unless response.auto_scaling_instances.empty?()

			if response.auto_scaling_instances[0].instance_id == instance_id
				autoscale = true
			end

		end
	
		return autoscale
	end

	def stop_instance(instance_id)

		status = false 
		skip = false
		begin
			response = @ec2_client.stop_instances({
				instance_ids: [instance_id]
			})
		rescue => e
			puts e
			skip = true
		end

		begin
			unless skip
				@ec2_client.wait_until(:instance_stopped, {:instance_ids => [instance_id]})
				status = true
			end 
		rescue => e
			puts e 
		end

		return status

	end

	def start_instance(instance_id)

		status = false
		skip = false 
		begin
			response = @ec2_client.start_instances({
				instance_ids: [instance_id]
			})
		rescue => e
			puts e
			skip = true
		end

		begin
			unless skip
				@ec2_client.wait_until(:instance_running, {:instance_ids => [instance_id]})
				status = true 
			end
		rescue => e
			puts e 
		end

		return status
		
	end

	def get_ssh_key_name(instance_id)

		instance = self.get_instance(instance_id)

		return instance.key_name

	end

	def get_subnet(instance_id)

		instance = self.get_instance(instance_id)

		return instance.subnet_id

	end

	def get_instance(instance_id)
		response = @ec2_client.describe_instances({
			instance_ids: [instance_id]
		})

		unless response.reservations.empty?

			instance = response.reservations[0].instances[0]

		else
			instance = nil

		end

		return instance
	
	end

	def get_iam_instance_profile_for_ssm
		
		iam_instance_profile = @iam_client.get_instance_profile({
			instance_profile_name: 'AmazonSSMRoleForInstancesQuickSetup'
		})

		return iam_instance_profile
	end

	def add_startstop_tag(instance_id,startstop_time)

	end

	def remove_startstop_tag(instance_id)

		status = false

		begin
			instance = self.get_instance(instance_id)
		rescue => e
			puts e
		end

		instance.tags.each do |tag|

			if tag.key == "dbi:StartStop"

				begin
					@ec2_client.delete_tags({
						resources: [instance_id],
						tags: [
							{
								key: tag.key,
								value: tag.value
							}]
					})

					status = true
				rescue => e
					puts e
				end

			end

		end

		return status
	
	end


	def knot_instance(instance_id)

		knot_instance = @ec2_client.run_instances({
				image_id: self.get_amazon_ami(),
				instance_type: "t2.micro",
				key_name: self.get_ssh_key_name(instance_id),
				max_count: 1,
				min_count: 1,
				subnet_id: self.get_subnet(instance_id),
				iam_instance_profile: {
		   			arn: self.get_iam_instance_profile_for_ssm()[:instance_profile][:arn]
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
							value: "Knot #{self.get_subnet(instance_id)}"
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
							value: "Knot #{self.get_subnet(instance_id)}"
						},
						{
							key: "dbi:Pod",
							value: "Infrastructure"
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
						 	value: "Knot #{self.get_subnet(instance_id)}"
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
							value: "Knot #{self.get_subnet(instance_id)}"
						},
						{
							key: "dbi:Pod",
							value: "Infrastructure"
						},
						{
							key: "dbi:StartStop",
							value: "3am-2pm"
						}
					],
				}
			]
		})

		instance_id = knot_instance.instances[0][:instance_id]
		
		self.remove_startstop_tag(instance_id)

		max_seconds = 60
		curr_seconds = 0

		while(self.get_ssm_status(instance_id) == "notconnected" and curr_seconds <= max_seconds)
			sleep 1
			curr_seconds += 1
		end

		unless self.get_ssm_status(instance_id) == "connected"
			instance_id = nil
			self.terminate_instance(instance_id)
		end

		return instance_id
	end

	def tie(instance_id, knot_instance)

	end

	def chroot_ssm_install(knot_instance)

	end

	def untie(knot_instance, instance_id)

	end

	def wait_for_ssm_connected(instance_id)

	end

	def terminate_instance(instance_id)

		status = false 

		begin
			response = @ec2_client.terminate_instances({
					instance_ids: [instance_id]
				})

			status = true
		rescue => e
			puts e
		end

		return status

	end

	def vpc_has_instances?(vpc_id)

		instances = self.get_ec2_instances()

		has_instances = false 
		
		instances.each do |instance|

			if instance.vpc_id == vpc_id 

				has_instances = true

			end
		end

		return has_instances

	end

	def validate_dns_resolution(vpc_id)

		status = false

		begin 
			response = @ec2_client.describe_vpc_attribute({
				attribute: "enableDnsSupport",
				vpc_id: vpc_id
			})
		rescue => e
			puts e
		end

		if response.enable_dns_support.value
			status = true
		end

		return status

	end

	def fix_dns_resolution(vpc_id)

		status = false

		unless self.validate_dns_resolution(vpc_id)

			begin
				response = @ec2_client.modify_vpc_attribute(
				{
					enable_dns_support: {
						value: true
					},
					vpc_id: vpc_id
				})

				status = true
			rescue => e
				puts e 
			end

		else
			status = true
		end

		return status

	end

	def vpc_has_ssm_endpoint?(vpc_id)

		status = false

		response = @ec2_client.describe_vpc_endpoints({})

		unless response.vpc_endpoints.empty?
			response.vpc_endpoints.each do |vpc_endpoint|
				if vpc_endpoint.vpc_id == vpc_id

					if vpc_endpoint.service_name =~ /com\.amazonaws\.(.*)\.ssm/
						status = true
					end

				end
			end
		end

		return status

	end

	def get_instance_name(instance_id)

		name = "-"

		instance = self.get_instance(instance_id)

		instance.tags.each do |tag|
			if tag.key == 'Name'
				name = tag.value
			end
		end

		return name
	
	end

	def add_ssm_endpoint(vpc_id)

	end

	def iam_profile_contains_ssm?(instance_id)

	end

	def iam_profile_add_ssm(instance_id)

	end

	def security_group_allows_outbound(instance_id)

		return true
	end

	def get_amazon_ami

		begin 
			images = @ec2_client.describe_images(:owners => ['amazon'],filters:
			[
				{ name: 'name', values: ['amzn2-ami-kernel-5.10-hvm-2.0.20220121.0-x86_64-gp2']}
			])
		rescue => e
			puts e
		end	

		image_id = images[:images][0].image_id
		
		return image_id

	end

end