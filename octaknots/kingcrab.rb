require 'aws-sdk'
require 'colorize'

class EC2

	attr_accessor :client

	attr_reader   :reservations
	attr_reader   :security_groups
	attr_reader   :vpn_gateways
	attr_reader   :vpn_connections
	attr_reader   :vpc_endpoints
	attr_reader   :vpcs
	attr_reader   :vpc_peering_connections
	attr_reader   :volumes
	attr_reader   :snapshots
	attr_reader   :subnets 
	attr_reader   :route_tables
	attr_reader   :regions
	attr_reader   :network_interfaces
	attr_reader   :network_acls
	attr_reader   :key_pairs
	attr_reader   :instance_types
	attr_reader   :internet_gateways
	attr_reader   :dhcp_options
	attr_reader   :nat_gateways
	attr_reader   :customer_gateways
	attr_reader   :client_vpn_endpoints
	attr_reader   :client_vpn_connections
	attr_reader   :client_vpn_routes
	attr_reader   :client_vpn_target_networks
	attr_reader   :launch_templates
	attr_reader   :local_gateways
	attr_reader   :reserved_instances
	attr_reader   :transit_gateway_attachments
	attr_reader   :transit_gateway_multicast_domains
	attr_reader   :transit_gateway_peering_attachments
	attr_reader   :transit_gateway_route_tables
	attr_reader   :transit_gateway_vpc_attachments
	attr_reader   :transit_gateways

	def populate()

		#puts @client.inspect 

		if @client.is_a?(Aws::EC2::Client)

			@reservations = @client.describe_instances()
			@security_groups = @client.describe_security_groups()
			@vpcs = @client.describe_vpcs()
			@vpn_connections = @client.describe_vpn_connections()
			@vpn_gateways = @client.describe_vpn_gateways()
			@vpc_peering_connections = @client.describe_vpc_peering_connections()
			@volumes = @client.describe_volumes()
			@snapshots = @client.describe_snapshots({ owner_ids: ["self"] })
			@subnets = @client.describe_subnets()
			@vpc_endpoints = @client.describe_vpc_endpoints()
			@route_tables = @client.describe_route_tables()
			@regions = @client.describe_regions()
			@network_interfaces = @client.describe_network_interfaces()
			@network_acls = @client.describe_network_acls()
			@key_pairs = @client.describe_key_pairs()
			@instance_types = @client.describe_instance_types()
			@internet_gateways = @client.describe_internet_gateways()
			@dhcp_options = @client.describe_dhcp_options()
			@nat_gateways = @client.describe_nat_gateways()
			@customer_gateways = @client.describe_customer_gateways()
			@client_vpn_endpoints = @client.describe_client_vpn_endpoints()
			@launch_templates = @client.describe_launch_templates()
			@local_gateways = @client.describe_local_gateways()
			@reserved_instances = @client.describe_reserved_instances()
			@transit_gateway_attachments = @client.describe_transit_gateway_attachments()
			@transit_gateway_multicast_domains = @client.describe_transit_gateway_multicast_domains()
			@transit_gateway_peering_attachments = @client.describe_transit_gateway_peering_attachments()
			@transit_gateway_route_tables = @client.describe_transit_gateway_route_tables()
			@transit_gateway_vpc_attachments = @client.describe_transit_gateway_vpc_attachments()
			@transit_gateways = @client.describe_transit_gateways()

		end

	end

	def initialize(ec2_client)

		if ec2_client.is_a?(Aws::EC2::Client)

			@client = ec2_client

		end

		self.populate()

	end

end

class ECR

	attr_accessor :client

	attr_reader   :images
	attr_reader   :repositories


	def populate()

		if @client.is_a?(Aws::ECR::Client)

			@images = Hash.new()

			@repositories = @client.describe_repositories({})

			begin 
				if @repositories.repositories.is_a?(Array)

					@repositories.repositories.each do |repo|

						@images[repo.repository_name] = @client.describe_images({
							repository_name: repo.repository_name
						})

					end

				end
			rescue
				# We should need anything but to capture the error

			end

		end

	end

	def initialize(ecr_client)

		if ecr_client.is_a?(Aws::ECR::Client)

			@client = ecr_client

		end

		self.populate()

	end

end

class ECS
	
	attr_accessor :client

	attr_reader :clusters

	def populate()

		@clusters = @client.list_clusters()

	end

	def initialize(ecs_client)

		if ecs_client.is_a?(Aws::ECS::Client)

			@client = ecs_client

		end

		self.populate()

	end

end


class Kingcrab

	attr_accessor :region
	attr_accessor :profile
	attr_reader   :ec2_client
	attr_reader   :ec2
	attr_reader   :ecr_client
	attr_reader   :ecr
	attr_reader   :ecs_client
	attr_reader   :ecs
	
	def initialize()

		@region = "us-east-1"
		@profile = "default"

		@ec2_client = Aws::EC2::Client.new (
		{
			region: @region,
			profile: @profile
		})

		@ecr_client = Aws::ECR::Client.new (
		{
			region: @region,
			profile: @profile
		})

		@ecs_client = Aws::ECS::Client.new (
		{
			region: @region,
			profile: @profile
		})


		@ec2 = EC2.new(@ec2_client)

		@ecr = ECR.new(@ecr_client)

		@ecs = ECS.new(@ecs_client)
	end

	def update_client()

		if @region.is_a?(String) and @profile.is_a?(String)

			@ec2_client = Aws::EC2::Client.new (
			{
				region: @region,
				profile: @profile
			})

			@ecr_client = Aws::ECR::Client.new (
			{
				region: @region,
				profile: @profile
			})

			@ecs_client = Aws::ECS::Client.new (
			{
				region: @region,
				profile: @profile
			})

			@ec2 = EC2.new(@ec2_client)

			@ecr = ECR.new(@ecr_client)

			@ecs = ECS.new(@ecs_client)

		end

	end

	def print_totals()

		if @ec2.is_a?(EC2)

			begin 
				account_id = @ec2.reservations.reservations[0].owner_id
			rescue
				account_id = "not available"
			end

			puts " Account: #{account_id}".colorize(:blue)
			puts ""
			puts "[ EC2 ]".colorize(:green)
			puts "  vpcs:                        #{@ec2.vpcs.vpcs.size}"
			puts "  vpc_peering_connections:     #{@ec2.vpc_peering_connections.vpc_peering_connections.size}"
			puts "  vpc_endpoints:               #{@ec2.vpc_endpoints.vpc_endpoints.size}"
			puts "  client_vpn_endpoints:        #{@ec2.client_vpn_endpoints.client_vpn_endpoints.size}"
			puts "  vpn_connections:             #{@ec2.vpn_connections.vpn_connections.size}"
			puts "  vpn_gateways:                #{@ec2.vpn_gateways.vpn_gateways.size}"
			puts "  nat_gateways:                #{@ec2.nat_gateways.nat_gateways.size}"
			puts "  customer_gateways:           #{@ec2.customer_gateways.customer_gateways.size}"
			puts "  local_gateways:              #{@ec2.local_gateways.local_gateways.size}"
			puts "  internet_gateways:           #{@ec2.internet_gateways.internet_gateways.size}"
			puts "  transit_gateways:            #{@ec2.transit_gateways.transit_gateways.size}"

			count = 0 

			@ec2.reservations.reservations.each do |reservation|
				count += reservation.instances.size
			end

			num_instances = count 

			puts "  instances:                   #{num_instances}"
			puts "  reserved_instances:          #{@ec2.reserved_instances.reserved_instances.size}"
			puts "  launch_templates:            #{@ec2.launch_templates.launch_templates.size}"
			puts "  volumes:                     #{@ec2.volumes.volumes.size}"
			puts "  snapshots:                   #{@ec2.snapshots.snapshots.size}"
			puts "  security_groups:             #{@ec2.security_groups.security_groups.size}"
			puts "  subnets:                     #{@ec2.subnets.subnets.size}"
			puts "  route_tables:                #{@ec2.route_tables.route_tables.size}"
			puts "  network_acls:                #{@ec2.network_acls.network_acls.size}"
			puts "  network_interfaces:          #{@ec2.network_interfaces.network_interfaces.size}"
			puts "  regions:                     #{@ec2.regions.regions.size}"
			puts "  key_pairs:                   #{@ec2.key_pairs.key_pairs.size}"
			puts "  instance_types:              #{@ec2.instance_types.instance_types.size}"
			puts "  dhcp_options:                #{@ec2.dhcp_options.dhcp_options.size}"
			puts 

		end

		if @ecr.is_a?(ECR)

			puts "[ ECR ]".colorize(:green)
			puts "  repositories: #{@ecr.repositories.repositories.size}"
			puts

			@ecr.repositories.repositories.each do |repo|

				puts "  $| #{repo.repository_name}".colorize(:yellow)
				puts "      repository_arn:  #{repo.repository_arn}"
				puts "      repository_uri:  #{repo.repository_uri}"
				puts "      encryption_type: #{repo.encryption_configuration.encryption_type}"
				puts "      created_at:      #{repo.created_at}"

				if @ecr.images[repo.repository_name]
					puts "      images:          #{@ecr.images[repo.repository_name].image_details.size}"

					@ecr.images[repo.repository_name].image_details.each do |image|
						puts "         {: #{image.image_digest}".colorize(:yellow)
						puts "             artifact_media_type: #{image.artifact_media_type}"
						puts "             manifest_media_type: #{image.image_manifest_media_type}"
						puts "             size_in_bytes:       #{image.image_size_in_bytes}"
						puts "             pushed_at:           #{image.image_pushed_at}"
						puts "         :}".colorize(:yellow)

					end

				end

				puts
			
			end

			puts

		end


		if @ecs.is_a?(ECS)

			puts "[ ECS ]".colorize(:green)
			puts "  clusters: #{@ecs.clusters.cluster_arns.size}"
			puts

			@ecs.clusters.cluster_arns.each do |cluster|

				container_instances = @ecs_client.list_container_instances ({
					cluster: cluster
				})

				services = @ecs_client.list_services({
					cluster: cluster
				})

				tasks = @ecs_client.list_tasks({
					cluster: cluster
				})

				puts "  @| #{cluster}".colorize(:yellow)
				puts "    container_instances : #{container_instances.container_instance_arns.size}"
				puts "    services            : #{services.service_arns.size}"
				puts "    tasks               : #{tasks.task_arns.size}"
				puts ""

			end

		end

	end 

end


