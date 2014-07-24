#!/usr/bin/env python
# -*- coding: UTF-8 no BOM -*-

import os,re,sys,math,string
import numpy as np
from collections import defaultdict
from optparse import OptionParser
import damask

scriptID = '$Id$'
scriptName = scriptID.split()[1]

def normalize(vec):
    return vec/np.sqrt(np.inner(vec,vec))

def E_hkl(stiffness,vec):   # stiffness = (c11,c12,c44)
    v = normalize(vec)
    S11 = (stiffness[0]+stiffness[1])/(stiffness[0]*stiffness[0]+stiffness[0]*stiffness[1]-2.0*stiffness[1]*stiffness[1])
    S12 = (            -stiffness[1])/(stiffness[0]*stiffness[0]+stiffness[0]*stiffness[1]-2.0*stiffness[1]*stiffness[1])
    S44 = 1.0/stiffness[2]

    invE = S11-(S11-S12-0.5*S44)* (1.0 - \
                 (v[0]**4+v[1]**4+v[2]**4) \
            /#------------------------------------
                 np.inner(v,v)**2 \
                )

    return 1.0/invE

# --------------------------------------------------------------------
#                                MAIN
# --------------------------------------------------------------------

parser = OptionParser(option_class=damask.extendableOption, usage='%prog options [file[s]]', description = """
Add column(s) containing directional stiffness
based on given cubic stiffness values C11, C12, and C44 in consecutive columns.

""", version = string.replace(scriptID,'\n','\\n')
)

parser.add_option('-c','--stiffness',   dest='vector', action='extend', type='string', metavar='<string LIST>',
                                        help='heading of column containing C11 (followed by C12, C44) field values')
parser.add_option('-d','--direction', \
                       '--hkl',         dest='hkl', action='store', type='int', nargs=3, metavar='int int int',
                                        help='direction of elastic modulus %default')
parser.set_defaults(vector = [])
parser.set_defaults(hkl = [1,1,1])

(options,filenames) = parser.parse_args()

if len(options.vector)== 0:
  parser.error('no data column specified...')

datainfo = {                                                               # list of requested labels per datatype
             'vector':     {'len':3,
                            'label':[]},
           }

datainfo['vector']['label']  += options.vector

# ------------------------------------------ setup file handles ---------------------------------------  

files = []
if filenames == []:
  files.append({'name':'STDIN', 'input':sys.stdin, 'output':sys.stdout, 'croak':sys.stderr})
else:
  for name in filenames:
    if os.path.exists(name):
      files.append({'name':name, 'input':open(name), 'output':open(name+'_tmp','w'), 'croak':sys.stderr})

# ------------------------------------------ loop over input files ---------------------------------------  
for file in files:
  if file['name'] != 'STDIN': file['croak'].write('\033[1m'+scriptName+'\033[0m: '+file['name']+'\n')
  else: file['croak'].write('\033[1m'+scriptName+'\033[0m\n')

  table = damask.ASCIItable(file['input'],file['output'],False)                                     # make unbuffered ASCII_table
  table.head_read()                                                                                 # read ASCII header info
  table.info_append(string.replace(scriptID,'\n','\\n') + '\t' + ' '.join(sys.argv[1:]))

  active = defaultdict(list)
  column = defaultdict(dict)

  for datatype,info in datainfo.items():
    for label in info['label']:
      foundIt = False
      for key in ['1_'+label,label]:
        if key in table.labels:
          foundIt = True
          active[datatype].append(label)
          column[datatype][label] = table.labels.index(key)                                         # remember columns of requested data
      if not foundIt:
        file['croak'].write('column %s not found...\n'%label)    

# ------------------------------------------ assemble header --------------------------------------- 
  for datatype,labels in active.items():                                                            # loop over vector,tensor
    for label in labels:                                                                            # loop over all requested stiffnesses
      table.labels_append('E%i%i%i(%s)'%(options.hkl[0],
                                         options.hkl[1],
                                         options.hkl[2],label))                                     # extend ASCII header with new labels
  table.head_write()

# ------------------------------------------ process data ----------------------------------------  
  outputAlive = True
  while outputAlive and table.data_read():                                                          # read next data line of ASCII table
    for datatype,labels in active.items():                                                          # loop over vector,tensor
      for label in labels:                                                                          # loop over all requested stiffnesses
        table.data_append(E_hkl(map(float,table.data[column[datatype][label]:\
                                                    column[datatype][label]+datainfo[datatype]['len']]),options.hkl))
    
    outputAlive = table.data_write()                                                                # output processed line

# ------------------------------------------ output result ---------------------------------------  
  outputAlive and table.output_flush()                                                              # just in case of buffered ASCII table

  file['input'].close()                                                                             # close input ASCII table (works for stdin)
  file['output'].close()                                                                            # close output ASCII table (works for stdout)
  if file['name'] != 'STDIN':
    os.rename(file['name']+'_tmp',file['name'])                                                     # overwrite old one with tmp new
