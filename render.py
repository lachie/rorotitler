#!BPY

from os import environ

from Blender import *
from Blender.Scene import Render
import bpy
import Blender
import re


def setup_text(text,sce):
  title = environ['RORO_TITLE'].replace('\\n', "\n")
  
  text3d = text.getData()
  text3d.setText(title)

  text.makeDisplayList()
  Window.RedrawAll()

def render_frame(sce):
  
  Window.ViewLayers([1,2])

  text = Blender.Object.Get('Font.001')
  print 'found ', text
  
  if text:
    setup_text(text,sce)

  context = sce.getRenderingContext()
  context.currentFrame(20)
  
  print "cf: ", context.currentFrame
  print "cframe: ", Blender.Get('curframe')
  
  
  context.renderPath   = ''
  context.imageType    = Render.PNG
  
  
  if environ['RORO_PREVIEW'] == '1':
    context.renderer = Render.INTERNAL
    context.imageSizeX(400)
    context.imageSizeY(300)

  else:
    context.renderer = Render.YAFRAY
    context.imageSizeX(800)
    context.imageSizeY(600)

  context.render()
  # context.saveRenderedImage(environ['RORO_OUTPUT_PATH'])

  
  
def main():
  done = 0

    
  # Gets the current scene, there can be many scenes in 1 blend file.
  sce = bpy.data.scenes.active
  
  Window.WaitCursor(1)
  t = sys.time()
  
  print environ
  # Run the object editing function
  render_frame(sce)
  
  
  
  # Timing the script is a good way to be aware on any speed hits when scripting
  print 'My Script finished in %.2f seconds' % (sys.time()-t)
  Window.WaitCursor(0)
  
  
# This lets you can import the script without running it
if __name__ == '__main__':
  main()