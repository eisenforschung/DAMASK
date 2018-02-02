#!/usr/bin/env python2.7
# -*- coding: UTF-8 no BOM -*-

import os,vtk
import damask
from vtk.util import numpy_support
from collections import defaultdict
from optparse import OptionParser

scriptName = os.path.splitext(os.path.basename(__file__))[0]
scriptID   = ' '.join([scriptName,damask.version])

# --------------------------------------------------------------------
#                                MAIN
# --------------------------------------------------------------------

msg = "Add scalars, vectors, and/or an RGB tuple from"
msg += "an ASCIItable to existing VTK grid (.vtr/.vtk/.vtu)."
parser = OptionParser(option_class=damask.extendableOption,
                      usage='%prog options [file[s]]',
                      description = msg,
                      version = scriptID)

parser.add_option(      '--vtk',
                  dest = 'vtk',
                  type = 'string', metavar = 'string',
                  help = 'VTK file name')
parser.add_option(      '--inplace',
                  dest = 'inplace',
                  action = 'store_true',
                  help = 'modify VTK file in-place')
parser.add_option('-r', '--render',
                  dest = 'render',
                  action = 'store_true',
                  help = 'open output in VTK render window')
parser.add_option('-d', '--data',
                  dest = 'data',
                  action = 'extend', metavar = '<string LIST>',
                  help = 'scalar/vector value(s) label(s)')
parser.add_option('-t', '--tensor',
                  dest = 'tensor',
                  action = 'extend', metavar = '<string LIST>',
                  help = 'tensor (3x3) value label(s)')
parser.add_option('-c', '--color',
                  dest = 'color',
                  action = 'extend', metavar = '<string LIST>',
                  help = 'RGB color tuple label')

parser.set_defaults(data = [],
                    tensor = [],
                    color = [],
                    inplace = False,
                    render = False,
)

(options, filenames) = parser.parse_args()

if not options.vtk:                 parser.error('No VTK file specified.')
if not os.path.exists(options.vtk): parser.error('VTK file does not exist.')

if os.path.splitext(options.vtk)[1] == '.vtr':
  reader = vtk.vtkXMLRectilinearGridReader()
  reader.SetFileName(options.vtk)
  reader.Update()
  rGrid = reader.GetOutput()
  writer = vtk.vtkXMLRectilinearGridWriter()
  writer.SetFileName(os.path.splitext(options.vtk)[0]+('.vtr' if options.inplace else '_added.vtr'))
elif os.path.splitext(options.vtk)[1] == '.vtk':
  reader = vtk.vtkGenericDataObjectReader()
  reader.SetFileName(options.vtk)
  reader.Update()
  rGrid = reader.GetRectilinearGridOutput()
  writer = vtk.vtkXMLRectilinearGridWriter()
  writer.SetFileName(os.path.splitext(options.vtk)[0]+('.vtr' if options.inplace else '_added.vtr'))
elif os.path.splitext(options.vtk)[1] == '.vtu':
  reader = vtk.vtkXMLUnstructuredGridReader()
  reader.SetFileName(options.vtk)
  reader.Update()
  rGrid = reader.GetOutput()
  writer = vtk.vtkXMLUnstructuredGridWriter()
  writer.SetFileName(os.path.splitext(options.vtk)[0]+('.vtu' if options.inplace else '_added.vtu'))
else:
  parser.error('Unsupported VTK file type extension.')

Npoints = rGrid.GetNumberOfPoints()
Ncells  = rGrid.GetNumberOfCells()

damask.util.croak('{}: {} points and {} cells...'.format(options.vtk,Npoints,Ncells))

# --- loop over input files -------------------------------------------------------------------------

if filenames == []: filenames = [None]

for name in filenames:
  try:    table = damask.ASCIItable(name = name,
                                    buffered = False,
                                    readonly = True)
  except: continue
  damask.util.report(scriptName, name)

# --- interpret header ----------------------------------------------------------------------------

  table.head_read()

  remarks = []
  errors  = []
  VTKarray = {}
  active = defaultdict(list)

  for datatype,dimension,label in [['data',99,options.data],
                                   ['tensor',9,options.tensor],
                                   ['color' ,3,options.color],
                                   ]:
    for i,dim in enumerate(table.label_dimension(label)):
      me = label[i]
      if dim == -1:         remarks.append('{} "{}" not found...'.format(datatype,me))
      elif dim > dimension: remarks.append('"{}" not of dimension {}...'.format(me,dimension))
      else:
        remarks.append('adding {} "{}"...'.format(datatype,me))
        active[datatype].append(me)

  if remarks != []: damask.util.croak(remarks)
  if errors  != []:
    damask.util.croak(errors)
    table.close(dismiss = True)
    continue

# ------------------------------------------ process data ---------------------------------------

  table.data_readArray([item for sublist in active.values() for item in sublist])                 # read all requested data

  for datatype,labels in active.items():                                                          # loop over scalar,color
    for me in labels:                                                                             # loop over all requested items
      VTKtype = vtk.VTK_DOUBLE
      VTKdata = table.data[:, table.label_indexrange(me)].copy()                                  # copy to force contiguous layout

      if datatype == 'color':
        VTKtype = vtk.VTK_UNSIGNED_CHAR
        VTKdata = (VTKdata*255).astype(int)                                                       # translate to 0..255 UCHAR
      elif datatype == 'tensor':
        VTKdata[:,1] = VTKdata[:,3] = 0.5*(VTKdata[:,1]+VTKdata[:,3])
        VTKdata[:,2] = VTKdata[:,6] = 0.5*(VTKdata[:,2]+VTKdata[:,6])
        VTKdata[:,5] = VTKdata[:,7] = 0.5*(VTKdata[:,5]+VTKdata[:,7])

      VTKarray[me] = numpy_support.numpy_to_vtk(num_array=VTKdata,deep=True,array_type=VTKtype)
      VTKarray[me].SetName(me)

  table.close()                                                                                     # close input ASCII table

# ------------------------------------------ add data ---------------------------------------

  if   len(table.data) == Npoints:  mode = 'point'
  elif len(table.data) == Ncells:   mode = 'cell'
  else:
    damask.util.croak('Data count is incompatible with grid...')
    continue

  damask.util.croak('{} mode...'.format(mode))

  for datatype,labels in active.items():                                                            # loop over scalar,color
    if datatype == 'color':
      if   mode == 'cell':  rGrid.GetCellData().SetScalars(VTKarray[active['color'][0]])
      elif mode == 'point': rGrid.GetPointData().SetScalars(VTKarray[active['color'][0]])
    for me in labels:                                                                               # loop over all requested items
      if   mode == 'cell':  rGrid.GetCellData().AddArray(VTKarray[me])
      elif mode == 'point': rGrid.GetPointData().AddArray(VTKarray[me])

  rGrid.Modified()
  if vtk.VTK_MAJOR_VERSION <= 5: rGrid.Update()

# ------------------------------------------ output result ---------------------------------------

  writer.SetDataModeToBinary()
  writer.SetCompressorTypeToZLib()
  if vtk.VTK_MAJOR_VERSION <= 5: writer.SetInput(rGrid)
  else:                          writer.SetInputData(rGrid)
  writer.Write()

# ------------------------------------------ render result ---------------------------------------

if options.render:
  mapper = vtk.vtkDataSetMapper()
  mapper.SetInputData(rGrid)
  actor = vtk.vtkActor()
  actor.SetMapper(mapper)

# Create the graphics structure. The renderer renders into the
# render window. The render window interactor captures mouse events
# and will perform appropriate camera or actor manipulation
# depending on the nature of the events.

  ren = vtk.vtkRenderer()

  renWin = vtk.vtkRenderWindow()
  renWin.AddRenderer(ren)

  ren.AddActor(actor)
  ren.SetBackground(1, 1, 1)
  renWin.SetSize(200, 200)

  iren = vtk.vtkRenderWindowInteractor()
  iren.SetRenderWindow(renWin)

  iren.Initialize()
  renWin.Render()
  iren.Start()