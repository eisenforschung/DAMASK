#!/usr/bin/env python

import os,re,sys,math,string,numpy,damask
from optparse import OptionParser, Option

# -----------------------------
class extendableOption(Option):
# -----------------------------
# used for definition of new option parser action 'extend', which enables to take multiple option arguments
# taken from online tutorial http://docs.python.org/library/optparse.html
  
  ACTIONS = Option.ACTIONS + ("extend",)
  STORE_ACTIONS = Option.STORE_ACTIONS + ("extend",)
  TYPED_ACTIONS = Option.TYPED_ACTIONS + ("extend",)
  ALWAYS_TYPED_ACTIONS = Option.ALWAYS_TYPED_ACTIONS + ("extend",)

  def take_action(self, action, dest, opt, value, values, parser):
    if action == "extend":
      lvalue = value.split(",")
      values.ensure_value(dest, []).extend(lvalue)
    else:
      Option.take_action(self, action, dest, opt, value, values, parser)

def location(idx,res):
  return ( idx  % res[0], \
         ( idx // res[0]) % res[1], \
         ( idx // res[0] // res[1]) % res[2] )

def index(location,res):
  return ( location[0] % res[0]                   + \
         ( location[1] % res[1]) * res[0]          + \
         ( location[2] % res[2]) * res[1] * res[0]   )



# --------------------------------------------------------------------
#                                MAIN
# --------------------------------------------------------------------

parser = OptionParser(option_class=extendableOption, usage='%prog options [file[s]]', description = """
Add column(s) containing deformed configuration of requested column(s).
Operates on periodic ordered three-dimensional data sets.

""" + string.replace('$Id$','\n','\\n')
)

parser.add_option('-c','--coordinates', dest='coords', type='string',\
                                        help='column heading for coordinates [%default]')
parser.add_option('-d','--defgrad',     dest='defgrad', type='string', \
                                        help='heading of columns containing tensor field values')
parser.add_option('-l', '--linear', dest='linearreconstruction', action='store_true',\
                  help='use linear reconstruction of geometry [%default]')
                  
parser.set_defaults(coords  = 'ip')
parser.set_defaults(defgrad = 'f' )
parser.set_defaults(linearreconstruction = False)

(options,filenames) = parser.parse_args()

# ------------------------------------------ setup file handles ---------------------------------------  

files = []
if filenames == []:
  files.append({'name':'STDIN', 'input':sys.stdin, 'output':sys.stdout})
else:
  for name in filenames:
    if os.path.exists(name):
      files.append({'name':name, 'input':open(name), 'output':open(name+'_tmp','w')})


# ------------------------------------------ loop over input files ---------------------------------------   

for file in files:
  if file['name'] != 'STDIN': print file['name'],

  table = damask.ASCIItable(file['input'],file['output'],False)             # make unbuffered ASCII_table
  table.head_read()                                                         # read ASCII header info
  table.info_append(string.replace('$Id$','\n','\\n') + \
                    '\t' + ' '.join(sys.argv[1:]))

# --------------- figure out dimension and resolution 
  try:
    locationCol = table.labels.index('%s.x'%options.coords)                 # columns containing location data
  except ValueError:
    print 'no coordinate data found...'
    continue

  grid = [{},{},{}]

  while table.data_read():                                                  # read next data line of ASCII table
    if str(table.data[locationCol+1]) in grid[1] and len(grid[1])>1:        # geomdim[1] and res[1] already figured out, skip layers
      table.data_skipLines(len(grid[1])*len(grid[0])-1)
    else:
      if str(table.data[locationCol]) in grid[0]:                           # geomdim[0] and res[0] already figured out, skip lines
        table.data_skipLines(len(grid[0])-1)
    for j in xrange(3):
      grid[j][str(table.data[locationCol+j])] = True                        # remember coordinate along x,y,z

  res = numpy.array([len(grid[0]),\
                     len(grid[1]),\
                     len(grid[2]),],'i')                                    # resolution is number of distinct coordinates found
  geomdim = res/numpy.maximum(numpy.ones(3,'d'),res-1.0)* \
              numpy.array([max(map(float,grid[0].keys()))-min(map(float,grid[0].keys())),\
                           max(map(float,grid[1].keys()))-min(map(float,grid[1].keys())),\
                           max(map(float,grid[2].keys()))-min(map(float,grid[2].keys())),\
                          ],'d')                                            # dimension from bounding box, corrected for cell-centeredness
  if res[2] == 1:
   geomdim[2] = min(geomdim[:2]/res[:2])

  N = res.prod()
  print '\t%s @ %s'%(geomdim,res)

  
# --------------- figure out columns to process

  key = '1_%s' %options.defgrad
  if key not in table.labels:
    sys.stderr.write('column %s not found...\n'%key)
  else:
    defgrad = numpy.array([0.0 for i in xrange(N*9)]).reshape(list(res)+[3,3])
    table.labels_append(['ip_deformed.%s'%(coord) for coord in 'x','y','z'])   # extend ASCII header with new labels
    column = table.labels.index(key)
        
# ------------------------------------------ assemble header ---------------------------------------  

  table.head_write()

# ------------------------------------------ read value field ---------------------------------------  

  table.data_rewind()

  idx = 0
  while table.data_read():                                                  # read next data line of ASCII table
    (x,y,z) = location(idx,res)                                             # figure out (x,y,z) position from line count
    idx += 1
    defgrad[x,y,z] = numpy.array(map(float,table.data[column:column+9]),'d').reshape(3,3)

    # ------------------------------------------ process value field ----------------------------
  defgrad_av = damask.core.math.tensorAvg(defgrad)
  if options.linearreconstruction:
    centroids = damask.core.mesh.deformed_fft(res,geomdim,defgrad_av,1.0,defgrad)
  else:
    centroids = damask.core.mesh.deformed_fft(res,geomdim,defgrad_av,1.0,defgrad)
# ------------------------------------------ process data ---------------------------------------  

  table.data_rewind()
  idx = 0
  while table.data_read():                                                  # read next data line of ASCII table
    (x,y,z) = location(idx,res)                                             # figure out (x,y,z) position from line count
    idx += 1
    table.data_append(list(centroids[x,y,z]))

    table.data_write()                                                      # output processed line

  
# ------------------------------------------ output result ---------------------------------------  

  table.output_flush()                                                      # just in case of buffered ASCII table

  file['input'].close()                                                     # close input ASCII table
  if file['name'] != 'STDIN':
    file['output'].close                                                    # close output ASCII table
    os.rename(file['name']+'_tmp',file['name'])                             # overwrite old one with tmp new
