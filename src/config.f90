!--------------------------------------------------------------------------------------------------
!> @author Martin Diehl, Max-Planck-Institut für Eisenforschung GmbH
!> @brief Read in the material and numerics configuration from their respective file.
!--------------------------------------------------------------------------------------------------
module config
  use IO
  use YAML_parse
  use YAML_types
  use result
  use parallelization

  implicit none(type,external)
  private

  type(tDict), pointer, public :: &
    config_material, &
    config_numerics

  public :: &
    config_init, &
    config_deallocate

contains

!--------------------------------------------------------------------------------------------------
!> @brief Read *.yaml configuration files.
!--------------------------------------------------------------------------------------------------
subroutine config_init()

  print'(/,1x,a)', '<<<+-  config init  -+>>>'; flush(IO_STDOUT)

  call parse_material()
  call parse_numerics()

end subroutine config_init


!--------------------------------------------------------------------------------------------------
!> @brief Read material.yaml.
!--------------------------------------------------------------------------------------------------
subroutine parse_material()

  logical :: fileExists
  character(len=:), allocatable :: fileContent


  inquire(file='material.yaml',exist=fileExists)
  if (.not. fileExists) call IO_error(100,ext_msg='material.yaml')

  if (worldrank == 0) then
    print'(/,1x,a)', 'reading material.yaml'; flush(IO_STDOUT)
    fileContent = IO_read('material.yaml')
    call result_openJobFile(parallel=.false.)
    call result_writeDataset_str(fileContent,'setup','material.yaml','main configuration')
    call result_closeJobFile()
  end if
  call parallelization_bcast_str(fileContent)

  config_material => YAML_parse_str_asDict(fileContent)

end subroutine parse_material


!--------------------------------------------------------------------------------------------------
!> @brief Read numerics.yaml.
!--------------------------------------------------------------------------------------------------
subroutine parse_numerics()

  logical :: fileExists
  character(len=:), allocatable :: fileContent


  config_numerics => emptyDict

  inquire(file='numerics.yaml', exist=fileExists)
  if (fileExists) then

    if (worldrank == 0) then
      print'(1x,a)', 'reading numerics.yaml'; flush(IO_STDOUT)
      fileContent = IO_read('numerics.yaml')
      if (len(fileContent) > 0) then
        call result_openJobFile(parallel=.false.)
        call result_writeDataset_str(fileContent,'setup','numerics.yaml','numerics configuration')
        call result_closeJobFile()
      end if
    end if
    call parallelization_bcast_str(fileContent)

    config_numerics => YAML_parse_str_asDict(fileContent)

  end if

end subroutine parse_numerics


!--------------------------------------------------------------------------------------------------
!> @brief Deallocate config_material.
!ToDo: deallocation of numerics (optional)
!--------------------------------------------------------------------------------------------------
subroutine config_deallocate

  deallocate(config_material)

end subroutine config_deallocate

end module config
