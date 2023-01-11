require 'net/ssh'
require 'find'

class SSH

	def initialize(debug = false)

		@host = 'localhost'
		@users = []
		@ssh_keys = []
		@debug = debug
	
	end

	def self.setup_ssh_keys(key)

		ssh_keys = Array.new()

		ssh_keys += [File.join(ENV['HOME'],'.ssh/id_rsa')]

		Find.find(File.join(ENV['HOME'], '.ssh')) do |path|

			if path =~ /.*\.pem$/

				if path.include?(key)
					ssh_keys << path
				end
			end
		end

		return ssh_keys
	end

	def have_private_key(key)

		status = false

		Find.find(File.join(ENV['HOME'], '.ssh')) do |path|

			if path =~ /.*\.pem$/

				if path.include?(key)
					status = true
				end
			end
		end

		return status
	
	end


	def setup_ssh_parameters(host, users)

		@host = host

		if users.is_a?(Array)

			@users = users

		end

	end


	def deploy_ssm(key_name)

		installed = false

	 	@users.each do |user|

	 		os = 'unknown'

	 		begin
	 			Net::SSH.start(@host, user, { keys: SSH::setup_ssh_keys(key_name), password_prompt: 0, timeout: 2 }) do |ssh|

	 				ssh.exec!("/bin/cat /etc/os-release") do |ch, stream, data|
	 					if stream == :stdout && /ID=ubuntu/.match(data)
	 						os = "ubuntu"

	 					elsif stream== :stdout && /ID="amzn"/.match(data)
	 						os = "amazon"
	 					else
	 						os = "other"
	 					end
	 				end

	 				case os
	 				when 'ubuntu'

	 					# Remove the snap version cause it doesn't work exactly the same as the deb package
	 					ssh.exec!('sudo snap remove amazon-ssm-agent') do |ch, stream, data|
	 						if stream == :stdout
	 						end

	 						if stream == :stderr
	 						end
	 					end

	 					ssh.exec!("cd /tmp; wget --quiet 'https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb'") do |ch, stream, data|
	 						if stream == :stdout
	 						end

	 						if stream == :stderr
	 						end
	 					end

	 					ssh.exec!("sudo /usr/bin/dpkg -i /tmp/amazon-ssm-agent.deb") do |ch, stream, data|
	 						if stream == :stdout 
	 						end

	 						if stream == :stderr
	 						end
	 					end

	 					ssh.exec!("sudo systemctl enable amazon-ssm-agent") do |ch, stream, data|
	 						if stream == :stdout
	 						end

	 						if stream == :stderr 
	 						end
	 					end

	 				when 'amazon', 'other'
	 					
	 					# We do this just in case there is a version installed by SSM isn't connecting for some reason
	 					ssh.exec!('sudo yum remove -y amazon-ssm-agent') do |ch, stream, data|
	 						if stream == :stdout
	 							
	 						end

	 						if stream == :stderr
	 							
	 						end
	 					end

	 					ssh.exec!('sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm') do |ch, stream, data|
	 						if stream == :stdout
	 			
	 						end

	 						if stream == :stderr
	 						end
	 					end

	 					ssh.exec!('sudo systemctl enable amazon-ssm-agent') do |ch, stream, data|
	 						if stream == :stdout
	 						end

	 						if stream == :stderr
	 						end
	 					end

	 				end
	 				installed = true

	 			end
	 		rescue => e
	 			puts "    " + e.to_s
	 		end
	
	 	end

	 	return installed

	end


end


