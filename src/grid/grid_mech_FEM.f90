!--------------------------------------------------------------------------------------------------
!> @author Arko Jyoti Bhattacharjee, Max-Planck-Institut für Eisenforschung GmbH
!> @author Martin Diehl, Max-Planck-Institut für Eisenforschung GmbH
!> @author Pratheek Shanthraj, Max-Planck-Institut für Eisenforschung GmbH
!> @brief Grid solver for mechanics: FEM
!--------------------------------------------------------------------------------------------------
module grid_mech_FEM
#include <petsc/finclude/petscsnes.h>
#include <petsc/finclude/petscdmda.h>
  use DAMASK_interface
  use HDF5_utilities
  use PETScdmda
  use PETScsnes
  use prec
  use CPFEM2
  use IO
  use debug
  use FEsolving
  use numerics
  use homogenization
  use DAMASK_interface
  use spectral_utilities
  use discretization
  use mesh_grid
  use math
 
  implicit none
  private
   
!--------------------------------------------------------------------------------------------------
! derived types
  type(tSolutionParams), private :: params

!--------------------------------------------------------------------------------------------------
! PETSc data
  DM,   private :: mech_grid
  SNES, private :: mech_snes
  Vec,  private :: solution_current, solution_lastInc, solution_rate

!--------------------------------------------------------------------------------------------------
! common pointwise data
  real(pReal), private, dimension(:,:,:,:,:), allocatable ::  F, P_current, F_lastInc
  real(pReal), private :: detJ
  real(pReal), private, dimension(3)   :: delta
  real(pReal), private, dimension(3,8) :: BMat
  real(pReal), private, dimension(8,8) :: HGMat
  PetscInt,    private :: xstart,ystart,zstart,xend,yend,zend

!--------------------------------------------------------------------------------------------------
! stress, stiffness and compliance average etc.
  real(pReal), private, dimension(3,3) :: &
    F_aimDot = 0.0_pReal, &                                                                         !< assumed rate of average deformation gradient
    F_aim = math_I3, &                                                                              !< current prescribed deformation gradient
    F_aim_lastIter = math_I3, &
    F_aim_lastInc = math_I3, &                                                                      !< previous average deformation gradient
    P_av = 0.0_pReal                                                                                !< average 1st Piola--Kirchhoff stress
 
  character(len=1024), private :: incInfo                                                           !< time and increment information
 
  real(pReal), private, dimension(3,3,3,3) :: &
    C_volAvg = 0.0_pReal, &                                                                         !< current volume average stiffness 
    C_volAvgLastInc = 0.0_pReal, &                                                                  !< previous volume average stiffness
    S = 0.0_pReal                                                                                   !< current compliance (filled up with zeros)
 
  real(pReal), private :: &
    err_BC                                                                                          !< deviation from stress BC
 
  integer, private :: &
    totalIter = 0                                                                                   !< total iteration in current increment
 
  public :: &
    grid_mech_FEM_init, &
    grid_mech_FEM_solution, &
    grid_mech_FEM_forward, &
    grid_mech_FEM_updateCoords, &
    grid_mech_FEM_restartWrite

contains

!--------------------------------------------------------------------------------------------------
!> @brief allocates all necessary fields and fills them with data, potentially from restart info
!--------------------------------------------------------------------------------------------------
subroutine grid_mech_FEM_init
    
  real(pReal) :: HGCoeff = 0e-2_pReal
  PetscInt, dimension(:), allocatable :: localK
  real(pReal), dimension(3,3) :: &
    temp33_Real = 0.0_pReal
  real(pReal), dimension(4,8) :: &
    HGcomp = reshape([ 1.0_pReal, 1.0_pReal, 1.0_pReal,-1.0_pReal, &
                       1.0_pReal,-1.0_pReal,-1.0_pReal, 1.0_pReal, &
                      -1.0_pReal, 1.0_pReal,-1.0_pReal, 1.0_pReal, &
                      -1.0_pReal,-1.0_pReal, 1.0_pReal,-1.0_pReal, &
                      -1.0_pReal,-1.0_pReal, 1.0_pReal, 1.0_pReal, &
                      -1.0_pReal, 1.0_pReal,-1.0_pReal,-1.0_pReal, &
                       1.0_pReal,-1.0_pReal,-1.0_pReal,-1.0_pReal, &
                       1.0_pReal, 1.0_pReal, 1.0_pReal, 1.0_pReal], [4,8])
  PetscErrorCode :: ierr
  integer :: rank
  integer(HID_T)      :: fileHandle, groupHandle
  character(len=1024) :: rankStr
  real(pReal), dimension(3,3,3,3) :: devNull
  PetscScalar, pointer, dimension(:,:,:,:) :: &
  u_current,u_lastInc
 
  write(6,'(/,a)') ' <<<+-  grid_mech_FEM init  -+>>>'

!--------------------------------------------------------------------------------------------------
! set default and user defined options for PETSc
  call PETScOptionsInsertString(PETSC_NULL_OPTIONS,'-mech_snes_type newtonls -mech_ksp_type fgmres &
                                &-mech_ksp_max_it 25 -mech_pc_type ml -mech_mg_levels_ksp_type chebyshev',ierr)
  CHKERRQ(ierr)
  call PETScOptionsInsertString(PETSC_NULL_OPTIONS,trim(petsc_options),ierr)
  CHKERRQ(ierr)

!--------------------------------------------------------------------------------------------------
! allocate global fields
  allocate(F (3,3,grid(1),grid(2),grid3),source = 0.0_pReal)
  allocate(P_current (3,3,grid(1),grid(2),grid3),source = 0.0_pReal)
  allocate(F_lastInc (3,3,grid(1),grid(2),grid3),source = 0.0_pReal)
    
!--------------------------------------------------------------------------------------------------
! initialize solver specific parts of PETSc
  call SNESCreate(PETSC_COMM_WORLD,mech_snes,ierr); CHKERRQ(ierr)
  call SNESSetOptionsPrefix(mech_snes,'mech_',ierr);CHKERRQ(ierr) 
  allocate(localK(worldsize), source = 0); localK(worldrank+1) = grid3
  do rank = 1, worldsize
    call MPI_Bcast(localK(rank),1,MPI_INTEGER,rank-1,PETSC_COMM_WORLD,ierr)
  enddo  
  call DMDACreate3d(PETSC_COMM_WORLD, &
         DM_BOUNDARY_PERIODIC, DM_BOUNDARY_PERIODIC, DM_BOUNDARY_PERIODIC, &
         DMDA_STENCIL_BOX, &
         grid(1),grid(2),grid(3), &
         1, 1, worldsize, &
         3, 1, &
         [grid(1)],[grid(2)],localK, &
         mech_grid,ierr)
  CHKERRQ(ierr)
  call DMDASetUniformCoordinates(mech_grid,0.0_pReal,geomSize(1),0.0_pReal,geomSize(2),0.0_pReal,geomSize(3),ierr)
  CHKERRQ(ierr)
  call SNESSetDM(mech_snes,mech_grid,ierr); CHKERRQ(ierr)
  call DMsetFromOptions(mech_grid,ierr); CHKERRQ(ierr)
  call DMsetUp(mech_grid,ierr); CHKERRQ(ierr)
  call DMCreateGlobalVector(mech_grid,solution_current,ierr); CHKERRQ(ierr)
  call DMCreateGlobalVector(mech_grid,solution_lastInc,ierr); CHKERRQ(ierr)
  call DMCreateGlobalVector(mech_grid,solution_rate   ,ierr); CHKERRQ(ierr)
  call DMSNESSetFunctionLocal(mech_grid,formResidual,PETSC_NULL_SNES,ierr)
  CHKERRQ(ierr) 
  call DMSNESSetJacobianLocal(mech_grid,formJacobian,PETSC_NULL_SNES,ierr)
  CHKERRQ(ierr)
  call SNESSetConvergenceTest(mech_snes,converged,PETSC_NULL_SNES,PETSC_NULL_FUNCTION,ierr)         ! specify custom convergence check function "_converged"
  CHKERRQ(ierr)
  call SNESSetMaxLinearSolveFailures(mech_snes, huge(1), ierr); CHKERRQ(ierr)                       ! ignore linear solve failures 
  call SNESSetFromOptions(mech_snes,ierr); CHKERRQ(ierr)                                            ! pull it all together with additional cli arguments

!--------------------------------------------------------------------------------------------------
! init fields
  call VecSet(solution_current,0.0_pReal,ierr);CHKERRQ(ierr)
  call VecSet(solution_lastInc,0.0_pReal,ierr);CHKERRQ(ierr)
  call VecSet(solution_rate   ,0.0_pReal,ierr);CHKERRQ(ierr)
  call DMDAVecGetArrayF90(mech_grid,solution_current,u_current,ierr); CHKERRQ(ierr)
  call DMDAVecGetArrayF90(mech_grid,solution_lastInc,u_lastInc,ierr); CHKERRQ(ierr)
 
  call DMDAGetCorners(mech_grid,xstart,ystart,zstart,xend,yend,zend,ierr)                           ! local grid extent
  CHKERRQ(ierr) 
  xend = xstart+xend-1
  yend = ystart+yend-1
  zend = zstart+zend-1
  delta = geomSize/real(grid,pReal)                                                                 ! grid spacing
  detJ = product(delta)                                                                             ! cell volume
 
  BMat = reshape(real([-1.0_pReal/delta(1),-1.0_pReal/delta(2),-1.0_pReal/delta(3), &
                        1.0_pReal/delta(1),-1.0_pReal/delta(2),-1.0_pReal/delta(3), &
                       -1.0_pReal/delta(1), 1.0_pReal/delta(2),-1.0_pReal/delta(3), &
                        1.0_pReal/delta(1), 1.0_pReal/delta(2),-1.0_pReal/delta(3), &
                       -1.0_pReal/delta(1),-1.0_pReal/delta(2), 1.0_pReal/delta(3), &
                        1.0_pReal/delta(1),-1.0_pReal/delta(2), 1.0_pReal/delta(3), &
                       -1.0_pReal/delta(1), 1.0_pReal/delta(2), 1.0_pReal/delta(3), &
                        1.0_pReal/delta(1), 1.0_pReal/delta(2), 1.0_pReal/delta(3)],pReal), [3,8])/4.0_pReal ! shape function derivative matrix
 
  HGMat = matmul(transpose(HGcomp),HGcomp) &
        * HGCoeff*(delta(1)*delta(2) + delta(2)*delta(3) + delta(3)*delta(1))/16.0_pReal            ! hourglass stabilization matrix

!--------------------------------------------------------------------------------------------------
! init fields
  restartRead: if (interface_restartInc > 0) then
    write(6,'(/,a,'//IO_intOut(interface_restartInc)//',a)') &
      'reading values of increment ', interface_restartInc, ' from file'
 
    write(rankStr,'(a1,i0)')'_',worldrank
    fileHandle  = HDF5_openFile(trim(getSolverJobName())//trim(rankStr)//'.hdf5')
    groupHandle = HDF5_openGroup(fileHandle,'solver')
    
    call HDF5_read(groupHandle,F_aim,        'F_aim')
    call HDF5_read(groupHandle,F_aim_lastInc,'F_aim_lastInc')
    call HDF5_read(groupHandle,F_aimDot,     'F_aimDot')
    call HDF5_read(groupHandle,F,            'F')
    call HDF5_read(groupHandle,F_lastInc,    'F_lastInc')
    call HDF5_read(groupHandle,u_current,    'u')
    call HDF5_read(groupHandle,u_lastInc,    'u_lastInc')
    
  elseif (interface_restartInc == 0) then restartRead
    F_lastInc = spread(spread(spread(math_I3,3,grid(1)),4,grid(2)),5,grid3)                         ! initialize to identity
    F         = spread(spread(spread(math_I3,3,grid(1)),4,grid(2)),5,grid3)
  endif restartRead
  materialpoint_F0 = reshape(F_lastInc, [3,3,1,product(grid(1:2))*grid3])                           ! set starting condition for materialpoint_stressAndItsTangent
  call utilities_updateCoords(F)
  call utilities_constitutiveResponse(P_current,temp33_Real,C_volAvg,devNull, &                     ! stress field, stress avg, global average of stiffness and (min+max)/2
                                      F, &                                                          ! target F
                                      0.0_pReal, &                                                  ! time increment
                                      math_I3)                                                      ! no rotation of boundary condition
  call DMDAVecRestoreArrayF90(mech_grid,solution_current,u_current,ierr)
  CHKERRQ(ierr)
  call DMDAVecRestoreArrayF90(mech_grid,solution_lastInc,u_lastInc,ierr)
  CHKERRQ(ierr)
 
  restartRead2: if (interface_restartInc > 0) then
    write(6,'(/,a,'//IO_intOut(interface_restartInc)//',a)') &
      'reading more values of increment ', interface_restartInc, ' from file'
    call HDF5_read(groupHandle,C_volAvg,       'C_volAvg')
    call HDF5_read(groupHandle,C_volAvgLastInc,'C_volAvgLastInc')
    
    call HDF5_closeGroup(groupHandle)
    call HDF5_closeFile(fileHandle)

  endif restartRead2

end subroutine grid_mech_FEM_init


!--------------------------------------------------------------------------------------------------
!> @brief solution for the FEM scheme with internal iterations
!--------------------------------------------------------------------------------------------------
function grid_mech_FEM_solution(incInfoIn,timeinc,timeinc_old,stress_BC,rotation_BC) result(solution)

!--------------------------------------------------------------------------------------------------
! input data for solution
  character(len=*),            intent(in) :: &
    incInfoIn
  real(pReal),                 intent(in) :: &
    timeinc, &                                                                                      !< time increment of current solution
    timeinc_old                                                                                     !< time increment of last successful increment
  type(tBoundaryCondition),    intent(in) :: &
    stress_BC
  real(pReal), dimension(3,3), intent(in) :: rotation_BC
  type(tSolutionState)                    :: &
    solution
!--------------------------------------------------------------------------------------------------
! PETSc Data
  PetscErrorCode :: ierr
  SNESConvergedReason :: reason
 
  incInfo = incInfoIn

!--------------------------------------------------------------------------------------------------
! update stiffness (and gamma operator)
  S = utilities_maskedCompliance(rotation_BC,stress_BC%maskLogical,C_volAvg)
!--------------------------------------------------------------------------------------------------
! set module wide available data 
  params%stress_mask = stress_BC%maskFloat
  params%stress_BC   = stress_BC%values
  params%rotation_BC = rotation_BC
  params%timeinc     = timeinc
  params%timeincOld  = timeinc_old

!--------------------------------------------------------------------------------------------------
! solve BVP 
  call SNESsolve(mech_snes,PETSC_NULL_VEC,solution_current,ierr);CHKERRQ(ierr)

!--------------------------------------------------------------------------------------------------
! check convergence
  call SNESGetConvergedReason(mech_snes,reason,ierr);CHKERRQ(ierr)
  
  solution%converged = reason > 0
  solution%iterationsNeeded = totalIter
  solution%termIll = terminallyIll
  terminallyIll = .false.

end function grid_mech_FEM_solution


!--------------------------------------------------------------------------------------------------
!> @brief forwarding routine
!> @details find new boundary conditions and best F estimate for end of current timestep
!> possibly writing restart information, triggering of state increment in DAMASK, and updating of IPcoordinates
!--------------------------------------------------------------------------------------------------
subroutine grid_mech_FEM_forward(cutBack,guess,timeinc,timeinc_old,loadCaseTime,&
                                 deformation_BC,stress_BC,rotation_BC)

  logical,                     intent(in) :: &
    cutBack, &
    guess
  real(pReal),                 intent(in) :: &
    timeinc_old, &
    timeinc, &
    loadCaseTime                                                                                    !< remaining time of current load case
  type(tBoundaryCondition),    intent(in) :: &
    stress_BC, &
    deformation_BC
  real(pReal), dimension(3,3), intent(in) :: &
    rotation_BC
  PetscErrorCode :: ierr
  PetscScalar, pointer, dimension(:,:,:,:) :: &
    u_current,u_lastInc
  
  call DMDAVecGetArrayF90(mech_grid,solution_current,u_current,ierr); CHKERRQ(ierr)
  call DMDAVecGetArrayF90(mech_grid,solution_lastInc,u_lastInc,ierr); CHKERRQ(ierr)
 
  if (cutBack) then
    C_volAvg = C_volAvgLastInc
  else
    C_volAvgLastInc    = C_volAvg
 
    F_aimDot = merge(stress_BC%maskFloat*(F_aim-F_aim_lastInc)/timeinc_old, 0.0_pReal, guess)
    F_aim_lastInc = F_aim

    !--------------------------------------------------------------------------------------------------
    ! calculate rate for aim
    if     (deformation_BC%myType=='l') then                                                        ! calculate F_aimDot from given L and current F
      F_aimDot = &
      F_aimDot + deformation_BC%maskFloat * matmul(deformation_BC%values, F_aim_lastInc)
    elseif(deformation_BC%myType=='fdot') then                                                      ! F_aimDot is prescribed
      F_aimDot = &
      F_aimDot + deformation_BC%maskFloat * deformation_BC%values
    elseif (deformation_BC%myType=='f') then                                                        ! aim at end of load case is prescribed
      F_aimDot = &
      F_aimDot + deformation_BC%maskFloat * (deformation_BC%values - F_aim_lastInc)/loadCaseTime
    endif

    if (guess) then
      call VecWAXPY(solution_rate,-1.0_pReal,solution_lastInc,solution_current,ierr)
      CHKERRQ(ierr)
      call VecScale(solution_rate,1.0_pReal/timeinc_old,ierr); CHKERRQ(ierr)
    else
      call VecSet(solution_rate,0.0_pReal,ierr); CHKERRQ(ierr)
    endif
    call VecCopy(solution_current,solution_lastInc,ierr); CHKERRQ(ierr)
    
    F_lastInc = F
    
    materialpoint_F0 = reshape(F, [3,3,1,product(grid(1:2))*grid3])   
  endif

!--------------------------------------------------------------------------------------------------
! update average and local deformation gradients
  F_aim = F_aim_lastInc + F_aimDot * timeinc
  call VecAXPY(solution_current,timeinc,solution_rate,ierr); CHKERRQ(ierr)

  call DMDAVecRestoreArrayF90(mech_grid,solution_current,u_current,ierr);CHKERRQ(ierr)
  call DMDAVecRestoreArrayF90(mech_grid,solution_lastInc,u_lastInc,ierr);CHKERRQ(ierr)

end subroutine grid_mech_FEM_forward


!--------------------------------------------------------------------------------------------------
!> @brief Age
!--------------------------------------------------------------------------------------------------
subroutine grid_mech_FEM_updateCoords()

  call utilities_updateCoords(F)

end subroutine grid_mech_FEM_updateCoords


!--------------------------------------------------------------------------------------------------
!> @brief Write current solver and constitutive data for restart to file
!--------------------------------------------------------------------------------------------------
subroutine grid_mech_FEM_restartWrite()

  PetscErrorCode :: ierr
  PetscScalar, dimension(:,:,:,:), pointer :: u_current,u_lastInc
  integer(HID_T)    :: fileHandle, groupHandle
  character(len=32) :: rankStr
  
  call DMDAVecGetArrayF90(mech_grid,solution_current,u_current,ierr); CHKERRQ(ierr)
  call DMDAVecGetArrayF90(mech_grid,solution_lastInc,u_lastInc,ierr); CHKERRQ(ierr)

  write(6,'(a)') ' writing solver data required for restart to file';flush(6)
  
  write(rankStr,'(a1,i0)')'_',worldrank
  fileHandle = HDF5_openFile(trim(getSolverJobName())//trim(rankStr)//'.hdf5','w')
  groupHandle = HDF5_addGroup(fileHandle,'solver')

  call HDF5_write(groupHandle,F_aim,        'F_aim')
  call HDF5_write(groupHandle,F_aim_lastInc,'F_aim_lastInc')
  call HDF5_write(groupHandle,F_aimDot,     'F_aimDot')
  call HDF5_write(groupHandle,F,            'F')
  call HDF5_write(groupHandle,F_lastInc,    'F_lastInc')
  call HDF5_write(groupHandle,u_current,    'u')
  call HDF5_write(groupHandle,u_lastInc,    'u_lastInc')

  call HDF5_write(groupHandle,C_volAvg,       'C_volAvg')
  call HDF5_write(groupHandle,C_volAvgLastInc,'C_volAvgLastInc')

  call HDF5_closeGroup(groupHandle)
  call HDF5_closeFile(fileHandle)
 
  call DMDAVecRestoreArrayF90(mech_grid,solution_current,u_current,ierr);CHKERRQ(ierr)
  call DMDAVecRestoreArrayF90(mech_grid,solution_lastInc,u_lastInc,ierr);CHKERRQ(ierr)

end subroutine grid_mech_FEM_restartWrite


!--------------------------------------------------------------------------------------------------
!> @brief convergence check
!--------------------------------------------------------------------------------------------------
subroutine converged(snes_local,PETScIter,devNull1,devNull2,fnorm,reason,dummy,ierr)

  SNES :: snes_local
   PetscInt,  intent(in) :: PETScIter
   PetscReal, intent(in) :: &
     devNull1, &
     devNull2, &
     fnorm 
  SNESConvergedReason :: reason
  PetscObject :: dummy
  PetscErrorCode :: ierr
  real(pReal) :: &
    err_div, &
    divTol, &
    BCTol

  err_div = fnorm*sqrt(wgt)*geomSize(1)/scaledGeomSize(1)/detJ
  divTol = max(maxval(abs(P_av))*err_div_tolRel   ,err_div_tolAbs)
  BCTol  = max(maxval(abs(P_av))*err_stress_tolRel,err_stress_tolAbs)

  if ((totalIter >= itmin .and. &
                            all([ err_div/divTol, &
                                  err_BC /BCTol       ] < 1.0_pReal)) &
              .or.    terminallyIll) then  
    reason = 1
  elseif (totalIter >= itmax) then
    reason = -1
  else
    reason = 0
  endif

!--------------------------------------------------------------------------------------------------
! report
  write(6,'(1/,a)') ' ... reporting .............................................................'
  write(6,'(1/,a,f12.2,a,es8.2,a,es9.2,a)') ' error divergence = ', &
          err_div/divTol,  ' (',err_div,' / m, tol = ',divTol,')'
  write(6,'(a,f12.2,a,es8.2,a,es9.2,a)')    ' error stress BC  = ', &
          err_BC/BCTol,    ' (',err_BC, ' Pa,  tol = ',BCTol,')' 
  write(6,'(/,a)') ' ==========================================================================='
  flush(6)
 
end subroutine converged


!--------------------------------------------------------------------------------------------------
!> @brief forms the residual vector
!--------------------------------------------------------------------------------------------------
subroutine formResidual(da_local,x_local, &
                        f_local,dummy,ierr)

  DM                   :: da_local
  Vec                  :: x_local, f_local
  PetscScalar, pointer,dimension(:,:,:,:) :: x_scal, f_scal
  PetscScalar, dimension(8,3) :: x_elem,  f_elem
  PetscInt             :: i, ii, j, jj, k, kk, ctr, ele
  real(pReal), dimension(3,3) :: &
    deltaF_aim
  PetscInt :: &
    PETScIter, &
    nfuncs
  PetscObject :: dummy
  PetscErrorCode :: ierr
  real(pReal), dimension(3,3,3,3) :: devNull


  call SNESGetNumberFunctionEvals(mech_snes,nfuncs,ierr); CHKERRQ(ierr)
  call SNESGetIterationNumber(mech_snes,PETScIter,ierr); CHKERRQ(ierr)

  if (nfuncs == 0 .and. PETScIter == 0) totalIter = -1                                              ! new increment

!--------------------------------------------------------------------------------------------------
! begin of new iteration
  newIteration: if (totalIter <= PETScIter) then
    totalIter = totalIter + 1
    write(6,'(1x,a,3(a,'//IO_intOut(itmax)//'))') &
            trim(incInfo), ' @ Iteration ', itmin, '≤',totalIter+1, '≤', itmax
    if (iand(debug_level(debug_spectral),debug_spectralRotation) /= 0) &
      write(6,'(/,a,/,3(3(f12.7,1x)/))',advance='no') &
              ' deformation gradient aim (lab) =', transpose(math_rotate_backward33(F_aim,params%rotation_BC))
    write(6,'(/,a,/,3(3(f12.7,1x)/))',advance='no') &
              ' deformation gradient aim       =', transpose(F_aim)
    flush(6)
  endif newIteration

!--------------------------------------------------------------------------------------------------
! get deformation gradient
  call DMDAVecGetArrayF90(da_local,x_local,x_scal,ierr);CHKERRQ(ierr)
  do k = zstart, zend; do j = ystart, yend; do i = xstart, xend
    ctr = 0
    do kk = 0, 1; do jj = 0, 1; do ii = 0, 1
      ctr = ctr + 1
      x_elem(ctr,1:3) = x_scal(0:2,i+ii,j+jj,k+kk)
    enddo; enddo; enddo
    ii = i-xstart+1; jj = j-ystart+1; kk = k-zstart+1
    F(1:3,1:3,ii,jj,kk) = math_rotate_backward33(F_aim,params%rotation_BC) + transpose(matmul(BMat,x_elem)) 
  enddo; enddo; enddo
  call DMDAVecRestoreArrayF90(da_local,x_local,x_scal,ierr);CHKERRQ(ierr)

!--------------------------------------------------------------------------------------------------
! evaluate constitutive response
  call Utilities_constitutiveResponse(P_current,&
                                      P_av,C_volAvg,devNull, &
                                      F,params%timeinc,params%rotation_BC)
  call MPI_Allreduce(MPI_IN_PLACE,terminallyIll,1,MPI_LOGICAL,MPI_LOR,PETSC_COMM_WORLD,ierr)
  
!--------------------------------------------------------------------------------------------------
! stress BC handling
  F_aim_lastIter = F_aim
  deltaF_aim = math_mul3333xx33(S, P_av - params%stress_BC)
  F_aim = F_aim - deltaF_aim
  err_BC = maxval(abs(params%stress_mask * (P_av - params%stress_BC)))                              ! mask = 0.0 when no stress bc

!--------------------------------------------------------------------------------------------------
! constructing residual
  call VecSet(f_local,0.0_pReal,ierr);CHKERRQ(ierr)
  call DMDAVecGetArrayF90(da_local,f_local,f_scal,ierr);CHKERRQ(ierr)
  call DMDAVecGetArrayF90(da_local,x_local,x_scal,ierr);CHKERRQ(ierr)
  ele = 0
  do k = zstart, zend; do j = ystart, yend; do i = xstart, xend
    ctr = 0
    do kk = 0, 1; do jj = 0, 1; do ii = 0, 1
      ctr = ctr + 1
      x_elem(ctr,1:3) = x_scal(0:2,i+ii,j+jj,k+kk)
    enddo; enddo; enddo
    ii = i-xstart+1; jj = j-ystart+1; kk = k-zstart+1
    ele = ele + 1
    f_elem = matmul(transpose(BMat),transpose(P_current(1:3,1:3,ii,jj,kk)))*detJ + &
             matmul(HGMat,x_elem)*(materialpoint_dPdF(1,1,1,1,1,ele) + &
                                   materialpoint_dPdF(2,2,2,2,1,ele) + &
                                   materialpoint_dPdF(3,3,3,3,1,ele))/3.0_pReal
    ctr = 0
    do kk = 0, 1; do jj = 0, 1; do ii = 0, 1
      ctr = ctr + 1
      f_scal(0:2,i+ii,j+jj,k+kk) = f_scal(0:2,i+ii,j+jj,k+kk) + f_elem(ctr,1:3)
    enddo; enddo; enddo
  enddo; enddo; enddo
  call DMDAVecRestoreArrayF90(da_local,x_local,x_scal,ierr);CHKERRQ(ierr)
  call DMDAVecRestoreArrayF90(da_local,f_local,f_scal,ierr);CHKERRQ(ierr)
 
!--------------------------------------------------------------------------------------------------
! applying boundary conditions
  call DMDAVecGetArrayF90(da_local,f_local,f_scal,ierr);CHKERRQ(ierr)
  if (zstart == 0) then
    f_scal(0:2,xstart,ystart,zstart) = 0.0 
    f_scal(0:2,xend+1,ystart,zstart) = 0.0 
    f_scal(0:2,xstart,yend+1,zstart) = 0.0 
    f_scal(0:2,xend+1,yend+1,zstart) = 0.0 
  endif
  if (zend + 1 == grid(3)) then
    f_scal(0:2,xstart,ystart,zend+1) = 0.0 
    f_scal(0:2,xend+1,ystart,zend+1) = 0.0 
    f_scal(0:2,xstart,yend+1,zend+1) = 0.0 
    f_scal(0:2,xend+1,yend+1,zend+1) = 0.0 
  endif
  call DMDAVecRestoreArrayF90(da_local,f_local,f_scal,ierr);CHKERRQ(ierr) 
 
end subroutine formResidual


!--------------------------------------------------------------------------------------------------
!> @brief forms the FEM stiffness matrix
!--------------------------------------------------------------------------------------------------
subroutine formJacobian(da_local,x_local,Jac_pre,Jac,dummy,ierr)

  DM                                   :: da_local
  Vec                                  :: x_local, coordinates
  Mat                                  :: Jac_pre, Jac
  MatStencil,dimension(4,24)           :: row, col
  PetscScalar,pointer,dimension(:,:,:,:) :: x_scal
  PetscScalar,dimension(24,24)         :: K_ele
  PetscScalar,dimension(9,24)          :: BMatFull
  PetscInt                             :: i, ii, j, jj, k, kk, ctr, ele
  PetscInt,dimension(3),parameter      :: rows = [0, 1, 2]
  PetscScalar                          :: diag
  PetscObject                          :: dummy
  MatNullSpace                         :: matnull
  PetscErrorCode                       :: ierr
  
  BMatFull = 0.0
  BMatFull(1:3,1 :8 ) = BMat
  BMatFull(4:6,9 :16) = BMat
  BMatFull(7:9,17:24) = BMat
  call MatSetOption(Jac,MAT_KEEP_NONZERO_PATTERN,PETSC_TRUE,ierr); CHKERRQ(ierr)
  call MatSetOption(Jac,MAT_NEW_NONZERO_ALLOCATION_ERR,PETSC_FALSE,ierr); CHKERRQ(ierr)
  call MatZeroEntries(Jac,ierr); CHKERRQ(ierr)
  ele = 0
  do k = zstart, zend; do j = ystart, yend; do i = xstart, xend
    ctr = 0
    do kk = 0, 1; do jj = 0, 1; do ii = 0, 1
      ctr = ctr + 1
      col(MatStencil_i,ctr   ) = i+ii
      col(MatStencil_j,ctr   ) = j+jj
      col(MatStencil_k,ctr   ) = k+kk
      col(MatStencil_c,ctr   ) = 0
      col(MatStencil_i,ctr+8 ) = i+ii
      col(MatStencil_j,ctr+8 ) = j+jj
      col(MatStencil_k,ctr+8 ) = k+kk
      col(MatStencil_c,ctr+8 ) = 1
      col(MatStencil_i,ctr+16) = i+ii
      col(MatStencil_j,ctr+16) = j+jj
      col(MatStencil_k,ctr+16) = k+kk
      col(MatStencil_c,ctr+16) = 2
    enddo; enddo; enddo
    row = col
    ele = ele + 1
    K_ele = 0.0
    K_ele(1 :8 ,1 :8 ) = HGMat*(materialpoint_dPdF(1,1,1,1,1,ele) + &
                                materialpoint_dPdF(2,2,2,2,1,ele) + &
                                materialpoint_dPdF(3,3,3,3,1,ele))/3.0_pReal
    K_ele(9 :16,9 :16) = HGMat*(materialpoint_dPdF(1,1,1,1,1,ele) + &
                                materialpoint_dPdF(2,2,2,2,1,ele) + &
                                materialpoint_dPdF(3,3,3,3,1,ele))/3.0_pReal
    K_ele(17:24,17:24) = HGMat*(materialpoint_dPdF(1,1,1,1,1,ele) + &
                                materialpoint_dPdF(2,2,2,2,1,ele) + &
                                materialpoint_dPdF(3,3,3,3,1,ele))/3.0_pReal
    K_ele = K_ele + &
            matmul(transpose(BMatFull), &
                   matmul(reshape(reshape(materialpoint_dPdF(1:3,1:3,1:3,1:3,1,ele), &
                                          shape=[3,3,3,3], order=[2,1,4,3]),shape=[9,9]),BMatFull))*detJ
    call MatSetValuesStencil(Jac,24,row,24,col,K_ele,ADD_VALUES,ierr)
    CHKERRQ(ierr)
  enddo; enddo; enddo
  call MatAssemblyBegin(Jac,MAT_FINAL_ASSEMBLY,ierr); CHKERRQ(ierr)
  call MatAssemblyEnd(Jac,MAT_FINAL_ASSEMBLY,ierr); CHKERRQ(ierr)
  call MatAssemblyBegin(Jac_pre,MAT_FINAL_ASSEMBLY,ierr); CHKERRQ(ierr)
  call MatAssemblyEnd(Jac_pre,MAT_FINAL_ASSEMBLY,ierr); CHKERRQ(ierr)
 
!--------------------------------------------------------------------------------------------------
! applying boundary conditions
  diag = (C_volAvg(1,1,1,1)/delta(1)**2.0_pReal + &
          C_volAvg(2,2,2,2)/delta(2)**2.0_pReal + &
          C_volAvg(3,3,3,3)/delta(3)**2.0_pReal)*detJ
  call MatZeroRowsColumns(Jac,size(rows),rows,diag,PETSC_NULL_VEC,PETSC_NULL_VEC,ierr)
  CHKERRQ(ierr)
  call DMGetGlobalVector(da_local,coordinates,ierr);CHKERRQ(ierr)
  call DMDAVecGetArrayF90(da_local,coordinates,x_scal,ierr);CHKERRQ(ierr)
  ele = 0
  do k = zstart, zend; do j = ystart, yend; do i = xstart, xend
    ele = ele + 1
    x_scal(0:2,i,j,k) = discretization_IPcoords(1:3,ele)
  enddo; enddo; enddo
  call DMDAVecRestoreArrayF90(da_local,coordinates,x_scal,ierr);CHKERRQ(ierr)                       ! initialize to undeformed coordinates (ToDo: use ip coordinates)
  call MatNullSpaceCreateRigidBody(coordinates,matnull,ierr);CHKERRQ(ierr)                          ! get rigid body deformation modes
  call DMRestoreGlobalVector(da_local,coordinates,ierr);CHKERRQ(ierr)
  call MatSetNullSpace(Jac,matnull,ierr); CHKERRQ(ierr)
  call MatSetNearNullSpace(Jac,matnull,ierr); CHKERRQ(ierr)
  call MatNullSpaceDestroy(matnull,ierr); CHKERRQ(ierr)

end subroutine formJacobian

end module grid_mech_FEM
