require_relative 'amazon'
require 'bundler/setup'
require 'socket'
require 'tty-progressbar'
require_relative 'ssh'
require 'time'
require 'orcasecurity'
require 'logger'


class Snapper

	def initialize
		@arguments = {}
		@debug = false

		@ssh_private = []
		@ssh_public = []

		@rdp_private = []
	end

	def console_output(message)

		puts message

	end

	def console_debug(message)

		if @debug
			puts message
		end

	end


	def arguments(args)

		if args.is_a?(Hash)

			@arguments = args

		end

	end

	def snap(instance_id)

		status = false

		self.console_output('    Provisioning KNOT')

		begin
			knot_instance = @amazon.knot_instance(instance_id)
		rescue => e
			console_output('    ' + e.to_s)
		end

		if knot_instance

			begin
			
				

			rescue => e
				self.console_output('     ' + e.to_s)
			end

			begin
				self.console_output('     Executing SSM document on KNOT to install via chroot')
			rescue => e
				self.console_output('     ' + e.to_s)
			end

			begin
				
			rescue => e
				self.console_output('     ' + e.to_s)
			end

			begin
				@amazon.terminate_instance(knot_instance)
				self.console_output("    KNOT terminated")

			rescue => e
				self.console_output('     ' + e.to_s)
			end

			status = true
		else
			self.console_output("    Knot unavailable (aborting)")
		end

		return status 

	end


	def scan

		status = false 

		begin
			self.console_debug('')
			self.console_debug("Retrieving list of EC2 instances...")
			ec2_instances = @amazon.get_ec2_instances({})
		rescue => e
			self.console_output("error : " + e)
			return status
		end

		self.console_output('')

		if ec2_instances.size == 0

			self.console_output('No instances to scan')

		else

			self.console_output('Scanning tcp ports')
			self.console_output('=' * 80)

		end

		ec2_instances.each do |instance|

			begin
				s_private = Socket.tcp(instance.private_ip_address, 22, connect_timeout: 1)
				s_private.close 
				ssh_private_port = 'open'

				@ssh_private << instance

			rescue => e
				ssh_private_port = "closed"
				self.console_debug('private_ip : ' + instance.private_ip_address + ' tcp port 22 (' + e.to_s + ')')
			end

			self.console_output(
				instance.instance_id.to_s.ljust(16) + " : " +
				instance.private_ip_address.to_s.ljust(14) + " : " +
				'tcp port 22 is ' +  ssh_private_port
			)

			if instance.public_ip_address

				begin
					s_public = Socket.tcp(instance.public_ip_address, 22, connect_timeout: 1)
					s_public.close

					ssh_public_port = 'open'

					@ssh_public << instance

				rescue => e

					ssh_public_port = 'closed'
					self.console_debug('public_ip : ' + instance.public_ip_address + ' tcp port 22 (' + e.to_s + ')')
				end

				self.console_output(
					instance.instance_id.to_s.ljust(16) + " : " +
					instance.public_ip_address.to_s.ljust(14) + " : " +
					'tcp port 22 is ' +  ssh_public_port
				)

			end

			begin
				rdp = Socket.tcp(instance.private_ip_address, 3389, connect_timeout: 1)
				rdp.close
				rdp_private_port = 'open' 

				@rdp_private << instance
			rescue
				rdp_private_port = 'closed'
				self.console_debug('private_ip : ' + instance.private_ip_address + ' tcp port 3389 (' + e.to_s + ')')
			end

			self.console_output(
				instance.instance_id.to_s.ljust(16) + " : " +
				instance.private_ip_address.to_s.ljust(14) + " : " +
				'tcp port 3389 is ' +  rdp_private_port
			)
		end

		self.console_output('')

		status = true

		return status 
		
	end

	def process_environment

		vpcs = @amazon.get_vpcs()

		self.console_output('')

		self.console_output("Process VPC")
		self.console_output("=" * 80)

		vpcs.each do |vpc|

			self.console_output(vpc.vpc_id.to_s)
			self.console_output('')

			if @amazon.validate_dns_resolution(vpc.vpc_id)

				self.console_output("    DNS support enabled")

			else

				self.console_output("    DNS support not enabled")

				self.console_output("    Attempting to enable DNS support")

				if @amazon.fix_dns_resolution(vpc.vpc_id)

					self.console_output("    DNS support now enabled")

				else

					self.console_output("    Failed to enable DNS support")

				end

			end

			if @amazon.vpc_has_ssm_endpoint?(vpc.vpc_id)

				self.console_output("    SSM vpc endpoint in-use")

			else

				self.console_output("    SSM vpc endpoint not available")
				self.console_output("    Attempting to enable SSM vpc endpoint")

				if @amazon.add_ssm_endpoint(vpc.vpc_id)

					self.console_output("    SSM vpc endpoint added succesfully")

				else

					self.console_output("    SSM vpc endpoint attempt failed")

				end

			end

			self.console_output('')

			self.console_output("    CIDR         : " + vpc.cidr_block)
			self.console_output("    DHCP Options : " + vpc.dhcp_options_id)
			self.console_output("    Default VPC  : " + vpc.is_default.to_s)

			subnets = @amazon.get_vpc_subnets(vpc.vpc_id)

			vpc_subnets = ""

			subnets.each do |subnet|
				vpc_subnets = vpc_subnets + subnet.subnet_id + " "
			end

			self.console_output("    Subnets      : " + vpc_subnets)
			self.console_output('')

		end

		instances = @amazon.get_ec2_instances()

		self.console_output('Process Instances (running)')
		self.console_output('=' * 80)

		if instances.empty?()

			self.console_output('No running instances found')

		end

		instances.each do |instance|

			self.console_output(instance.instance_id.to_s + ' ( ' + @amazon.get_instance_name(instance.instance_id) + ' )')
			self.console_output('')

			if @amazon.get_ssm_status(instance.instance_id) == 'notconnected'
				self.console_output('     Not connected to SSM')
				self.console_output('')
				self.console_output('     Provisioning Knot instance')
				knot_instance = @amazon.knot_instance(instance.instance_id)

				if knot_instance and @amazon.get_ssm_status(instance.instance_id) == 'notconnected'
					
					self.console_output('     Knot instance : ' + knot_instance)

					self.console_output('     Stopping instance')
					@amazon.stop_instance(instance.instance_id)

					root_volume = @amazon.get_root_volume(instance.instance_id)

					if root_volume and root_volume.is_a?(Hash)

						detach = @amazon.detach_volume(root_volume[:volume_id])

						if detach

							if root_volume[:device_name] == '/dev/sda1'

								source_device = '/dev/sda1'
								mount_device = '/dev/xvdf1'

							elsif root_volume[:device_name] == '/dev/xvda'

								source_device = '/dev/xvda'
								mount_device = '/dev/xvdf'

							end

							attach = @amazon.attach_volume(knot_instance, root_volume[:volume_id], '/dev/xvdf')

							if attach

								ssm_executed = @amazon.ssm_chroot_install(mount_device)

								if ssm_executed

									@amazon.wait_for_ssm(instance.instance_id)

								else

									self.console_output('      Command failed ( chroot_install )')

									detach = @amazon.detach_volume(root_volume[:device_name])

									if detach

										attach = @amazon.attach_volume(instance.instance_id, root_volume[:volume_id], source_device)

										if attach

											self.console_output('     ' + root_volume[:volume_id] + ' attached to instance at ' + source_device)
										
										else
										
											self.console_output('     ' + root_volume[:volume_id] + ' not attached to instance')

										end

									else

										self.console_output

									end

								end

							end

						end
					end

					self.console_output('     Starting instance')
					@amazon.start_instance(instance.instance_id)

				else

					self.console_output('      Knot unavailable')

				end

				self.console_output('')
			
			else

				self.console_output('     Connected to SSM')
				self.console_output('')
			end

			self.console_output('     AMI               : ' + instance.image_id)
			self.console_output('     Instance Type     : ' + instance.instance_type)
			self.console_output('     Instance Profile  : ' + instance.iam_instance_profile.arn)
			self.console_output('     Hypervisor        : ' + instance.hypervisor)
			self.console_output('     Private IP        : ' + instance.private_ip_address)
			self.console_output('     Public IP         : ' + instance.public_ip_address)
			self.console_output('     Subnet            : ' + instance.subnet_id)
			self.console_output('     Security Group(s) : ')

			instance.security_groups.each do |security_group|
				self.console_output('                         ' + 'Name : ' + security_group.group_name)
				self.console_output('                         ' + 'ID   : ' + security_group.group_id)
				self.console_output('')
			end

			

			self.console_output('     Tags              : ')
			
			instance.tags.each do |tag|

				self.console_output('                         ' + 'Key   : ' + tag.key)
				self.console_output('                         ' + 'Value : ' + tag.value)
				self.console_output('')

			end

			self.console_output('')
		end

	end





	def execute(mode='all')

		self.console_output("Start Time: " + Time.now().to_s)

		if @arguments.is_a?(Hash)

			if @arguments[:profile]

				profile = @arguments[:profile]

			else

				profile = 'default'

			end

			if @arguments[:region]

				region = @arguments[:region]

			else

				region = 'us-east-1'

			end

			if @arguments[:debug]

				self.console_output("++ Debug Mode ++")
				@debug = true

			end

		end

		self.console_output('')
		self.console_output("AWS Profile : " + profile)
		self.console_output("AWS Region  : " + region)

		@amazon = Amazon.new(profile, region)

		# self.scan()

		self.process_environment()

		puts "End Time: " + Time.now().to_s
	end
end