class AsyncTask < OSX::NSObject
	include OSX
	
	#def self.run(path,*args,&block)
	#	t = AsyncTask.alloc.init
	#	t.run(path,*args,&block)
	#end
	
	def run(path,args,&block)	
		puts "running #{path}"
		
		@block = block
		
		@task = NSTask.alloc.init
		@task.launchPath = path		
		@task.arguments = args
		
		stdout_pipe = NSPipe.pipe
		stderr_pipe = NSPipe.pipe
		
		@task.standardOutput = stdout_pipe
		@task.standardOutput = stderr_pipe
		
		
		@stdout = stdout_pipe.fileHandleForReading
		@stdout.readInBackgroundAndNotify

		@stderr = stderr_pipe.fileHandleForReading
		@stderr.readInBackgroundAndNotify		
		
		NSNotificationCenter.defaultCenter.addObserver_selector_name_object(self,'read:',NSFileHandleReadCompletionNotification,@stdout)
		NSNotificationCenter.defaultCenter.addObserver_selector_name_object(self,'read:',NSFileHandleReadCompletionNotification,@stderr)
		NSNotificationCenter.defaultCenter.addObserver_selector_name_object(self,'taskTerminated:',NSTaskDidTerminateNotification,@task)
		
		@task.launch
		self
	end
	
	def dealloc
		NSNotificationCenter.defaultCenter.removeObserver(self)
	end
	
	def read(notification)
		filehandle = notification.object

		if filehandle
			if filehandle == @stdout
				kind = :out 
			elsif filehandle == @stderr
				kind = :err
			end
			
			consume_data(kind,notification.userInfo[NSFileHandleNotificationDataItem])
		
			filehandle.readInBackgroundAndNotify
		end
		
	end

	def consume_data(kind,data)
		if data
			string = NSString.alloc.initWithData_encoding(data,NSUTF8StringEncoding)
			@block.call(kind,string)
		end
	end
	
	
	def terminate
		@task.terminate if @task
	end

	
	def taskTerminated(notification)
		status = notification.object.terminationStatus
		puts "task terminated with status #{status}"
		
		#consume_data(:out,@stdout.readDataToEndOfFile)
		#consume_data(:out,@stderr.readDataToEndOfFile)
		
		@block.call(:finished,nil)
		
		NSNotificationCenter.defaultCenter.removeObserver self
	end
end
