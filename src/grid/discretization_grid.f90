!--------------------------------------------------------------------------------------------------
!> @author Franz Roters, Max-Planck-Institut für Eisenforschung GmbH
!> @author Philip Eisenlohr, Max-Planck-Institut für Eisenforschung GmbH
!> @author Martin Diehl, Max-Planck-Institut für Eisenforschung GmbH
!> @brief Parse geometry file to set up discretization and geometry for nonlocal model
!--------------------------------------------------------------------------------------------------
module discretization_grid
#include <petsc/finclude/petscsys.h>
  use PETScsys

  use prec
  use system_routines
  use base64
  use zlib
  use DAMASK_interface
  use IO
  use config
  use results
  use discretization
  use geometry_plastic_nonlocal
  use FEsolving

  implicit none
  private

  integer,     dimension(3), public, protected :: &
    grid                                                                                            !< (global) grid
  integer,                   public, protected :: &
    grid3, &                                                                                        !< (local) grid in 3rd direction
    grid3Offset                                                                                     !< (local) grid offset in 3rd direction
  real(pReal), dimension(3), public, protected :: &
    geomSize                                                                                        !< (global) physical size
  real(pReal),               public, protected :: &
    size3, &                                                                                        !< (local) size in 3rd direction
    size3offset                                                                                     !< (local) size offset in 3rd direction

  public :: &
    discretization_grid_init

contains


!--------------------------------------------------------------------------------------------------
!> @brief reads the geometry file to obtain information on discretization
!--------------------------------------------------------------------------------------------------
subroutine discretization_grid_init(restart)

  logical, intent(in) :: restart

  include 'fftw3-mpi.f03'
  real(pReal), dimension(3) :: &
    mySize, &                                                                                       !< domain size of this process
    origin                                                                                          !< (global) distance to origin
  integer,     dimension(3) :: &
    myGrid                                                                                          !< domain grid of this process

  integer,     dimension(:),   allocatable :: &
    microstructureAt

  integer :: &
    j, &
    debug_element, &
    debug_ip
  integer(C_INTPTR_T) :: &
    devNull, z, z_offset

  write(6,'(/,a)') ' <<<+-  discretization_grid init  -+>>>'; flush(6)

  if(index(geometryFile,'.vtr') /= 0) then
    call readVTR(grid,geomSize,origin,microstructureAt)
  else
    call readGeom(grid,geomSize,origin,microstructureAt)
  endif

!--------------------------------------------------------------------------------------------------
! grid solver specific quantities
  if(worldsize>grid(3)) call IO_error(894, ext_msg='number of processes exceeds grid(3)')

  call fftw_mpi_init
  devNull = fftw_mpi_local_size_3d(int(grid(3),C_INTPTR_T), &
                                   int(grid(2),C_INTPTR_T), &
                                   int(grid(1),C_INTPTR_T)/2+1, &
                                   PETSC_COMM_WORLD, &
                                   z, &                                                             ! domain grid size along z
                                   z_offset)                                                        ! domain grid offset along z
  grid3       = int(z)
  grid3Offset = int(z_offset)
  size3       = geomSize(3)*real(grid3,pReal)      /real(grid(3),pReal)
  size3Offset = geomSize(3)*real(grid3Offset,pReal)/real(grid(3),pReal)
  myGrid = [grid(1:2),grid3]
  mySize = [geomSize(1:2),size3]

!-------------------------------------------------------------------------------------------------
! debug parameters
  debug_element = debug_root%get_asInt('element',defaultVal=1)
  debug_ip      = debug_root%get_asInt('integrationpoint',defaultVal=1)

!--------------------------------------------------------------------------------------------------
! general discretization
  microstructureAt = microstructureAt(product(grid(1:2))*grid3Offset+1: &
                                      product(grid(1:2))*(grid3Offset+grid3))                       ! reallocate/shrink in case of MPI

  call discretization_init(microstructureAt, &
                           IPcoordinates0(myGrid,mySize,grid3Offset), &
                           Nodes0(myGrid,mySize,grid3Offset),&
                           merge((grid(1)+1) * (grid(2)+1) * (grid3+1),&                            ! write bottom layer
                                 (grid(1)+1) * (grid(2)+1) *  grid3,&                               ! do not write bottom layer (is top of rank-1)
                                 worldrank<1))

  FEsolving_execElem = [1,product(myGrid)]                                                          ! parallel loop bounds set to comprise all elements
  FEsolving_execIP   = [1,1]                                                                        ! parallel loop bounds set to comprise the only IP

!--------------------------------------------------------------------------------------------------
! store geometry information for post processing
  if(.not. restart) then
    call results_openJobFile
    call results_closeGroup(results_addGroup('geometry'))
    call results_addAttribute('grid',  grid,    'geometry')
    call results_addAttribute('size',  geomSize,'geometry')
    call results_addAttribute('origin',origin,  'geometry')
    call results_closeJobFile
  endif

!--------------------------------------------------------------------------------------------------
! geometry information required by the nonlocal CP model
  call geometry_plastic_nonlocal_setIPvolume(reshape([(product(mySize/real(myGrid,pReal)),j=1,product(myGrid))], &
                                                     [1,product(myGrid)]))
  call geometry_plastic_nonlocal_setIParea        (cellSurfaceArea(mySize,myGrid))
  call geometry_plastic_nonlocal_setIPareaNormal  (cellSurfaceNormal(product(myGrid)))
  call geometry_plastic_nonlocal_setIPneighborhood(IPneighborhood(myGrid))

!--------------------------------------------------------------------------------------------------
! sanity checks for debugging
  if (debug_element < 1 .or. debug_element > product(myGrid)) call IO_error(602,ext_msg='element')  ! selected element does not exist
  if (debug_ip /= 1)                                          call IO_error(602,ext_msg='IP')       ! selected IP does not exist

end subroutine discretization_grid_init


!--------------------------------------------------------------------------------------------------
!> @brief Parses geometry file
!> @details important variables have an implicit "save" attribute. Therefore, this function is
! supposed to be called only once!
!--------------------------------------------------------------------------------------------------
subroutine readGeom(grid,geomSize,origin,microstructure)

  integer,     dimension(3), intent(out) :: &
    grid                                                                                            ! grid (for all processes!)
  real(pReal), dimension(3), intent(out) :: &
    geomSize, &                                                                                     ! size (for all processes!)
    origin                                                                                          ! origin (for all processes!)
  integer,     dimension(:), intent(out), allocatable :: &
    microstructure

  character(len=:),      allocatable :: rawData
  character(len=65536)               :: line
  integer, allocatable, dimension(:) :: chunkPos
  integer :: &
    headerLength = -1, &                                                                            !< length of header (in lines)
    fileLength, &                                                                                   !< length of the geom file (in characters)
    fileUnit, &
    startPos, endPos, &
    myStat, &
    l, &                                                                                            !< line counter
    c, &                                                                                            !< counter for # microstructures in line
    o, &                                                                                            !< order of "to" packing
    e, &                                                                                            !< "element", i.e. spectral collocation point
    i, j

  grid = -1
  geomSize = -1.0_pReal

!--------------------------------------------------------------------------------------------------
! read raw data as stream
  inquire(file = trim(geometryFile), size=fileLength)
  open(newunit=fileUnit, file=trim(geometryFile), access='stream',&
       status='old', position='rewind', action='read',iostat=myStat)
  if(myStat /= 0) call IO_error(100,ext_msg=trim(geometryFile))
  allocate(character(len=fileLength)::rawData)
  read(fileUnit) rawData
  close(fileUnit)

!--------------------------------------------------------------------------------------------------
! get header length
  endPos = index(rawData,IO_EOL)
  if(endPos <= index(rawData,'head')) then                                                          ! ToDo: Should be 'header'
    startPos = len(rawData)
    call IO_error(error_ID=841, ext_msg='readGeom')
  else
    chunkPos = IO_stringPos(rawData(1:endPos))
    if (chunkPos(1) < 2) call IO_error(error_ID=841, ext_msg='readGeom')
    headerLength = IO_intValue(rawData(1:endPos),chunkPos,1)
    startPos = endPos + 1
  endif

!--------------------------------------------------------------------------------------------------
! read and interprete header
  origin = 0.0_pReal
  l = 0
  do while (l < headerLength .and. startPos < len(rawData))
    endPos = startPos + index(rawData(startPos:),IO_EOL) - 1
    if (endPos < startPos) endPos = len(rawData)                                                    ! end of file without new line
    line = rawData(startPos:endPos)
    startPos = endPos + 1
    l = l + 1

    chunkPos = IO_stringPos(trim(line))
    if (chunkPos(1) < 2) cycle                                                                      ! need at least one keyword value pair

    select case (IO_lc(IO_StringValue(trim(line),chunkPos,1)) )
      case ('grid')
        if (chunkPos(1) > 6) then
          do j = 2,6,2
            select case (IO_lc(IO_stringValue(line,chunkPos,j)))
              case('a')
                grid(1) = IO_intValue(line,chunkPos,j+1)
              case('b')
                grid(2) = IO_intValue(line,chunkPos,j+1)
              case('c')
                grid(3) = IO_intValue(line,chunkPos,j+1)
            end select
          enddo
        endif

      case ('size')
        if (chunkPos(1) > 6) then
          do j = 2,6,2
            select case (IO_lc(IO_stringValue(line,chunkPos,j)))
              case('x')
                geomSize(1) = IO_floatValue(line,chunkPos,j+1)
              case('y')
                geomSize(2) = IO_floatValue(line,chunkPos,j+1)
              case('z')
                geomSize(3) = IO_floatValue(line,chunkPos,j+1)
            end select
          enddo
        endif

      case ('origin')
        if (chunkPos(1) > 6) then
          do j = 2,6,2
            select case (IO_lc(IO_stringValue(line,chunkPos,j)))
              case('x')
                origin(1) = IO_floatValue(line,chunkPos,j+1)
              case('y')
                origin(2) = IO_floatValue(line,chunkPos,j+1)
              case('z')
                origin(3) = IO_floatValue(line,chunkPos,j+1)
            end select
          enddo
        endif

    end select

  enddo

!--------------------------------------------------------------------------------------------------
! sanity checks
  if(any(grid < 1)) &
    call IO_error(error_ID = 842, ext_msg='grid (readGeom)')
  if(any(geomSize < 0.0_pReal)) &
    call IO_error(error_ID = 842, ext_msg='size (readGeom)')

  allocate(microstructure(product(grid)), source = -1)                                              ! too large in case of MPI (shrink later, not very elegant)

!--------------------------------------------------------------------------------------------------
! read and interpret content
  e = 1
  do while (startPos < len(rawData))
    endPos = startPos + index(rawData(startPos:),IO_EOL) - 1
    if (endPos < startPos) endPos = len(rawData)                                                    ! end of file without new line
    line = rawData(startPos:endPos)
    startPos = endPos + 1
    l = l + 1
    chunkPos = IO_stringPos(trim(line))

    noCompression: if (chunkPos(1) /= 3) then
      c = chunkPos(1)
      microstructure(e:e+c-1) =  [(IO_intValue(line,chunkPos,i+1), i=0, c-1)]
    else noCompression
      compression: if (IO_lc(IO_stringValue(line,chunkPos,2))  == 'of') then
        c = IO_intValue(line,chunkPos,1)
        microstructure(e:e+c-1) = [(IO_intValue(line,chunkPos,3),i = 1,IO_intValue(line,chunkPos,1))]
      else         if (IO_lc(IO_stringValue(line,chunkPos,2))  == 'to') then compression
        c = abs(IO_intValue(line,chunkPos,3) - IO_intValue(line,chunkPos,1)) + 1
        o = merge(+1, -1, IO_intValue(line,chunkPos,3) > IO_intValue(line,chunkPos,1))
        microstructure(e:e+c-1) = [(i, i = IO_intValue(line,chunkPos,1),IO_intValue(line,chunkPos,3),o)]
      else compression
        c = chunkPos(1)
        microstructure(e:e+c-1) = [(IO_intValue(line,chunkPos,i+1), i=0, c-1)]
      endif compression
    endif noCompression

    e = e+c
  end do

  if (e-1 /= product(grid)) call IO_error(error_ID = 843, el=e)

end subroutine readGeom


!--------------------------------------------------------------------------------------------------
!> @brief Parse vtk rectilinear grid (.vtr)
!> @details https://vtk.org/Wiki/VTK_XML_Formats
!--------------------------------------------------------------------------------------------------
subroutine readVTR(grid,geomSize,origin,microstructure)

  integer,     dimension(3), intent(out) :: &
    grid                                                                                            ! grid (for all processes!)
  real(pReal), dimension(3), intent(out) :: &
    geomSize, &                                                                                     ! size (for all processes!)
    origin                                                                                          ! origin (for all processes!)
  integer,     dimension(:), intent(out), allocatable :: &
    microstructure

  character(len=:), allocatable :: fileContent, data_type, header_type
  logical :: inFile,inGrid,readCoordinates,readCellData,compressed
  integer :: fileUnit, myStat, coord
  integer(pI64) :: &
    fileLength, &                                                                                   !< length of the geom file (in characters)
    startPos, endPos, &
    s

  grid = -1
  geomSize = -1.0_pReal

!--------------------------------------------------------------------------------------------------
! read raw data as stream
  inquire(file = trim(geometryFile), size=fileLength)
  open(newunit=fileUnit, file=trim(geometryFile), access='stream',&
       status='old', position='rewind', action='read',iostat=myStat)
  if(myStat /= 0) call IO_error(100,ext_msg=trim(geometryFile))
  allocate(character(len=fileLength)::fileContent)
  read(fileUnit) fileContent
  close(fileUnit)

  inFile          = .false.
  inGrid          = .false.
  readCoordinates = .false.
  readCelldata    = .false.

!--------------------------------------------------------------------------------------------------
! interprete XML file
  startPos = 1_pI64
  do while (startPos < len(fileContent,kind=pI64))
    endPos = startPos + index(fileContent(startPos:),IO_EOL,kind=pI64) - 2_pI64
    if (endPos < startPos) endPos = len(fileContent,kind=pI64)                                      ! end of file without new line

    if(.not. inFile) then
      if(index(fileContent(startPos:endPos),'<VTKFile',kind=pI64) /= 0_pI64) then
        inFile = .true.
        if(.not. fileOk(fileContent(startPos:endPos))) call IO_error(error_ID = 844, ext_msg='file format')
        header_type = merge('UInt64','UInt32',getXMLValue(fileContent(startPos:endPos),'header_type')=='UInt64')
        compressed  = getXMLValue(fileContent(startPos:endPos),'compressor') == 'vtkZLibDataCompressor'
      endif
    else
      if(.not. inGrid) then
        if(index(fileContent(startPos:endPos),'<RectilinearGrid',kind=pI64) /= 0_pI64) then
          inGrid = .true.
          grid = getGrid(fileContent(startPos:endPos))
        endif
      else
        if(index(fileContent(startPos:endPos),'<CellData>',kind=pI64) /= 0_pI64) then
          readCellData = .true.
          startPos = endPos + 2_pI64
          do while (index(fileContent(startPos:endPos),'</CellData>',kind=pI64) == 0_pI64)
            endPos = startPos + index(fileContent(startPos:),IO_EOL,kind=pI64) - 2_pI64
            if(index(fileContent(startPos:endPos),'<DataArray',kind=pI64) /= 0_pI64 .and. &
                 getXMLValue(fileContent(startPos:endPos),'Name') == 'materialpoint' ) then

              if(getXMLValue(fileContent(startPos:endPos),'format') /= 'binary') &
                call IO_error(error_ID = 844, ext_msg='format (materialpoint)')
              data_type = getXMLValue(fileContent(startPos:endPos),'type')

              startPos = endPos + 2_pI64
              endPos  = startPos + index(fileContent(startPos:),IO_EOL,kind=pI64) - 2_pI64
              s = startPos + verify(fileContent(startPos:endPos),IO_WHITESPACE,kind=pI64) -1_pI64   ! start (no leading whitespace)
              microstructure = as_Int(fileContent(s:endPos),header_type,compressed,data_type)
              exit
            endif
            startPos = endPos + 2_pI64
          enddo
        elseif(index(fileContent(startPos:endPos),'<Coordinates>',kind=pI64) /= 0_pI64) then
          readCoordinates = .true.
          startPos = endPos + 2_pI64

          coord = 0
          do while (startPos<fileLength)
            endPos = startPos + index(fileContent(startPos:),IO_EOL,kind=pI64) - 2_pI64
            if(index(fileContent(startPos:endPos),'<DataArray',kind=pI64) /= 0_pI64) then

              if(getXMLValue(fileContent(startPos:endPos),'format') /= 'binary') &
                call IO_error(error_ID = 844, ext_msg='format (coordinates)')
              data_type = getXMLValue(fileContent(startPos:endPos),'type')

              startPos = endPos + 2_pI64
              endPos  = startPos + index(fileContent(startPos:),IO_EOL,kind=pI64) - 2_pI64
              s = startPos + verify(fileContent(startPos:endPos),IO_WHITESPACE,kind=pI64) -1_pI64   ! start (no leading whitespace)

              coord = coord + 1

              call origin_and_size(fileContent(s:endPos),header_type,compressed,data_type,coord)
            endif
            if(index(fileContent(startPos:endPos),'</Coordinates>',kind=pI64) /= 0_pI64) exit
            startPos = endPos + 2_pI64
          enddo
        endif
      endif
    endif

    if(readCellData .and. readCoordinates) exit
    startPos = endPos + 2_pI64

  end do

  if(.not. allocated(microstructure))       call IO_error(error_ID = 844, ext_msg='materialpoint not found')
  if(size(microstructure) /= product(grid)) call IO_error(error_ID = 844, ext_msg='size(materialpoint)')
  if(any(geomSize<=0))                      call IO_error(error_ID = 844, ext_msg='size')
  if(any(grid<1))                           call IO_error(error_ID = 844, ext_msg='grid')

  contains

  !------------------------------------------------------------------------------------------------
  !> @brief determine size and origin from coordinates
  !------------------------------------------------------------------------------------------------
  !ToDo: check for regular spacing
  subroutine origin_and_size(base64_str,header_type,compressed,data_type,direction)

    character(len=*), intent(in) :: base64_str, &                                                   ! base64 encoded string of 1D coordinates
                                    header_type, &                                                  ! header type (UInt32 or Uint64)
                                    data_type                                                       ! data type (Int32, Int64, Float32, Float64)
    logical,          intent(in) :: compressed                                                      ! indicate whether data is zlib compressed
    integer,          intent(in) :: direction                                                       ! direction (1=x,2=y,3=z)

    real(pReal), dimension(:), allocatable :: coords

    coords = as_pReal(base64_str,header_type,compressed,data_type)
    origin(direction) = coords(1)
    geomSize(direction) = coords(size(coords)) - coords(1)

  end subroutine


  !------------------------------------------------------------------------------------------------
  !> @brief Interpret Base64 string in vtk XML file as integer of default kind
  !------------------------------------------------------------------------------------------------
  function as_Int(base64_str,header_type,compressed,data_type)

    character(len=*), intent(in) :: base64_str, &                                                   ! base64 encoded string
                                    header_type, &                                                  ! header type (UInt32 or Uint64)
                                    data_type                                                       ! data type (Int32, Int64, Float32, Float64)
    logical,          intent(in) :: compressed                                                      ! indicate whether data is zlib compressed

    integer, dimension(:), allocatable :: as_Int

    select case(data_type)
      case('Int32')
        as_Int = int(bytes_to_C_INT32_T(asBytes(base64_str,header_type,compressed)))
      case('Int64')
        as_Int = int(bytes_to_C_INT64_T(asBytes(base64_str,header_type,compressed)))
      case('Float32')
        as_Int = int(bytes_to_C_FLOAT  (asBytes(base64_str,header_type,compressed)))
      case('Float64')
        as_Int = int(bytes_to_C_DOUBLE (asBytes(base64_str,header_type,compressed)))
      case default
        call IO_error(844_pInt,ext_msg='unknown data type: '//trim(data_type))
    end select

  end function as_Int


  !------------------------------------------------------------------------------------------------
  !> @brief Interpret Base64 string in vtk XML file as integer of pReal kind
  !------------------------------------------------------------------------------------------------
  function as_pReal(base64_str,header_type,compressed,data_type)

    character(len=*), intent(in) :: base64_str, &                                                   ! base64 encoded string
                                    header_type, &                                                  ! header type (UInt32 or Uint64)
                                    data_type                                                       ! data type (Int32, Int64, Float32, Float64)
    logical,          intent(in) :: compressed                                                      ! indicate whether data is zlib compressed

    real(pReal), dimension(:), allocatable :: as_pReal

    select case(data_type)
      case('Int32')
        as_pReal = real(bytes_to_C_INT32_T(asBytes(base64_str,header_type,compressed)),pReal)
      case('Int64')
        as_pReal = real(bytes_to_C_INT64_T(asBytes(base64_str,header_type,compressed)),pReal)
      case('Float32')
        as_pReal = real(bytes_to_C_FLOAT  (asBytes(base64_str,header_type,compressed)),pReal)
      case('Float64')
        as_pReal = real(bytes_to_C_DOUBLE (asBytes(base64_str,header_type,compressed)),pReal)
      case default
        call IO_error(844_pInt,ext_msg='unknown data type: '//trim(data_type))
    end select

  end function as_pReal


  !------------------------------------------------------------------------------------------------
  !> @brief Interpret Base64 string in vtk XML file as bytes
  !------------------------------------------------------------------------------------------------
  function asBytes(base64_str,header_type,compressed) result(bytes)

    character(len=*), intent(in) :: base64_str, &                                                   ! base64 encoded string
                                    header_type                                                     ! header type (UInt32 or Uint64)
    logical,          intent(in) :: compressed                                                      ! indicate whether data is zlib compressed

    integer(C_SIGNED_CHAR), dimension(:), allocatable :: bytes

    if(compressed) then
      bytes = asBytes_compressed(base64_str,header_type)
    else
      bytes = asBytes_uncompressed(base64_str,header_type)
    endif

  end function asBytes

  !------------------------------------------------------------------------------------------------
  !> @brief Interpret compressed Base64 string in vtk XML file as bytes
  !> @details A compressed Base64 string consists of a header block and a data block
  ! [#blocks/#u-size/#p-size/#c-size-1/#c-size-2/.../#c-size-#blocks][DATA-1/DATA-2...]
  ! #blocks = Number of blocks
  ! #u-size = Block size before compression
  ! #p-size = Size of last partial block (zero if it not needed)
  ! #c-size-i = Size in bytes of block i after compression
  !------------------------------------------------------------------------------------------------
  function asBytes_compressed(base64_str,header_type) result(bytes)

    character(len=*), intent(in) :: base64_str, &                                                   ! base64 encoded string
                                    header_type                                                     ! header type (UInt32 or Uint64)

    integer(C_SIGNED_CHAR), dimension(:), allocatable :: bytes, bytes_inflated

    integer(pI64), dimension(:), allocatable :: temp, size_inflated, size_deflated
    integer(pI64) :: header_len, N_blocks, b,s,e

    if    (header_type == 'UInt32') then
      temp = int(bytes_to_C_INT32_T(base64_to_bytes(base64_str(:base64_nChar(4_pI64)))),pI64)
      N_blocks = int(temp(1),pI64)
      header_len = 4_pI64 * (3_pI64 + N_blocks)
      temp = int(bytes_to_C_INT32_T(base64_to_bytes(base64_str(:base64_nChar(header_len)))),pI64)
    elseif(header_type == 'UInt64') then
      temp = int(bytes_to_C_INT64_T(base64_to_bytes(base64_str(:base64_nChar(8_pI64)))),pI64)
      N_blocks = int(temp(1),pI64)
      header_len = 8_pI64 * (3_pI64 + N_blocks)
      temp = int(bytes_to_C_INT64_T(base64_to_bytes(base64_str(:base64_nChar(header_len)))),pI64)
    endif

    allocate(size_inflated(N_blocks),source=temp(2))
    size_inflated(N_blocks) = merge(temp(3),temp(2),temp(3)/=0_pI64)
    size_deflated = temp(4:)
    bytes_inflated = base64_to_bytes(base64_str(base64_nChar(header_len)+1_pI64:))

    allocate(bytes(0))
    e = 0_pI64
    do b = 1, N_blocks
      s = e + 1_pI64
      e = s + size_deflated(b) - 1_pI64
      bytes = [bytes,zlib_inflate(bytes_inflated(s:e),size_inflated(b))]
    enddo

  end function asBytes_compressed


  !------------------------------------------------------------------------------------------------
  !> @brief Interprete uncompressed Base64 string in vtk XML file as bytes
  !> @details An uncompressed Base64 string consists of N headers blocks and a N data blocks
  ![#bytes-1/DATA-1][#bytes-2/DATA-2]...
  !------------------------------------------------------------------------------------------------
  function asBytes_uncompressed(base64_str,header_type) result(bytes)

    character(len=*), intent(in) :: base64_str, &                                                   ! base64 encoded string
                                    header_type                                                     ! header type (UInt32 or Uint64)

    integer(pI64) :: s
    integer(pI64), dimension(1) :: N_bytes

    integer(C_SIGNED_CHAR), dimension(:), allocatable :: bytes
    allocate(bytes(0))

    s=0_pI64
    if    (header_type == 'UInt32') then
      do while(s+base64_nChar(4_pI64)<(len(base64_str,pI64)))
        N_bytes = int(bytes_to_C_INT32_T(base64_to_bytes(base64_str(s+1_pI64:s+base64_nChar(4_pI64)))),pI64)
        bytes = [bytes,base64_to_bytes(base64_str(s+1_pI64:s+base64_nChar(4_pI64+N_bytes(1))),5_pI64)]
        s = s + base64_nChar(4_pI64+N_bytes(1))
      enddo
    elseif(header_type == 'UInt64') then
      do while(s+base64_nChar(8_pI64)<(len(base64_str,pI64)))
        N_bytes = int(bytes_to_C_INT64_T(base64_to_bytes(base64_str(s+1_pI64:s+base64_nChar(8_pI64)))),pI64)
        bytes = [bytes,base64_to_bytes(base64_str(s+1_pI64:s+base64_nChar(8_pI64+N_bytes(1))),9_pI64)]
        s = s + base64_nChar(8_pI64+N_bytes(1))
      enddo
    endif

  end function asBytes_uncompressed

  !------------------------------------------------------------------------------------------------
  !> @brief Get XML string value for given key
  !------------------------------------------------------------------------------------------------
  ! ToDo: check if "=" is between key and value
  pure function getXMLValue(line,key)

    character(len=*), intent(in)  :: line, key

    character(len=:), allocatable :: getXMLValue

    integer :: s,e
#ifdef __INTEL_COMPILER
    character :: q
#endif

    s = index(line," "//key,back=.true.)
    if(s==0) then
      getXMLValue = ''
    else
      s = s + 1 + scan(line(s+1:),"'"//'"')
#ifdef __INTEL_COMPILER
      q = line(s-1:s-1)
      e = s + index(line(s:),q) - 1
#else
      e = s + index(line(s:),merge("'",'"',line(s-1:s-1)=="'")) - 1
#endif
      getXMLValue = line(s:e-1)
    endif

  end function


  !------------------------------------------------------------------------------------------------
  !> @brief figure out if file format is understandable
  !------------------------------------------------------------------------------------------------
  pure function fileOk(line)

    character(len=*),intent(in) :: line
    logical :: fileOk

    fileOk = getXMLValue(line,'type')       == 'RectilinearGrid' .and. &
             getXMLValue(line,'byte_order') == 'LittleEndian' .and. &
             getXMLValue(line,'compressor') /= 'vtkLZ4DataCompressor' .and. &
             getXMLValue(line,'compressor') /= 'vtkLZMADataCompressor'

  end function fileOk


  !------------------------------------------------------------------------------------------------
  !> @brief get grid information from '<RectilinearGrid WholeExtent="0 x 0 y 0 z">'
  !------------------------------------------------------------------------------------------------
  function getGrid(line)

    character(len=*),intent(in) :: line

    integer,dimension(3) :: getGrid

    integer :: s,e,i

    s=scan(line,'"'//"'",back=.False.)
    e=scan(line,'"'//"'",back=.True.)

    getGrid = [(IO_intValue(line(s+1:e-1),IO_stringPos(line(s+1:e-1)),i*2),i=1,3)]

  end function getGrid

end subroutine readVTR


!---------------------------------------------------------------------------------------------------
!> @brief Calculate undeformed position of IPs/cell centers (pretend to be an element)
!---------------------------------------------------------------------------------------------------
function IPcoordinates0(grid,geomSize,grid3Offset)

  integer,     dimension(3), intent(in) :: grid                                                     ! grid (for this process!)
  real(pReal), dimension(3), intent(in) :: geomSize                                                 ! size (for this process!)
  integer,                   intent(in) :: grid3Offset                                              ! grid(3) offset

  real(pReal), dimension(3,product(grid))  :: ipCoordinates0

  integer :: &
    a,b,c, &
    i

  i = 0
  do c = 1, grid(3); do b = 1, grid(2); do a = 1, grid(1)
    i = i + 1
    IPcoordinates0(1:3,i) = geomSize/real(grid,pReal) * (real([a,b,grid3Offset+c],pReal) -0.5_pReal)
  enddo; enddo; enddo

end function IPcoordinates0


!---------------------------------------------------------------------------------------------------
!> @brief Calculate position of undeformed nodes (pretend to be an element)
!---------------------------------------------------------------------------------------------------
pure function nodes0(grid,geomSize,grid3Offset)

  integer,     dimension(3), intent(in) :: grid                                                     ! grid (for this process!)
  real(pReal), dimension(3), intent(in) :: geomSize                                                 ! size (for this process!)
  integer,                   intent(in) :: grid3Offset                                              ! grid(3) offset

  real(pReal), dimension(3,product(grid+1)) :: nodes0

  integer :: &
    a,b,c, &
    n

  n = 0
  do c = 0, grid3; do b = 0, grid(2); do a = 0, grid(1)
    n = n + 1
    nodes0(1:3,n) = geomSize/real(grid,pReal) * real([a,b,grid3Offset+c],pReal)
  enddo; enddo; enddo

end function nodes0


!--------------------------------------------------------------------------------------------------
!> @brief Calculate IP interface areas
!--------------------------------------------------------------------------------------------------
pure function cellSurfaceArea(geomSize,grid)

  real(pReal), dimension(3), intent(in) :: geomSize                                                 ! size (for this process!)
  integer,     dimension(3), intent(in) :: grid                                                     ! grid (for this process!)

  real(pReal), dimension(6,1,product(grid)) :: cellSurfaceArea

  cellSurfaceArea(1:2,1,:) = geomSize(2)/real(grid(2)) * geomSize(3)/real(grid(3))
  cellSurfaceArea(3:4,1,:) = geomSize(3)/real(grid(3)) * geomSize(1)/real(grid(1))
  cellSurfaceArea(5:6,1,:) = geomSize(1)/real(grid(1)) * geomSize(2)/real(grid(2))

end function cellSurfaceArea


!--------------------------------------------------------------------------------------------------
!> @brief Calculate IP interface areas normals
!--------------------------------------------------------------------------------------------------
pure function cellSurfaceNormal(nElems)

  integer, intent(in) :: nElems

  real(pReal), dimension(3,6,1,nElems) :: cellSurfaceNormal

  cellSurfaceNormal(1:3,1,1,:) = spread([+1.0_pReal, 0.0_pReal, 0.0_pReal],2,nElems)
  cellSurfaceNormal(1:3,2,1,:) = spread([-1.0_pReal, 0.0_pReal, 0.0_pReal],2,nElems)
  cellSurfaceNormal(1:3,3,1,:) = spread([ 0.0_pReal,+1.0_pReal, 0.0_pReal],2,nElems)
  cellSurfaceNormal(1:3,4,1,:) = spread([ 0.0_pReal,-1.0_pReal, 0.0_pReal],2,nElems)
  cellSurfaceNormal(1:3,5,1,:) = spread([ 0.0_pReal, 0.0_pReal,+1.0_pReal],2,nElems)
  cellSurfaceNormal(1:3,6,1,:) = spread([ 0.0_pReal, 0.0_pReal,-1.0_pReal],2,nElems)

end function cellSurfaceNormal


!--------------------------------------------------------------------------------------------------
!> @brief Build IP neighborhood relations
!--------------------------------------------------------------------------------------------------
pure function IPneighborhood(grid)

  integer, dimension(3), intent(in) :: grid                                                         ! grid (for this process!)

  integer, dimension(3,6,1,product(grid)) :: IPneighborhood                                         !< 6 neighboring IPs as [element ID, IP ID, face ID]

  integer :: &
   x,y,z, &
   e

  e = 0
  do z = 0,grid(3)-1; do y = 0,grid(2)-1; do x = 0,grid(1)-1
    e = e + 1
    ! element ID
    IPneighborhood(1,1,1,e) = z * grid(1) * grid(2) &
                            + y * grid(1) &
                            + modulo(x+1,grid(1)) &
                            + 1
    IPneighborhood(1,2,1,e) = z * grid(1) * grid(2) &
                            + y * grid(1) &
                            + modulo(x-1,grid(1)) &
                            + 1
    IPneighborhood(1,3,1,e) = z * grid(1) * grid(2) &
                            + modulo(y+1,grid(2)) * grid(1) &
                            + x &
                            + 1
    IPneighborhood(1,4,1,e) = z * grid(1) * grid(2) &
                            + modulo(y-1,grid(2)) * grid(1) &
                            + x &
                            + 1
    IPneighborhood(1,5,1,e) = modulo(z+1,grid(3)) * grid(1) * grid(2) &
                            + y * grid(1) &
                            + x &
                            + 1
    IPneighborhood(1,6,1,e) = modulo(z-1,grid(3)) * grid(1) * grid(2) &
                            + y * grid(1) &
                            + x &
                            + 1
    ! IP ID
    IPneighborhood(2,:,1,e) = 1

    ! face ID
    IPneighborhood(3,1,1,e) = 2
    IPneighborhood(3,2,1,e) = 1
    IPneighborhood(3,3,1,e) = 4
    IPneighborhood(3,4,1,e) = 3
    IPneighborhood(3,5,1,e) = 6
    IPneighborhood(3,6,1,e) = 5

  enddo; enddo; enddo

end function IPneighborhood


end module discretization_grid
