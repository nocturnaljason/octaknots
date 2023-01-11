# Require rest-client, yaml, and json gems to use later
require 'rest-client'
require 'yaml'
require 'json'

# Defines the class Orca used for communicating with the orca security api for vulnerability alerts 
class Orca

	# Login to the rest api and return the cookie we got back to make further rest calls
	def self.login()

		# Start with an empty cookies variable
		cookies = nil 

		# Verify we got the type of object we expect or return nil
		if @@configuration.kind_of?(Hash)
			
			# Get the secretkey to login to the rest api with
			if @@configuration['orca_secretkey']

				# Make a post request to generate the authentication cookie we need for further calls
				login = RestClient.post('https://api.orcasecurity.io/api/user/session', {'security_token': @@configuration['orca_secretkey']})
				
				# Check we got the status we expect from the post
				if login.code == 200

					# Store the cookie in a variable we got back from RestClient
					cookies = login.cookies
				
				else
			
					# Got a response we didn't expect and we didn't get a cookie back
					puts "Unable to login to Orca rest api".colorize(:red)
			
				end
			else

				# Config file doesn't have orca_secretkey defined by the file exists
				puts "Unable to find orca_secretkey in ~/.orca/config".colorize(:red)
			
			end
		end

		# Returns the cookies retrieved by the RestClient url or returns nil indicating we didn't login
		return cookies 
	end

	# Load the yaml file .orca/config from our home directory and return the data
	def self.load_configuration(config_file = "#{Dir.home}/.orca/config")
		
		# Verify the file exists where we expect or print a message
		if File.exists?(config_file)

			# Open the file for reading and read the files content
			file = File.open(config_file)
			content = file.read()

			# Parse the contents as YAML and store the content in config
			config = YAML.load(content)

			# Return the parsed yaml in a variable
			return config
		else

			# File didn't exist and we print this to state we are unable to find it
			puts "Unable to read #{Dir.home}/.orca/config".colorize(:red)
		end
	end

	# Retrieve the alerts and return only the ones valid for the instance_id passed to the method
	def get_alerts_by_instance(instance_id)

		# Holds the json data from the RestClient
		orca_alerts = nil

		# Stores an array of alerts for the instance_id passed to this method
		instance_alerts = []

		# Make sure we are given an instance_id
		if instance_id
	
			# Verify we are authenticated
			if @@cookies
				# Get the alerts for assest_type = vm which is ec2 instances
				alerts = RestClient.get('https://api.orcasecurity.io/api/alerts?asset_type=vm', :cookies => @@cookies)

				# Confirm we got a 200 status code from the rest url
				if alerts.code == 200

					# Parse the body from the api which is in JSON and convert it to a useable form
					orca_alerts = JSON.parse(alerts.body)
				
					# Check the returned data that holds the Orca alerts and loop through the alerts
					orca_alerts['data'].each do |alert|
						
						# Verify we get only the alerts for an instance_id be comparing with vm_id that Orca uses
						if alert['vm_id'] == instance_id
							
							# Append an alert to the instance_alerts array
							instance_alerts << alert 
						
						end
					end
				else
					# RestClient returned a status code other than 200 and when didn't expect it
					puts "Orca Client Error: -(Failed)- Status code: #{alerts.code}".colorize(:red)
				end
			end
		end

		# Return the array of orca alerts for the instance_id passed to the method or return an empty array
		return instance_alerts

	end

	# Function that is called when you do Orca.new and setups class variables used by the other methods
	def initialize()
		
		# Load orca/config to get orca_secretkey to login
		@@configuration = Orca::load_configuration()
		
		# Login to get auth cookie
		@@cookies = Orca::login()

		if @@cookies
			# Online means we have logged in and we can make rest calls to api
			puts "++[Orca Security]++ | status: online".colorize(:blue)
		else
			# Says we don't have a cookie to use to authenticate our rest calls to the api
			puts "++[Orca Security]++ | status: offline".colorize(:red)
		end
		# Informational message of the login_url we use to authenticate for rest
		puts "++[Orca Security]++ | login_url: https://api.orcasecurity.io/api/user/session".colorize(:blue)
		puts ""
	end

end