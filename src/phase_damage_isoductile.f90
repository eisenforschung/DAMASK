!--------------------------------------------------------------------------------------------------
!> @author Pratheek Shanthraj, Max-Planck-Institut für Eisenforschung GmbH
!> @author Luv Sharma, Max-Planck-Institut für Eisenforschung GmbH
!> @brief material subroutine incorporating isotropic ductile damage source mechanism
!> @details to be done
!--------------------------------------------------------------------------------------------------
submodule(phase:damagee) isoductile

  type:: tParameters                                                                                !< container type for internal constitutive parameters
    real(pReal) :: &
      gamma_crit, &                                                                                 !< critical plastic strain
      q
    character(len=pStringLen), allocatable, dimension(:) :: &
      output
  end type tParameters

  type(tParameters), dimension(:), allocatable :: param                                             !< containers of constitutive parameters (len Ninstances)


contains


!--------------------------------------------------------------------------------------------------
!> @brief module initialization
!> @details reads in material parameters, allocates arrays, and does sanity checks
!--------------------------------------------------------------------------------------------------
module function isoductile_init(source_length) result(mySources)

  integer, intent(in)                  :: source_length
  logical, dimension(:,:), allocatable :: mySources

  class(tNode), pointer :: &
    phases, &
    phase, &
    sources, &
    src
  integer :: Ninstances,sourceOffset,Nconstituents,p
  character(len=pStringLen) :: extmsg = ''

  print'(/,a)', ' <<<+-  phase:damage:isoductile init  -+>>>'

  mySources = source_active('isoductile',source_length)
  Ninstances = count(mySources)
  print'(a,i2)', ' # instances: ',Ninstances; flush(IO_STDOUT)
  if(Ninstances == 0) return

  phases => config_material%get('phase')
  allocate(param(phases%length))

  do p = 1, phases%length
    phase => phases%get(p)
    if(count(mySources(:,p)) == 0) cycle
    sources => phase%get('damage')
    do sourceOffset = 1, sources%length
      if(mySources(sourceOffset,p)) then
        associate(prm  => param(p))
        src => sources%get(sourceOffset)

        prm%q          = src%get_asFloat('q')
        prm%gamma_crit = src%get_asFloat('gamma_crit')

#if defined (__GFORTRAN__)
        prm%output = output_asStrings(src)
#else
        prm%output = src%get_asStrings('output',defaultVal=emptyStringArray)
#endif

        ! sanity checks
        if (prm%q          <= 0.0_pReal) extmsg = trim(extmsg)//' q'
        if (prm%gamma_crit <= 0.0_pReal) extmsg = trim(extmsg)//' gamma_crit'

        Nconstituents=count(material_phaseAt==p) * discretization_nIPs
        call phase_allocateState(damageState(p),Nconstituents,1,1,0)
        damageState(p)%atol = src%get_asFloat('isoDuctile_atol',defaultVal=1.0e-3_pReal)
        if(any(damageState(p)%atol < 0.0_pReal)) extmsg = trim(extmsg)//' isoductile_atol'

        end associate

!--------------------------------------------------------------------------------------------------
!  exit if any parameter is out of range
        if (extmsg /= '') call IO_error(211,ext_msg=trim(extmsg)//'(damage_isoDuctile)')
      endif
    enddo
  enddo


end function isoductile_init


!--------------------------------------------------------------------------------------------------
!> @brief calculates derived quantities from state
!--------------------------------------------------------------------------------------------------
module subroutine isoductile_dotState(co, ip, el)

  integer, intent(in) :: &
    co, &                                                                                          !< component-ID of integration point
    ip, &                                                                                           !< integration point
    el                                                                                              !< element

  integer :: &
    ph, &
    me

  ph = material_phaseAt(co,el)
  me = material_phasememberAt(co,ip,el)


  associate(prm => param(ph))
    damageState(ph)%dotState(1,me) = sum(plasticState(ph)%slipRate(:,me))/(damage_phi(ph,me)**prm%q)/prm%gamma_crit
  end associate

end subroutine isoductile_dotState


!--------------------------------------------------------------------------------------------------
!> @brief returns local part of nonlocal damage driving force
!--------------------------------------------------------------------------------------------------
module subroutine source_damage_isoDuctile_getRateAndItsTangent(localphiDot, dLocalphiDot_dPhi, phi, phase, constituent)

  integer, intent(in) :: &
    phase, &
    constituent
  real(pReal),  intent(in) :: &
    phi
  real(pReal),  intent(out) :: &
    localphiDot, &
    dLocalphiDot_dPhi


  dLocalphiDot_dPhi = -damageState(phase)%state(1,constituent)

  localphiDot = 1.0_pReal &
              + dLocalphiDot_dPhi*phi

end subroutine source_damage_isoDuctile_getRateAndItsTangent


!--------------------------------------------------------------------------------------------------
!> @brief writes results to HDF5 output file
!--------------------------------------------------------------------------------------------------
module subroutine isoductile_results(phase,group)

  integer,          intent(in) :: phase
  character(len=*), intent(in) :: group

  integer :: o

  associate(prm => param(phase), stt => damageState(phase)%state)
    outputsLoop: do o = 1,size(prm%output)
      select case(trim(prm%output(o)))
        case ('f_phi')
          call results_writeDataset(group,stt,trim(prm%output(o)),'driving force','J/m³')
      end select
    enddo outputsLoop
  end associate

end subroutine isoductile_results

end submodule isoductile