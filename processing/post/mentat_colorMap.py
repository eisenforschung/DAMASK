#!/usr/bin/env python 

import sys, os, string
import damask
from optparse import OptionParser


# -----------------------------
def readConfig(configFile,ownPath):
  config = {}
  configDir = os.path.split(os.path.realpath(ownPath))[0]
  filename = os.path.join(configDir,configFile)
  if os.path.isfile(filename):
    file = open(filename)
    for line in file.readlines():
      if not line.startswith('#'):
        item = line.split()
        for name in item[0].split('|'):
          config[name] = {}
          config[name]['left']  = map(float,item[1].split(','))
          config[name]['right'] = map(float,item[2].split(','))
    file.close()

  return config



# -----------------------------
def outMentat(cmd,locals):
    if cmd[0:3] == '(!)':
        exec(cmd[3:])
    elif cmd[0:3] == '(?)':
        cmd = eval(cmd[3:])
        py_send(cmd)
    else:
        py_send(cmd)
    return



# -----------------------------
def outStdout(cmd,locals):
    if cmd[0:3] == '(!)':
        exec(cmd[3:])
    elif cmd[0:3] == '(?)':
        cmd = eval(cmd[3:])
        print cmd
    else:
        print cmd
    return



# -----------------------------
def output(cmds,locals,dest):
    for cmd in cmds:
        if isinstance(cmd,list):
            output(cmd,locals,dest)
        else:
            {\
            'Mentat': outMentat,\
            'Stdout': outStdout,\
            }[dest](cmd,locals)
    return



# -----------------------------
def colorMap(colors,baseIdx=32):
    cmds = [ "*color %i %f %f %f"%(idx+baseIdx,color[0],color[1],color[2]) 
             for idx,color in enumerate(colors) ]    
    return cmds
    

# -----------------------------
# MAIN FUNCTION STARTS HERE
# -----------------------------

parser = OptionParser(usage="%prog [options] configured scheme | (lower_h,s,l upper_h,s,l)", description = """
Changes the color map in MSC.Mentat. 

Interpolates colors between "lower_hsl" and "upper_hsl". 
""" + string.replace('$Id$','\n','\\n')
)


parser.add_option("-i","--inverse", action = "store_true", 
                  dest = "inverse", \
                  help = "invert legend [%default]")
parser.add_option(     "--palette", action = "store_true", 
                  dest = "palette", \
                  help = "output plain rgb palette integer values (0-255) [%default]")
parser.add_option(     "--palettef", action = "store_true", 
                  dest = "palettef", \
                  help = "output plain rgb palette float values (0.0-1.0) [%default]")
parser.add_option("-p", "--port", type = "int",\
                  dest = "port",\
                  help = "Mentat connection port [%default]")
parser.add_option("-b", "--baseindex", type = "int",\
                  dest = "baseIdx",\
                  help = "base index of colormap [%default]")
parser.add_option("-n", "--colorcount", type = "int",\
                  dest = "colorcount",\
                  help = "number of colors [%default]")
parser.add_option("-c", "--config", type='string', \
                  dest = "config",\
                  help = "configuration file [%default]")
parser.add_option("-v", "--verbose", action="store_true",\
                  dest = "verbose",\
                  help = "write Mentat command stream also to stdout [%default]")

parser.set_defaults(port = 40007)
parser.set_defaults(baseIdx = 32)
parser.set_defaults(colorcount = 32)
parser.set_defaults(config = 'colorMap.config')
parser.set_defaults(inverse   = False)
parser.set_defaults(palette   = False)
parser.set_defaults(verbose   = False)

msg = []

(options, colors) = parser.parse_args()

config = readConfig(options.config,sys.argv[0])

if len(colors) > 0 and colors[0] in config:
  left  = config[colors[0]][{True:'right',False:'left' }[options.inverse]]
  right = config[colors[0]][{True:'left' ,False:'right'}[options.inverse]]
elif len(colors) == 2:
  left  = map(float, colors[{True:1,False:0}[options.inverse]].split(','))
  right = map(float, colors[{True:0,False:1}[options.inverse]].split(','))
else:
  left   = {True:[0.0,0.0,0.0],False:[0.0,0.0,1.0]}[options.inverse]
  right  = {True:[0.0,0.0,1.0],False:[0.0,0.0,0.0]}[options.inverse]

theMap = damask.Colormap(damask.Color('HSL',left),damask.Color('HSL',right))
theColors = theMap.export(format='list',steps=options.colorcount)

if options.palette or options.palettef:
  for theColor in theColors:
    print '\t'.join(map(lambda x: {True: str(        x),
                                   False:str(int(255*x))}[options.palettef],theColor))
else:  
### connect to mentat and change colorMap
  sys.path.append(damask.solver.Marc().libraryPath('../../'))
  try:
    from py_mentat import *
    print 'waiting to connect...'
    py_connect('',options.port)
    print 'connected...'
    mentat = True
  except:
    sys.stderr.write('warning: no valid Mentat release found\n')
    mentat = False

  outputLocals = {}
  cmds = colorMap(theColors,options.baseIdx)
  if mentat:
    output(['*show_table']+cmds+['*show_model *redraw'],outputLocals,'Mentat')
    py_disconnect()
  
  if options.verbose:
    output(cmds,outputLocals,'Stdout')
