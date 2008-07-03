#require 'rubygems'
#require 'active_support'

# thanks Marcus for all the code/inspiration:
module OSX
  
  class CIFilter
	def self.filternamed(name,options={})
		f = filterWithName("CI#{name}") or return
		f.setDefaults
		options.each {|k,v| f.setValue_forKey(v, k.to_s)}
		f
	end
	
	def save_output(target, format = OSX::NSPNGFileType, properties = nil)
		bitmapRep = OSX::NSBitmapImageRep.alloc.initWithCIImage(valueForKey('outputImage'))
        blob = bitmapRep.representationUsingType_properties(format, properties)
        blob.writeToFile_atomically(target, false)
	end
	
	def outputimage
		valueForKey('outputImage')
	end
	
	def []=(key,value)
		setValue_forKey(value,key.to_s)
	end
  end
  
  
  class CIImage      
    def save(target, format = OSX::NSPNGFileType, properties = nil)
      bitmapRep = OSX::NSBitmapImageRep.alloc.initWithCIImage(self)
      blob = bitmapRep.representationUsingType_properties(format, properties)
      blob.writeToFile_atomically(target, false)
    end
	
	def nsimage
		image = NSImage.alloc.initWithSize([extent.size.width, extent.size.height])
		image.addRepresentation(OSX::NSCIImageRep.imageRepWithCIImage(self))
		image
	end

    def cgimage
      OSX::NSBitmapImageRep.alloc.initWithCIImage(self).CGImage()
    end

    def self.from(filepath)
      raise Errno::ENOENT, "No such file or directory - #{filepath}" unless File.exists?(filepath)
      OSX::CIImage.imageWithContentsOfURL(OSX::NSURL.fileURLWithPath(filepath))
    end
	
	def cicontext
	   output = OSX::NSBitmapImageRep.alloc.initWithBitmapDataPlanes_pixelsWide_pixelsHigh_bitsPerSample_samplesPerPixel_hasAlpha_isPlanar_colorSpaceName_bytesPerRow_bitsPerPixel(nil, self.extent.size.width, self.extent.size.height, 8, 4, true, false, OSX::NSDeviceRGBColorSpace, 0, 0)
	   context = OSX::NSGraphicsContext.graphicsContextWithBitmapImageRep(output)
	   OSX::NSGraphicsContext.setCurrentContext(context)
	   @ci_context = context.CIContext
	end
	
	def filternamed(name,options={})
		OSX::CIFilter.filternamed(name, options.update(:inputImage => self))
	end
	
  end

end