require 'aws-sdk'
require 'colorize'
require 'yaml'

class DBI

	attr_accessor   :name
	attr_accessor   :id
	attr_accessor   :application
	attr_accessor   :class
	attr_accessor   :config
	
	def initialize()
		
		@name = self
		@id = 0
		@application = "#{File.basename($PROGRAM_NAME)}"
		@class = self
		@config = Object

	end

end

class DBI::Config

	attr_accessor :config_file
	attr_reader   :file_format
	attr_reader   :configuration

	def initialize(config = "#{Dir.home}/.dbi/config")

		@config_file = config
		@file_format = "yaml"

		if File.exists(@config_file)

			begin
				file = File.open(@config_file)
			rescue
				puts "Unable to open file #{@config_file}.".colorize(:red)
				exit 1
			end

			data = file.read()
			
			begin
				@configuration = YAML.load(data)
			rescue
				puts "#{@config_file} invalid YAML format.".colorize(:red)
				exit 1
			end
		else
			puts "Please create #{@config_file} in YAML format.".colorize(:red)
			exit 1
		end
	end
end

class DBI::Service < DBI

	attr_accessor :service_name
	attr_accessor :service_type

	def initialize()

		@service_name = String
		@service_type = String
	end

end

class DBI::AmazonWebServices < DBI::Service

	attr_accessor :client

	def initialize()

		DBI::Service::service_name = "Amazon Web Services"
		DBI::Service::service_type = "api"

		@client = Object

	end

end

