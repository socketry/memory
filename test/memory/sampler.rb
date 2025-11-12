# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.

require "memory"
require "socket"
require "fileutils"

class MyThing
end

describe Memory::Sampler do
	let(:sampler) {subject.new}
	
	it "captures allocations" do
		sampler.run do
			MyThing.new
		end
		
		expect(sampler.allocated.size).to be == 1
		
		allocation = sampler.allocated.first
		expect(allocation.class_name).to be == MyThing.name
		expect(allocation.file).to be(:end_with?, "sampler.rb")
		expect(allocation.retained).to be_falsey
	end
	
	it "captures retained allocations" do
		x = nil
		
		sampler.run do
			x = MyThing.new
		end
		
		expect(sampler.allocated.size).to be == 1
		
		allocation = sampler.allocated.first
		expect(allocation.class_name).to be == MyThing.name
		expect(allocation.file).to be(:end_with?, "sampler.rb")
		expect(allocation.retained).to be_truthy
	end
	
	it "safely captures locked string objects" do
		socket_path = "/tmp/test_supervisor.ipc"
		FileUtils.rm_f(socket_path)
		
		memory = Memory::Sampler.new
		memory.start
		
		# Create server thread
		Thread.new do
			server = UNIXServer.new(socket_path)
			client = server.accept
			
			2.times do
				buffer = String.new(capacity: 2)
				length_data = client.read(2, buffer) # buffer gets locked while reading
				break unless length_data && length_data.bytesize == 2
				
				length = length_data.unpack1("n")
				client.read(length)
			end
		ensure
			client&.close
			server.close
		end
		
		# Create a client thread
		Thread.new do
			socket = UNIXSocket.new(socket_path)
			
			2.times do
				message = Time.now.to_s
				socket.write([message.bytesize].pack("n") + message)
				puts "hello #{message}"
				sleep(1)
			end
		ensure
			socket&.close
		end
		
		sleep(0.1)
		
		memory.stop
		memory.report # buffer string is locked while reading ObjectSpace#each_object
	ensure
		FileUtils.rm_f(socket_path)
	end
	
	with "#as_json" do
		it "returns allocation count" do
			x = nil
			
			sampler.run do
				x = MyThing.new
			end
			
			json_data = sampler.as_json
			
			expect(json_data).to have_keys(:allocations)
			expect(json_data[:allocations]).to be > 0
		end
	end
	
	with "#to_json" do
		it "produces valid JSON string" do
			x = nil
			
			sampler.run do
				x = MyThing.new
			end
			
			json_string = sampler.to_json
			parsed = JSON.parse(json_string)
			
			expect(parsed["allocations"]).to be > 0
		end
	end
end
