!----------------------------------------------------------------------------------------------------
!> @brief internal microstructure state for all damage sources and kinematics constitutive models  
!----------------------------------------------------------------------------------------------------
submodule(constitutive) constitutive_damage

  interface

  module subroutine source_damage_anisoBrittle_init
  end subroutine source_damage_anisoBrittle_init 

  module subroutine source_damage_anisoDuctile_init
  end subroutine source_damage_anisoDuctile_init

  module subroutine source_damage_isoBrittle_init
  end subroutine source_damage_isoBrittle_init

  module subroutine source_damage_isoDuctile_init
  end subroutine source_damage_isoDuctile_init   

  module subroutine kinematics_cleavage_opening_init
  end subroutine kinematics_cleavage_opening_init

  module subroutine kinematics_slipplane_opening_init
  end subroutine kinematics_slipplane_opening_init


  module subroutine source_damage_anisobrittle_getRateAndItsTangent(localphiDot, dLocalphiDot_dPhi, phi, phase, constituent)
    integer, intent(in) :: &
      phase, &                                                                                      !< phase ID of element
      constituent                                                                                   !< position of element within its phase instance 
    real(pReal),  intent(in) :: &
      phi                                                                                           !< damage parameter 
    real(pReal),  intent(out) :: &
      localphiDot, &
      dLocalphiDot_dPhi
  end subroutine source_damage_anisoBrittle_getRateAndItsTangent
 
  module subroutine source_damage_anisoDuctile_getRateAndItsTangent(localphiDot, dLocalphiDot_dPhi, phi, phase, constituent)
    integer, intent(in) :: &
      phase, &                                                                                      !< phase ID of element
      constituent                                                                                   !< position of element within its phase instance
    real(pReal),  intent(in) :: &
      phi                                                                                           !< damage parameter
    real(pReal),  intent(out) :: &
      localphiDot, &
      dLocalphiDot_dPhi
  end subroutine source_damage_anisoDuctile_getRateAndItsTangent

  module subroutine source_damage_isoBrittle_getRateAndItsTangent(localphiDot, dLocalphiDot_dPhi, phi, phase, constituent)
    integer, intent(in) :: &
      phase, &                                                                                      !< phase ID of element
      constituent                                                                                   !< position of element within its phase instance
    real(pReal),  intent(in) :: &
      phi                                                                                           !< damage parameter
    real(pReal),  intent(out) :: &
      localphiDot, &
      dLocalphiDot_dPhi
  end subroutine source_damage_isoBrittle_getRateAndItsTangent

  module subroutine source_damage_isoDuctile_getRateAndItsTangent(localphiDot, dLocalphiDot_dPhi, phi, phase, constituent)
    integer, intent(in) :: &
      phase, &                                                                                      !< phase ID of element
      constituent                                                                                   !< position of element within its phase instance
    real(pReal),  intent(in) :: &
      phi                                                                                           !< damage parameter
    real(pReal),  intent(out) :: &
      localphiDot, &
      dLocalphiDot_dPhi
  end subroutine source_damage_isoDuctile_getRateAndItsTangent

  module subroutine source_damage_anisoBrittle_results(phase,group)
    integer,          intent(in) :: phase
    character(len=*), intent(in) :: group
  end subroutine source_damage_anisoBrittle_results

  module subroutine source_damage_anisoDuctile_results(phase,group)
    integer,          intent(in) :: phase
    character(len=*), intent(in) :: group
  end subroutine source_damage_anisoDuctile_results

  module subroutine source_damage_isoBrittle_results(phase,group)
    integer,          intent(in) :: phase
    character(len=*), intent(in) :: group
  end subroutine source_damage_isoBrittle_results

  module subroutine source_damage_isoDuctile_results(phase,group)
    integer,          intent(in) :: phase
    character(len=*), intent(in) :: group
  end subroutine source_damage_isoDuctile_results

 end interface

contains

!----------------------------------------------------------------------------------------------
!< @brief initialize damage sources and kinematics mechanism
!----------------------------------------------------------------------------------------------
module subroutine damage_init

! initialize source mechanisms
  if (any(phase_source == SOURCE_damage_isoBrittle_ID))         call source_damage_isoBrittle_init
  if (any(phase_source == SOURCE_damage_isoDuctile_ID))         call source_damage_isoDuctile_init
  if (any(phase_source == SOURCE_damage_anisoBrittle_ID))       call source_damage_anisoBrittle_init
  if (any(phase_source == SOURCE_damage_anisoDuctile_ID))       call source_damage_anisoDuctile_init

!--------------------------------------------------------------------------------------------------
! initialize kinematic mechanisms
  if (any(phase_kinematics == KINEMATICS_cleavage_opening_ID))  call kinematics_cleavage_opening_init
  if (any(phase_kinematics == KINEMATICS_slipplane_opening_ID)) call kinematics_slipplane_opening_init

end subroutine damage_init


!----------------------------------------------------------------------------------------------
!< @brief returns local part of nonlocal damage driving force
!----------------------------------------------------------------------------------------------
module subroutine constitutive_damage_getRateAndItsTangents(phiDot, dPhiDot_dPhi, phi, ip, el)

  integer, intent(in) :: &
    ip, &                                                                                           !< integration point number
    el                                                                                              !< element number
  real(pReal), intent(in) :: &
    phi                                                                                             !< damage parameter      
  real(pReal), intent(inout) :: &
    phiDot, &
    dPhiDot_dPhi

  real(pReal) :: &
    localphiDot, &
    dLocalphiDot_dPhi
  integer :: &
    phase, &
    grain, &
    source, &
    constituent

   phiDot = 0.0_pReal
   dPhiDot_dPhi = 0.0_pReal
 
   do grain = 1, homogenization_Ngrains(material_homogenizationAt(el))
     phase = material_phaseAt(grain,el)
     constituent = material_phasememberAt(grain,ip,el)
     do source = 1, phase_Nsources(phase)
       select case(phase_source(source,phase))
         case (SOURCE_damage_isoBrittle_ID)
           call source_damage_isobrittle_getRateAndItsTangent  (localphiDot, dLocalphiDot_dPhi, phi, phase, constituent)

         case (SOURCE_damage_isoDuctile_ID)
           call source_damage_isoductile_getRateAndItsTangent  (localphiDot, dLocalphiDot_dPhi, phi, phase, constituent)

         case (SOURCE_damage_anisoBrittle_ID)
           call source_damage_anisobrittle_getRateAndItsTangent(localphiDot, dLocalphiDot_dPhi, phi, phase, constituent)

         case (SOURCE_damage_anisoDuctile_ID)
           call source_damage_anisoductile_getRateAndItsTangent(localphiDot, dLocalphiDot_dPhi, phi, phase, constituent)

         case default
         localphiDot = 0.0_pReal
         dLocalphiDot_dPhi = 0.0_pReal

      end select
      phiDot = phiDot + localphiDot
      dPhiDot_dPhi = dPhiDot_dPhi + dLocalphiDot_dPhi
    enddo
  enddo

end subroutine constitutive_damage_getRateAndItsTangents


!----------------------------------------------------------------------------------------------
!< @brief writes damage sources resultsvto HDF5 output file
!----------------------------------------------------------------------------------------------
module subroutine damage_results

  integer :: p,i
  character(len=pStringLen) :: group

  do p = 1, size(config_name_phase)
    sourceLoop: do i = 1, phase_Nsources(p)
    group = trim('current/constituent')//'/'//trim(config_name_phase(p))
    group = trim(group)//'/sources'
    call results_closeGroup(results_addGroup(group))

      sourceType: select case (phase_source(i,p))

        case (SOURCE_damage_anisoBrittle_ID) sourceType
          call source_damage_anisoBrittle_results(p,group)
        case (SOURCE_damage_anisoDuctile_ID) sourceType
          call source_damage_anisoDuctile_results(p,group)
        case (SOURCE_damage_isoBrittle_ID) sourceType
          call source_damage_isoBrittle_results(p,group)
        case (SOURCE_damage_isoDuctile_ID) sourceType
          call source_damage_isoDuctile_results(p,group)
      end select sourceType

    enddo SourceLoop
  enddo

end subroutine damage_results


end submodule constitutive_damage