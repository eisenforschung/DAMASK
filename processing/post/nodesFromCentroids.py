#!/usr/bin/env python
# -*- coding: UTF-8 no BOM -*-

import os,sys,string,numpy,damask
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
Calculates current nodal coordinates and nodal displacement from IP/FP based data.

""" + string.replace('$Id$','\n','\\n')
)

parser.add_option('-d','--deformed',   dest='deformedCentroids', type='string',\
                                       help='column heading for position of deformed center of element/IP [%default]')
parser.add_option('-u','--undeformed', dest='undeformedCentroids', type='string',\
                                       help='column heading for position of undeformed center of element/IP [%default]')
parser.add_option('-f','--defgrad',    dest='defgrad', type='string',\
                                       help='column heading for position of deformation gradient [%default]')

parser.set_defaults(deformedCentroids    = 'ip_deformed')
parser.set_defaults(undeformedCentroids  = 'ipinitialcoord')
parser.set_defaults(defgrad              = 'f')

(options,filenames) = parser.parse_args()

# ------------------------------------------ setup file handles ---------------------------------------  

files = []
if filenames == []:
  files.append({'name':'STDIN', 'input':sys.stdin, 'output':sys.stdout})
else:
  for name in filenames:
    if os.path.exists(name):
      files.append({'name':name, 'input':open(name), \
                                'output':open(os.path.splitext(name)[0]+'_nodal'+os.path.splitext(name)[1],'w')})


# ------------------------------------------ loop over input files ---------------------------------------   
for file in files:
  if file['name'] != 'STDIN': print file['name'],
  table = damask.ASCIItable(file['input'])                                  # make unbuffered ASCII_table
  table.head_read()                                                         # read ASCII header info
  table.info_append(string.replace('$Id$','\n','\\n') + \
                    '\t' + ' '.join(sys.argv[1:]))

# --------------- figure out dimension and resolution 
  try:
    locationCol = table.labels.index('%s.x'%options.undeformedCentroids)    # columns containing location data
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

  key = '%s.x' %options.deformedCentroids
  if key not in table.labels:
    sys.stderr.write('column %s not found...\n'%key)
  else:
    columnDeformed = table.labels.index(key)
  
  key = '%s.x' %options.undeformedCentroids
  if key not in table.labels:
    sys.stderr.write('column %s not found...\n'%key)
  else:
    columnUndeformed = table.labels.index(key)  
  
  key = '1_%s' %options.defgrad
  if key not in table.labels:
    sys.stderr.write('column %s not found...\n'%key)
  else:
    columnDefgrad = table.labels.index(key)
# ------------------------------------------ read value field ---------------------------------------  

  deformedCentroids   = numpy.array([0.0 for i in xrange(N*3)]).reshape(list(res)+[3])
  undeformedCentroids = numpy.array([0.0 for i in xrange(N*3)]).reshape(list(res)+[3])
  defgrad             = numpy.array([0.0 for i in xrange(N*9)]).reshape(list(res)+[3,3])

  table.data_rewind()
  table.data_read()
  inc = int(eval(table.data[table.labels.index('inc')]))

  table.data_rewind()
  idx = 0
  while table.data_read():                                                  # read next data line of ASCII table
    (x,y,z) = location(idx,res)                                             # figure out (x,y,z) position from line count
    idx += 1
    deformedCentroids[x,y,z]   = numpy.array(map(float,table.data[columnDeformed:columnDeformed+3]),'d')
    undeformedCentroids[x,y,z] = numpy.array(map(float,table.data[columnUndeformed:columnUndeformed+3]),'d')
    defgrad[x,y,z] = numpy.array(map(float,table.data[columnDefgrad:columnDefgrad+9]),'d').reshape(3,3)

  table.input_close()                                                       # close input ASCII table


# ------------------------------------------ process value field ----------------------------
  defgrad_av = damask.core.math.math_tensorAvg(defgrad)
  nodesDeformed   = damask.core.mesh.mesh_regular_grid(res,geomdim,defgrad_av,deformedCentroids)
  nodesUndeformed = damask.core.mesh.mesh_regular_grid(res,geomdim,numpy.identity(3,'d'),undeformedCentroids)


# ------------------------------------------ process data ---------------------------------------  
  table = damask.ASCIItable(fileOut=file['output'],buffered= False)             # make unbuffered ASCII_table
  table.info_append(string.replace('$Id$','\n','\\n') + \
                    '\t' + ' '.join(sys.argv[1:]))

  table.labels_append('inc elem node ip grain ')   # extend ASCII header with new labels
  table.labels_append(['node.%s'%(coord) for coord in 'x','y','z'])   # extend ASCII header with new labels
  table.labels_append(['Displacement%s'%(coord) for coord in 'X','Y','Z'])   # extend ASCII header with new labels
  table.head_write()

  ielem = 0
  for z in xrange(res[2]+1):
    for y in xrange(res[1]+1):
      for x in xrange(res[0]+1):
        ielem +=1
        entry = [inc,0,ielem,0,0,'\t'.join([str(a) for a in(nodesUndeformed[x][y][z])]),'\t'.join([str(a) for a in (nodesUndeformed[x][y][z] - nodesDeformed[x][y][z])])]
        table.data_append(entry)
        table.data_write()                                                 # output processed line
        table.data_clear()
# ------------------------------------------ assemble header ---------------------------------------  

  table.output_flush()                                                      # just in case of buffered ASCII table

  if file['name'] != 'STDIN': file['output'].close                                                    # close output ASCII table
