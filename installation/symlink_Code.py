#!/usr/bin/env python
import os
import damask

bin_link = { \
            '.' : [
                    'DAMASK_spectral.exe',
                  ],
           }

MarcReleases =[2011,2012,2013,2013.1]

baseDir = damask.Environment('../../').relPath('code/')

try:
  binDir = damask.Environment().options['DAMASK_BIN']
except:
  root=os.access('/usr/local/bin', os.W_OK)
  if root:
    binDir = '/usr/local/bin'
  else:
    binDir = os.path.join(os.getenv('HOME'),'bin')

if not os.path.isdir(binDir):
  os.mkdir(binDir)

for dir in bin_link:
  for file in bin_link[dir]:
    src = os.path.abspath(os.path.join(baseDir,dir,file))
    if os.path.exists(src): 
      sym_link = os.path.abspath(os.path.join(binDir,\
                                              {True: dir,
                                               False:os.path.splitext(file)[0]}[file == '']))
      if os.path.lexists(sym_link): os.remove(sym_link)
      os.symlink(src,sym_link)
      print sym_link,'-->',src


for version in MarcReleases:
  src = os.path.abspath(os.path.join(baseDir,'DAMASK_marc.f90'))
  if os.path.exists(src): 
    sym_link = os.path.abspath(os.path.join(baseDir,'DAMASK_marc'+str(version)+'.f90'))                    
    if os.path.lexists(sym_link): os.remove(sym_link)
    os.symlink(src,sym_link)
    print sym_link,'-->',src
