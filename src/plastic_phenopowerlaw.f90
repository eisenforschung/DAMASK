!--------------------------------------------------------------------------------------------------
!> @author Franz Roters, Max-Planck-Institut für Eisenforschung GmbH
!> @author Philip Eisenlohr, Max-Planck-Institut für Eisenforschung GmbH
!> @author Martin Diehl, Max-Planck-Institut für Eisenforschung GmbH
!> @brief material subroutine for phenomenological crystal plasticity formulation using a powerlaw
!! fitting
!--------------------------------------------------------------------------------------------------
module plastic_phenopowerlaw
 use prec, only: &
   pReal,&
   pInt

 implicit none
 private
 integer(pInt),                       dimension(:,:),   allocatable, target, public :: &
   plastic_phenopowerlaw_sizePostResult                                                             !< size of each post result output
 character(len=64),                   dimension(:,:),   allocatable, target, public :: &
   plastic_phenopowerlaw_output                                                                     !< name of each post result output

 enum, bind(c)
   enumerator :: &
     undefined_ID, &
     resistance_slip_ID, &
     accumulatedshear_slip_ID, &
     shearrate_slip_ID, &
     resolvedstress_slip_ID, &
     totalshear_ID, &
     resistance_twin_ID, &
     accumulatedshear_twin_ID, &
     shearrate_twin_ID, &
     resolvedstress_twin_ID, &
     totalvolfrac_twin_ID
 end enum

 type, private :: tParameters                                                                       !< container type for internal constitutive parameters
   integer(pInt) :: &
     totalNslip, &
     totalNtwin
   real(pReal) :: &
     gdot0_slip, &                                                                                  !< reference shear strain rate for slip
     gdot0_twin, &                                                                                  !< reference shear strain rate for twin
     n_slip, &                                                                                      !< stress exponent for slip
     n_twin, &                                                                                      !< stress exponent for twin
     spr, &                                                                                         !< push-up factor for slip saturation due to twinning
     twinB, &
     twinC, &
     twinD, &
     twinE, &
     h0_SlipSlip, &                                                                                 !< reference hardening slip - slip
     h0_TwinSlip, &                                                                                 !< reference hardening twin - slip
     h0_TwinTwin, &                                                                                 !< reference hardening twin - twin
     a_slip, &
     aTolResistance, &                                                                              ! default absolute tolerance 1 Pa
     aTolShear, &                                                                                   ! default absolute tolerance 1e-6
     aTolTwinfrac                                                                                   ! default absolute tolerance 1e-6
   integer(pInt), dimension(:),   allocatable :: &
     Nslip, &                                                                                       !< active number of slip systems per family
     Ntwin                                                                                          !< active number of twin systems per family
   real(pReal),   dimension(:),   allocatable :: &
     tau0_slip, &                                                                                   !< initial critical shear stress for slip
     tau0_twin, &                                                                                   !< initial critical shear stress for twin
     tausat_slip, &                                                                                 !< maximum critical shear stress for slip
     nonSchmidCoeff, &
     H_int, &                                                                                       !< per family hardening activity (optional) !ToDo: Better name!
     shear_twin                                                                                     !< characteristic shear for twins
   real(pReal),   dimension(:,:),   allocatable :: &
     interaction_SlipSlip, &                                                                        !< slip resistance from slip activity
     interaction_SlipTwin, &                                                                        !< slip resistance from twin activity
     interaction_TwinSlip, &                                                                        !< twin resistance from slip activity
     interaction_TwinTwin                                                                           !< twin resistance from twin activity
   real(pReal),   dimension(:,:,:),   allocatable :: &
     Schmid_slip, &
     Schmid_twin
   real(pReal),   dimension(:,:,:,:),   allocatable :: &
     nonSchmid_pos, &
     nonSchmid_neg
 integer(kind(undefined_ID)),         dimension(:),   allocatable          :: &
   outputID                                                                                         !< ID of each post result output
 end type

 type(tParameters), dimension(:), allocatable, private :: param                                     !< containers of constitutive parameters (len Ninstance)

 type, private :: tPhenopowerlawState
   real(pReal), pointer,     dimension(:,:) :: &
     s_slip, &
     s_twin, &
     accshear_slip, &
     accshear_twin, &
     whole
   real(pReal), pointer,     dimension(:) :: &
     sumGamma, &
     sumF
 end type

 type(tPhenopowerlawState), allocatable, dimension(:), private :: &
   dotState, &
   state

 public :: &
   plastic_phenopowerlaw_init, &
   plastic_phenopowerlaw_LpAndItsTangent, &
   plastic_phenopowerlaw_dotState, &
   plastic_phenopowerlaw_postResults

contains


!--------------------------------------------------------------------------------------------------
!> @brief module initialization
!> @details reads in material parameters, allocates arrays, and does sanity checks
!--------------------------------------------------------------------------------------------------
subroutine plastic_phenopowerlaw_init
#if defined(__GFORTRAN__) || __INTEL_COMPILER >= 1800
 use, intrinsic :: iso_fortran_env, only: &
   compiler_version, &
   compiler_options
#endif
 use prec, only: &
   dEq0
 use debug, only: &
   debug_level, &
   debug_constitutive,&
   debug_levelBasic
 use math, only: &
   math_expand
 use IO, only: &
   IO_warning, &
   IO_error, &
   IO_timeStamp
 use material, only: &
   phase_plasticity, &
   phase_plasticityInstance, &
   phase_Noutput, &
   PLASTICITY_PHENOPOWERLAW_label, &
   PLASTICITY_PHENOPOWERLAW_ID, &
   material_phase, &
   plasticState
 use config, only: &
   MATERIAL_partPhase, &
   config_phase
 use lattice
 use numerics,only: &
   numerics_integrator

 implicit none

 integer(pInt) :: &
   maxNinstance, &
   instance,p,j,k, f,o, i,&
   NipcMyPhase, outputSize, &
   index_myFamily, index_otherFamily, &
   sizeState,sizeDotState, &
   startIndex, endIndex

 real(pReal), dimension(:,:), allocatable :: temp1, temp2

 integer(pInt),          dimension(0), parameter :: emptyIntArray = [integer(pInt)::]
 real(pReal),            dimension(0), parameter :: emptyRealArray = [real(pReal)::]
 character(len=65536),   dimension(0), parameter :: emptyStringArray = [character(len=65536)::]

 type(tParameters) :: prm

 integer(kind(undefined_ID)) :: &
   outputID                                                                                     !< ID of each post result output

 character(len=512) :: &
   extmsg    = ''
 character(len=65536), dimension(:), allocatable :: outputs

 write(6,'(/,a)')   ' <<<+-  constitutive_'//PLASTICITY_PHENOPOWERLAW_label//' init  -+>>>'
 write(6,'(a15,a)') ' Current time: ',IO_timeStamp()
#include "compilation_info.f90"

 maxNinstance = int(count(phase_plasticity == PLASTICITY_PHENOPOWERLAW_ID),pInt)
 if (iand(debug_level(debug_constitutive),debug_levelBasic) /= 0_pInt) &
   write(6,'(a16,1x,i5,/)') '# instances:',maxNinstance

 allocate(plastic_phenopowerlaw_sizePostResult(maxval(phase_Noutput),maxNinstance),source=0_pInt)
 allocate(plastic_phenopowerlaw_output(maxval(phase_Noutput),maxNinstance))
          plastic_phenopowerlaw_output = ''

 allocate(param(maxNinstance))                                                                      ! one container of parameters per instance
 allocate(state(maxNinstance))
 allocate(dotState(maxNinstance))

 do p = 1_pInt, size(phase_plasticityInstance)
   if (phase_plasticity(p) /= PLASTICITY_PHENOPOWERLAW_ID) cycle
   instance = phase_plasticityInstance(p)
   associate(prm => param(instance))

   prm%Nslip = config_phase(p)%getInts('nslip',defaultVal=emptyIntArray)
   if (size(prm%Nslip) > count(lattice_NslipSystem(:,p) > 0_pInt))       call IO_error(150_pInt,ext_msg='Nslip')
   if (any(lattice_NslipSystem(1:size(prm%Nslip),p)-prm%Nslip < 0_pInt)) call IO_error(150_pInt,ext_msg='Nslip')
   prm%totalNslip = sum(prm%Nslip)

   if (prm%totalNslip > 0_pInt) then
     prm%tau0_slip            = config_phase(p)%getFloats('tau0_slip')
     prm%tausat_slip          = config_phase(p)%getFloats('tausat_slip')
     prm%interaction_SlipSlip = spread(config_phase(p)%getFloats('interaction_slipslip'),2,1)
     prm%H_int                = config_phase(p)%getFloats('h_int',&
                              defaultVal=[(0.0_pReal,i=1_pInt,size(prm%Nslip))])
     prm%nonSchmidCoeff       = config_phase(p)%getFloats('nonschmid_coefficients',&
                              defaultVal = emptyRealArray )

     prm%gdot0_slip           = config_phase(p)%getFloat('gdot0_slip')
     prm%n_slip               = config_phase(p)%getFloat('n_slip')
     prm%a_slip               = config_phase(p)%getFloat('a_slip')
     prm%h0_SlipSlip          = config_phase(p)%getFloat('h0_slipslip')
   endif

   prm%Ntwin = config_phase(p)%getInts('ntwin', defaultVal=emptyIntArray)
   if (size(prm%Ntwin) > count(lattice_NtwinSystem(:,p) > 0_pInt))       call IO_error(150_pInt,ext_msg='Ntwin')
   if (any(lattice_NtwinSystem(1:size(prm%Ntwin),p)-prm%Ntwin < 0_pInt)) call IO_error(150_pInt,ext_msg='Ntwin')
   prm%totalNtwin = sum(prm%Ntwin)

   if (prm%totalNtwin > 0_pInt) then
     prm%tau0_twin       =  config_phase(p)%getFloats('tau0_twin')
     prm%interaction_TwinTwin = spread(config_phase(p)%getFloats('interaction_twintwin'),2,1)

     prm%gdot0_twin  = config_phase(p)%getFloat('gdot0_twin')
     prm%n_twin      = config_phase(p)%getFloat('n_twin')
     prm%spr         = config_phase(p)%getFloat('s_pr')
     prm%h0_TwinTwin = config_phase(p)%getFloat('h0_twintwin')
   endif

   if (prm%totalNslip > 0_pInt .and. prm%totalNtwin > 0_pInt) then
     prm%interaction_SlipTwin = spread(config_phase(p)%getFloats('interaction_sliptwin'),2,1)
     prm%interaction_TwinSlip = spread(config_phase(p)%getFloats('interaction_twinslip'),2,1)
     prm%h0_TwinSlip = config_phase(p)%getFloat('h0_twinslip')
   endif

   prm%twinB       = config_phase(p)%getFloat('twin_b',defaultVal=1.0_pReal)
   prm%twinC       = config_phase(p)%getFloat('twin_c',defaultVal=0.0_pReal)
   prm%twinD       = config_phase(p)%getFloat('twin_d',defaultVal=0.0_pReal)
   prm%twinE       = config_phase(p)%getFloat('twin_e',defaultVal=0.0_pReal)

   prm%aTolResistance = config_phase(p)%getFloat('atol_resistance',defaultVal=1.0_pReal)
   prm%aTolShear      = config_phase(p)%getFloat('atol_shear',defaultVal=1.0e-6_pReal)
   prm%aTolTwinfrac   = config_phase(p)%getFloat('atol_twinfrac',defaultVal=1.0e-6_pReal)

   outputs = config_phase(p)%getStrings('(output)',defaultVal=emptyStringArray)
   allocate(prm%outputID(0))
   do i=1_pInt, size(outputs)
     outputID = undefined_ID
     select case(outputs(i))
        case ('resistance_slip')
          outputID = resistance_slip_ID
          outputSize = prm%totalNslip
        case ('accumulatedshear_slip')
          outputID = accumulatedshear_slip_ID
          outputSize = prm%totalNslip
        case ('shearrate_slip')
          outputID = shearrate_slip_ID
          outputSize = prm%totalNslip
        case ('resolvedstress_slip')
          outputID = resolvedstress_slip_ID
          outputSize = prm%totalNslip

        case ('resistance_twin')
          outputID = resistance_twin_ID
          outputSize = prm%totalNtwin
        case ('accumulatedshear_twin')
          outputID = accumulatedshear_twin_ID
          outputSize = prm%totalNtwin
        case ('shearrate_twin')
          outputID = shearrate_twin_ID
          outputSize = prm%totalNtwin
        case ('resolvedstress_twin')
          outputID = resolvedstress_twin_ID
          outputSize = prm%totalNtwin

        case ('totalvolfrac_twin')
          outputID = totalvolfrac_twin_ID
          outputSize = 1_pInt
        case ('totalshear')
          outputID = totalshear_ID
          outputSize = 1_pInt
      end select

      if (outputID /= undefined_ID) then
        plastic_phenopowerlaw_output(i,instance) = outputs(i)
        plastic_phenopowerlaw_sizePostResult(i,instance) = outputSize
        prm%outputID = [prm%outputID , outputID]
      endif

   end do

   extmsg = ''
   if (prm%totalNslip > 0_pInt) then
     if (size(prm%tau0_slip) /= size(prm%Nslip))   call IO_error(211_pInt,ip=instance, &
            ext_msg='shape(tau0_slip) ('//PLASTICITY_PHENOPOWERLAW_label//')')
     if (size(prm%tausat_slip) /= size(prm%Nslip)) call IO_error(211_pInt,ip=instance, &
            ext_msg='shape(tausat_slip) ('//PLASTICITY_PHENOPOWERLAW_label//')')
     if (size(prm%H_int) /= size(prm%Nslip))       call IO_error(211_pInt,ip=instance, &
            ext_msg='shape(H_int) ('//PLASTICITY_PHENOPOWERLAW_label//')')

     if (any(prm%tau0_slip < 0.0_pReal .and. prm%Nslip > 0_pInt)) &
       extmsg = trim(extmsg)//"tau0_slip "
     if (any(prm%tausat_slip < prm%tau0_slip .and. prm%Nslip > 0_pInt)) &
       extmsg = trim(extmsg)//"tausat_slip "

     if (prm%gdot0_slip <= 0.0_pReal) extmsg = trim(extmsg)//" gdot0_slip "
     if (dEq0(prm%a_slip))            extmsg = trim(extmsg)//" a_slip " ! ToDo: negative values ok?
     if (dEq0(prm%n_slip))            extmsg = trim(extmsg)//" n_slip " ! ToDo: negative values ok?

     prm%H_int = math_expand(prm%H_int,prm%Nslip)
     prm%tausat_slip = math_expand(prm%tausat_slip,prm%Nslip)
   endif 

   if (prm%totalNtwin > 0_pInt) then
     if (size(prm%tau0_twin) /= size(prm%ntwin)) call IO_error(211_pInt,ip=instance,&
            ext_msg='shape(tau0_twin) ('//PLASTICITY_PHENOPOWERLAW_label//')')

     if (any(prm%tau0_twin < 0.0_pReal .and. prm%Ntwin > 0_pInt)) &
       extmsg = trim(extmsg)//"tau0_twin "

     if (prm%gdot0_twin <= 0.0_pReal) extmsg = trim(extmsg)//"gdot0_twin "
     if (dEq0(prm%n_twin))            extmsg = trim(extmsg)//"n_twin " ! ToDo: negative values ok?
   endif

   if (prm%aTolResistance <= 0.0_pReal) extmsg = trim(extmsg)//"aTolresistance "
   if (prm%aTolShear      <= 0.0_pReal) extmsg = trim(extmsg)//"aTolShear "
   if (prm%aTolTwinfrac   <= 0.0_pReal) extmsg = trim(extmsg)//"atoltwinfrac "

   if (extmsg /= '') call IO_error(211_pInt,ip=instance,&
                                 ext_msg=trim(extmsg)//'('//PLASTICITY_PHENOPOWERLAW_label//')')

!--------------------------------------------------------------------------------------------------
! allocate state arrays
   NipcMyPhase = count(material_phase == p)                                                         ! number of IPCs containing my phase
   sizeState = size(['tau_slip     ','accshear_slip']) * prm%TotalNslip &
             + size(['tau_twin     ','accshear_twin']) * prm%TotalNtwin &
             + size(['sum(gamma)', 'sum(f)    '])

   sizeDotState = sizeState
   plasticState(p)%sizeState = sizeState
   plasticState(p)%sizeDotState = sizeDotState
   plasticState(p)%sizePostResults = sum(plastic_phenopowerlaw_sizePostResult(:,instance))
   plasticState(p)%nSlip = prm%totalNslip
   plasticState(p)%nTwin = prm%totalNtwin
   allocate(plasticState(p)%aTolState          (   sizeState),             source=0.0_pReal)
   allocate(plasticState(p)%state0             (   sizeState,NipcMyPhase), source=0.0_pReal)
   allocate(plasticState(p)%partionedState0    (   sizeState,NipcMyPhase), source=0.0_pReal)
   allocate(plasticState(p)%subState0          (   sizeState,NipcMyPhase), source=0.0_pReal)
   allocate(plasticState(p)%state              (   sizeState,NipcMyPhase), source=0.0_pReal)

   allocate(plasticState(p)%dotState           (sizeDotState,NipcMyPhase), source=0.0_pReal)
   allocate(plasticState(p)%deltaState               (0_pInt,NipcMyPhase), source=0.0_pReal)
   if (any(numerics_integrator == 1_pInt)) then
     allocate(plasticState(p)%previousDotState (sizeDotState,NipcMyPhase),source=0.0_pReal)
     allocate(plasticState(p)%previousDotState2(sizeDotState,NipcMyPhase),source=0.0_pReal)
   endif
   if (any(numerics_integrator == 4_pInt)) &
     allocate(plasticState(p)%RK4dotState      (sizeDotState,NipcMyPhase), source=0.0_pReal)
   if (any(numerics_integrator == 5_pInt)) &
     allocate(plasticState(p)%RKCK45dotState (6,sizeDotState,NipcMyPhase), source=0.0_pReal)


!--------------------------------------------------------------------------------------------------
! calculate hardening matrices
   allocate(temp1(prm%totalNslip,prm%totalNslip),source = 0.0_pReal)
   allocate(temp2(prm%totalNslip,prm%totalNtwin),source = 0.0_pReal)
   allocate(prm%Schmid_slip(3,3,prm%totalNslip),source   = 0.0_pReal)
   allocate(prm%nonSchmid_pos(3,3,size(prm%nonSchmidCoeff),prm%totalNslip),source = 0.0_pReal)
   allocate(prm%nonSchmid_neg(3,3,size(prm%nonSchmidCoeff),prm%totalNslip),source = 0.0_pReal)
   i = 0_pInt
   mySlipFamilies: do f = 1_pInt,size(prm%Nslip,1)                                    ! >>> interaction slip -- X
     index_myFamily = sum(prm%Nslip(1:f-1_pInt))

     mySlipSystems: do j = 1_pInt,prm%Nslip(f)
       i = i + 1_pInt
       prm%Schmid_slip(1:3,1:3,i) = lattice_Sslip(1:3,1:3,1,sum(lattice_Nslipsystem(1:f-1,p))+j,p)
       do k = 1,size(prm%nonSchmidCoeff)
         prm%nonSchmid_pos(1:3,1:3,k,i) = lattice_Sslip(1:3,1:3,2*k,  index_myFamily+j,p) &
                                        * prm%nonSchmidCoeff(k)
         prm%nonSchmid_neg(1:3,1:3,k,i) = lattice_Sslip(1:3,1:3,2*k+1,index_myFamily+j,p) &
                                        * prm%nonSchmidCoeff(k)
       enddo
       otherSlipFamilies: do o = 1_pInt,size(prm%Nslip,1)
         index_otherFamily = sum(prm%Nslip(1:o-1_pInt))
         otherSlipSystems: do k = 1_pInt,prm%Nslip(o)
           temp1(index_myFamily+j,index_otherFamily+k) = &
               prm%interaction_SlipSlip(lattice_interactionSlipSlip( &
                                                                 sum(lattice_NslipSystem(1:f-1,p))+j, &
                                                                 sum(lattice_NslipSystem(1:o-1,p))+k, &
                                                                 p),1)
       enddo otherSlipSystems; enddo otherSlipFamilies

       twinFamilies: do o = 1_pInt,size(prm%Ntwin,1)
         index_otherFamily = sum(prm%Ntwin(1:o-1_pInt))
         twinSystems: do k = 1_pInt,prm%Ntwin(o)
           temp2(index_myFamily+j,index_otherFamily+k) = &
               prm%interaction_SlipTwin(lattice_interactionSlipTwin( &
                                                                 sum(lattice_NslipSystem(1:f-1_pInt,p))+j, &
                                                                 sum(lattice_NtwinSystem(1:o-1_pInt,p))+k, &
                                                                 p),1)
       enddo twinSystems; enddo twinFamilies
     enddo mySlipSystems
   enddo mySlipFamilies
   prm%interaction_SlipSlip = temp1; deallocate(temp1)
   prm%interaction_SlipTwin = temp2; deallocate(temp2)
   

   allocate(temp1(prm%totalNtwin,prm%totalNslip),source = 0.0_pReal)
   allocate(temp2(prm%totalNtwin,prm%totalNtwin),source = 0.0_pReal)
   allocate(prm%Schmid_twin(3,3,prm%totalNtwin),source  = 0.0_pReal)
   allocate(prm%shear_twin(prm%totalNtwin),source       = 0.0_pReal)
   i = 0_pInt
   myTwinFamilies: do f = 1_pInt,size(prm%Ntwin,1)                                    ! >>> interaction twin -- X
     index_myFamily = sum(prm%Ntwin(1:f-1_pInt))
     myTwinSystems: do j = 1_pInt,prm%Ntwin(f)
       i = i + 1_pInt
       prm%Schmid_twin(1:3,1:3,i) = lattice_Stwin(1:3,1:3,sum(lattice_NTwinsystem(1:f-1,p))+j,p)
       prm%shear_twin(i)          = lattice_shearTwin(sum(lattice_Ntwinsystem(1:f-1,p))+j,p)
       slipFamilies: do o = 1_pInt,size(prm%Nslip,1)
         index_otherFamily = sum(prm%Nslip(1:o-1_pInt))
         slipSystems: do k = 1_pInt,prm%Nslip(o)
           temp1(index_myFamily+j,index_otherFamily+k) = &
               prm%interaction_TwinSlip(lattice_interactionTwinSlip( &
                                                                 sum(lattice_NtwinSystem(1:f-1_pInt,p))+j, &
                                                                 sum(lattice_NslipSystem(1:o-1_pInt,p))+k, &
                                                                 p),1)
       enddo slipSystems; enddo slipFamilies

       otherTwinFamilies: do o = 1_pInt,size(prm%Ntwin,1)
         index_otherFamily = sum(prm%Ntwin(1:o-1_pInt))
         otherTwinSystems: do k = 1_pInt,prm%Ntwin(o)
           temp2(index_myFamily+j,index_otherFamily+k) = &
               prm%interaction_TwinTwin(lattice_interactionTwinTwin( &
                                                                 sum(lattice_NtwinSystem(1:f-1_pInt,p))+j, &
                                                                 sum(lattice_NtwinSystem(1:o-1_pInt,p))+k, &
                                                                 p),1)
       enddo otherTwinSystems; enddo otherTwinFamilies
     enddo myTwinSystems
   enddo myTwinFamilies
   prm%interaction_TwinSlip = temp1; deallocate(temp1)
   prm%interaction_TwinTwin = temp2; deallocate(temp2)

!--------------------------------------------------------------------------------------------------
! locally defined state aliases and initialization of state0 and aTolState
   startIndex = 1_pInt
   endIndex   = prm%totalNslip
   state   (instance)%s_slip => plasticState(p)%state   (startIndex:endIndex,:)
   state   (instance)%s_slip = spread(math_expand(prm%tau0_slip, prm%Nslip), 2, NipcMyPhase)
   dotState(instance)%s_slip => plasticState(p)%dotState(startIndex:endIndex,:)
   plasticState(p)%state0(startIndex:endIndex,:) = &
     spread(math_expand(prm%tau0_slip, prm%Nslip), 2, NipcMyPhase)
   plasticState(p)%aTolState(startIndex:endIndex) = prm%aTolResistance

   startIndex = endIndex + 1_pInt
   endIndex   = endIndex + prm%totalNtwin
   state   (instance)%s_twin => plasticState(p)%state   (startIndex:endIndex,:)
   state   (instance)%s_twin = spread(math_expand(prm%tau0_twin, prm%Ntwin), 2, NipcMyPhase)
   dotState(instance)%s_twin => plasticState(p)%dotState(startIndex:endIndex,:)
   plasticState(p)%state0(startIndex:endIndex,:) = &
     spread(math_expand(prm%tau0_twin, prm%Ntwin), 2, NipcMyPhase)
   plasticState(p)%aTolState(startIndex:endIndex) = prm%aTolResistance

   startIndex = endIndex + 1_pInt
   endIndex   = endIndex + 1_pInt
   state   (instance)%sumGamma => plasticState(p)%state   (startIndex,:)
   dotState(instance)%sumGamma => plasticState(p)%dotState(startIndex,:)
   plasticState(p)%aTolState(startIndex:endIndex) = prm%aTolShear

   startIndex = endIndex + 1_pInt
   endIndex   = endIndex + 1_pInt
   state   (instance)%sumF=>plasticState(p)%state   (startIndex,:)
   dotState(instance)%sumF=>plasticState(p)%dotState(startIndex,:)
   plasticState(p)%aTolState(startIndex:endIndex) = prm%aTolTwinFrac

   startIndex = endIndex + 1_pInt
   endIndex   = endIndex + prm%totalNslip
   state   (instance)%accshear_slip => plasticState(p)%state   (startIndex:endIndex,:)
   dotState(instance)%accshear_slip => plasticState(p)%dotState(startIndex:endIndex,:)
   plasticState(p)%aTolState(startIndex:endIndex) = prm%aTolShear
   ! global alias
   plasticState(p)%slipRate        => plasticState(p)%dotState(startIndex:endIndex,:)
   plasticState(p)%accumulatedSlip => plasticState(p)%state(startIndex:endIndex,:)

   startIndex = endIndex + 1_pInt
   endIndex   = endIndex + prm%totalNtwin
   state   (instance)%accshear_twin => plasticState(p)%state   (startIndex:endIndex,:)
   dotState(instance)%accshear_twin => plasticState(p)%dotState(startIndex:endIndex,:)
   plasticState(p)%aTolState(startIndex:endIndex) = prm%aTolShear
   
   dotState(instance)%whole => plasticState(p)%dotState
   
   end associate
 enddo

end subroutine plastic_phenopowerlaw_init


!--------------------------------------------------------------------------------------------------
!> @brief calculates plastic velocity gradient and its tangent
!--------------------------------------------------------------------------------------------------
subroutine plastic_phenopowerlaw_LpAndItsTangent(Lp,dLp_dMstar99,Mstar_v,ipc,ip,el)
 use math, only: &
   math_Mandel6to33, &
   math_Plain3333to99
 use material, only: &
   phasememberAt, &
   material_phase, &
   phase_plasticityInstance

 implicit none
 real(pReal), dimension(3,3), intent(out) :: &
   Lp                                                                                               !< plastic velocity gradient
 real(pReal), dimension(9,9), intent(out) :: & 
   dLp_dMstar99                                                                                     !< derivative of Lp with respect to the Mandel stress

 integer(pInt),               intent(in) :: &
   ipc, &                                                                                           !< component-ID of integration point
   ip, &                                                                                            !< integration point
   el                                                                                               !< element
 real(pReal), dimension(6), intent(in) :: &
   Mstar_v                                                                                          !< Mandel stress

 integer(pInt) :: &
   j,k,l,m,n, &
   of
 real(pReal), dimension(3,3) :: &
   S                                                                                                !< Second-Piola Kirchhoff stress
 real(pReal), dimension(3,3,3,3) :: &
   dLp_dS                                                                                           !< derivative of Lp with respect to Mstar as 4th order tensor
 real(pReal), dimension(param(phase_plasticityInstance(material_phase(ipc,ip,el)))%totalNslip) :: &
   dgdot_dtauslip_pos,dgdot_dtauslip_neg, &
   gdot_slip_pos,gdot_slip_neg
 real(pReal), dimension(param(phase_plasticityInstance(material_phase(ipc,ip,el)))%totalNtwin) :: &
   gdot_twin,dgdot_dtautwin

 type(tParameters)          :: prm
 type(tPhenopowerlawState)  :: stt

! BEGIN DEPRECATED
 of = phasememberAt(ipc,ip,el)
 S = math_Mandel6to33(Mstar_v)
 associate(prm => param(phase_plasticityInstance(material_phase(ipc,ip,el))),&
           stt => state(phase_plasticityInstance(material_phase(ipc,ip,el))))
! END DEPRECATED

 Lp = 0.0_pReal
 dLp_dS = 0.0_pReal

 call kinetics_slip(prm,stt,of,S,gdot_slip_pos,gdot_slip_neg,dgdot_dtauslip_pos,dgdot_dtauslip_neg)
 slipSystems: do j = 1_pInt, prm%totalNslip
   Lp = Lp + (1.0_pReal-stt%sumF(of))*(gdot_slip_pos(j)+gdot_slip_neg(j))*prm%Schmid_slip(1:3,1:3,j)
   forall (k=1_pInt:3_pInt,l=1_pInt:3_pInt,m=1_pInt:3_pInt,n=1_pInt:3_pInt) &
     dLp_dS(k,l,m,n) = dLp_dS(k,l,m,n) &
                     + dgdot_dtauslip_pos(j) * prm%Schmid_slip(k,l,j) &
                                             *(prm%Schmid_slip(m,n,j) + sum(prm%nonSchmid_pos(m,n,:,j)))
   forall (k=1_pInt:3_pInt,l=1_pInt:3_pInt,m=1_pInt:3_pInt,n=1_pInt:3_pInt) &
     dLp_dS(k,l,m,n) = dLp_dS(k,l,m,n) &
                     + dgdot_dtauslip_neg(j) * prm%Schmid_slip(k,l,j) &
                                             *(prm%Schmid_slip(m,n,j) + sum(prm%nonSchmid_neg(m,n,:,j)))
 enddo slipSystems

 call kinetics_twin(prm,stt,of,S,gdot_twin,dgdot_dtautwin)
 twinSystems: do j = 1_pInt, prm%totalNtwin
   Lp = Lp + gdot_twin(j)*prm%Schmid_twin(1:3,1:3,j)
   forall (k=1_pInt:3_pInt,l=1_pInt:3_pInt,m=1_pInt:3_pInt,n=1_pInt:3_pInt) &
     dLp_dS(k,l,m,n) = dLp_dS(k,l,m,n) &
                     + dgdot_dtautwin(j)*prm%Schmid_twin(k,l,j)*prm%Schmid_twin(m,n,j)
 enddo twinSystems
 end associate

 dLp_dMstar99 = math_Plain3333to99(dLp_dS) ! DEPRECATED

end subroutine plastic_phenopowerlaw_LpAndItsTangent


!--------------------------------------------------------------------------------------------------
!> @brief calculates the rate of change of microstructure
!--------------------------------------------------------------------------------------------------
subroutine plastic_phenopowerlaw_dotState(Mstar6,ipc,ip,el)
 use math, only: &
   math_Mandel6to33 
 use material, only: &
   material_phase, &
   phasememberAt, &
   phase_plasticityInstance

 implicit none
 real(pReal), dimension(6),  intent(in) :: &
   Mstar6                                                                                           !< Mandel stress
 integer(pInt),              intent(in) :: &
   ipc, &                                                                                           !< component-ID of integration point
   ip, &                                                                                            !< integration point
   el                                                                                               !< element                                                                                    !< microstructure state

 integer(pInt) :: &
   ph, &
   j,k, &
   of
 real(pReal) :: &
   c_SlipSlip,c_TwinSlip,c_TwinTwin, &
   ssat_offset

 real(pReal), dimension(3,3) :: &
   S                                                                                                !< Second-Piola Kirchhoff stress
 real(pReal), dimension(param(phase_plasticityInstance(material_phase(ipc,ip,el)))%totalNslip) :: &
   left_SlipSlip,right_SlipSlip, &
   gdot_slip_pos,gdot_slip_neg

 type(tParameters)         :: prm
 type(tPhenopowerlawState) :: dst,stt

 of = phasememberAt(ipc,ip,el)
 associate(prm => param(phase_plasticityInstance(material_phase(ipc,ip,el))), &
           stt => state(phase_plasticityInstance(material_phase(ipc,ip,el))), &
           dst => dotState(phase_plasticityInstance(material_phase(ipc,ip,el))))

 dst%whole(:,of) = 0.0_pReal
 S = math_Mandel6to33(Mstar6)

!--------------------------------------------------------------------------------------------------
! system-independent (nonlinear) prefactors to M_Xx (X influenced by x) matrices
 c_SlipSlip = prm%h0_slipslip * (1.0_pReal + prm%twinC*stt%sumF(of)** prm%twinB)
 c_TwinSlip = prm%h0_TwinSlip * stt%sumGamma(of)**prm%twinE
 c_TwinTwin = prm%h0_TwinTwin * stt%sumF(of)**prm%twinD

!--------------------------------------------------------------------------------------------------
!  calculate left and right vectors
 left_SlipSlip  = 1.0_pReal + prm%H_int
 ssat_offset = prm%spr*sqrt(stt%sumF(of))
 right_SlipSlip = abs(1.0_pReal-stt%s_slip(:,of) / (prm%tausat_slip+ssat_offset)) **prm%a_slip &
                * sign(1.0_pReal,1.0_pReal-stt%s_slip(:,of) / (prm%tausat_slip+ssat_offset))

!--------------------------------------------------------------------------------------------------
! shear rates
 call kinetics_slip(prm,stt,of,S,gdot_slip_pos,gdot_slip_neg)
 dst%accshear_slip(:,of) = abs(gdot_slip_pos+gdot_slip_neg)
 dst%sumGamma(of) = sum(dst%accshear_slip(:,of))
 call kinetics_twin(prm,stt,of,S,dst%accshear_twin(:,of))
 if (stt%sumF(of) < 0.98_pReal) dst%sumF(of) = sum(dst%accshear_twin(:,of)/prm%shear_twin)

!--------------------------------------------------------------------------------------------------
! hardening
 hardeningSlip: do j = 1_pInt, prm%totalNslip
   dst%s_slip(j,of) = &
     c_SlipSlip * left_SlipSlip(j) &
     * dot_product(prm%interaction_SlipSlip(j,:),right_SlipSlip*dst%accshear_slip(:,of)) &
                    + & 
     dot_product(prm%interaction_SlipTwin(j,:),dst%accshear_twin(:,of))
 enddo hardeningSlip

 hardeningTwin: do j = 1_pInt, prm%totalNtwin
   dst%s_twin(j,of) = &
     c_TwinSlip &
     * dot_product(prm%interaction_TwinSlip(j,:),dst%accshear_slip(:,of)) &
                    + &
     c_TwinTwin &
     * dot_product(prm%interaction_TwinTwin(j,:),dst%accshear_twin(:,of))
 enddo hardeningTwin

 end associate

end subroutine plastic_phenopowerlaw_dotState


!--------------------------------------------------------------------------------------------------
!> @brief calculates shear rates on slip systems
!--------------------------------------------------------------------------------------------------
subroutine kinetics_slip(prm,stt,of,S,gdot_slip_pos,gdot_slip_neg, &
                           dgdot_dtau_slip_pos,dgdot_dtau_slip_neg)
 use prec, only: &
  dNeq0
 use math, only: &
   math_mul33xx33

 implicit none
 type(tParameters), intent(in) :: &
   prm
 type(tPhenopowerlawState), intent(in) :: &
   stt
 integer(pInt),     intent(in) :: &
   of
 real, dimension(prm%totalNslip), intent(out) :: &
   gdot_slip_pos, &
   gdot_slip_neg
 real, dimension(prm%totalNslip), optional, intent(out) :: &
   dgdot_dtau_slip_pos, &
   dgdot_dtau_slip_neg
 real(pReal), dimension(3,3), intent(in) :: &
   S

 real, dimension(prm%totalNslip) :: &
   tau_slip_pos, &
   tau_slip_neg

 integer(pInt) :: i, j

 do i = 1_pInt, prm%totalNslip
   tau_slip_pos(i) = math_mul33xx33(S,prm%Schmid_slip(1:3,1:3,i))
   tau_slip_neg(i) = tau_slip_pos(i)
   do j = 1,size(prm%nonSchmidCoeff)
     tau_slip_pos(i) = tau_slip_pos(i) + math_mul33xx33(S,prm%nonSchmid_pos(1:3,1:3,j,i))
     tau_slip_neg(i) = tau_slip_neg(i) + math_mul33xx33(S,prm%nonSchmid_neg(1:3,1:3,j,i))
   enddo
 enddo


 gdot_slip_pos = 0.5_pReal*prm%gdot0_slip &
               * sign(abs(tau_slip_pos/stt%s_slip(:,of))**prm%n_slip,  tau_slip_pos)
 gdot_slip_neg = 0.5_pReal*prm%gdot0_slip &
               * sign(abs(tau_slip_neg/stt%s_slip(:,of))**prm%n_slip,  tau_slip_neg)

 if (present(dgdot_dtau_slip_pos)) then 
   where(dNeq0(tau_slip_pos))
     dgdot_dtau_slip_pos = gdot_slip_pos*prm%n_slip/tau_slip_pos
   else where
     dgdot_dtau_slip_pos = 0.0_pReal
   end where
 endif
 if (present(dgdot_dtau_slip_neg)) then 
   where(dNeq0(tau_slip_neg))
     dgdot_dtau_slip_neg = gdot_slip_neg*prm%n_slip/tau_slip_neg
   else where
     dgdot_dtau_slip_neg = 0.0_pReal
   end where
 endif

end subroutine kinetics_slip


!--------------------------------------------------------------------------------------------------
!> @brief calculates shear rates on twin systems
!--------------------------------------------------------------------------------------------------
subroutine kinetics_twin(prm,stt,of,S,gdot_twin,dgdot_dtau_twin)
 use prec, only: &
  dNeq0
 use math, only: &
   math_mul33xx33

 implicit none
 type(tParameters), intent(in) :: &
   prm
 type(tPhenopowerlawState), intent(in) :: &
   stt
 integer(pInt),     intent(in) :: &
   of
 real(pReal), dimension(3,3), intent(in) :: &
   S
 real, dimension(prm%totalNtwin), intent(out) :: &
   gdot_twin
 real, dimension(prm%totalNtwin), optional, intent(out) :: &
   dgdot_dtau_twin

 real, dimension(prm%totalNtwin) :: &
   tau_twin
 integer(pInt) :: i
 do i = 1_pInt, prm%totalNtwin
   tau_twin(i)  = math_mul33xx33(S,prm%Schmid_twin(1:3,1:3,i))
 enddo
 gdot_twin = merge((1.0_pReal-stt%sumF(of))*prm%gdot0_twin*(abs(tau_twin)/stt%s_twin(:,of))**prm%n_twin, &
                   0.0_pReal, tau_twin>0.0_pReal)
 if (present(dgdot_dtau_twin)) then 
   where(dNeq0(tau_twin))
     dgdot_dtau_twin = gdot_twin*prm%n_twin/tau_twin
   else where
     dgdot_dtau_twin = 0.0_pReal
   end where
 endif

end subroutine kinetics_twin


!--------------------------------------------------------------------------------------------------
!> @brief return array of constitutive results
!--------------------------------------------------------------------------------------------------
function plastic_phenopowerlaw_postResults(Mstar6,ipc,ip,el) result(postResults)
 use material, only: &
   material_phase, &
   plasticState, &
   phasememberAt, &
   phase_plasticityInstance
 use math, only: &
   math_mul33xx33, &
   math_Mandel6to33 

 implicit none
 real(pReal), dimension(6), intent(in) :: &
   Mstar6                                                                                           !< Mandel stress
 integer(pInt),             intent(in) :: &
   ipc, &                                                                                           !< component-ID of integration point
   ip, &                                                                                            !< integration point
   el                                                                                               !< element                                                                                        !< microstructure state

 real(pReal), dimension(3,3) :: &
   S                                                                                                !< Second-Piola Kirchhoff stress
 real(pReal), dimension(plasticState(material_phase(ipc,ip,el))%sizePostResults) :: &
   postResults

 integer(pInt) :: &
   of, &
   o,c,i,j
 real(pReal) :: &
   tau_slip_pos, tau_slip_neg
 real(pReal), dimension(param(phase_plasticityInstance(material_phase(ipc,ip,el)))%totalNslip) :: &
   gdot_slip_pos,gdot_slip_neg
 real(pReal), dimension(param(phase_plasticityInstance(material_phase(ipc,ip,el)))%totalNtwin) :: &
   gdot_twin,tau_twin

 type(tParameters)          :: prm
 type(tPhenopowerlawState)  :: stt

 of = phasememberAt(ipc,ip,el)
 associate( prm => param(phase_plasticityInstance(material_phase(ipc,ip,el))), &
            stt => state(phase_plasticityInstance(material_phase(ipc,ip,el))) )

 postResults = 0.0_pReal
 c = 0_pInt
 S = math_Mandel6to33(Mstar6)

 outputsLoop: do o = 1_pInt,size(prm%outputID)
   select case(prm%outputID(o))

     case (resistance_slip_ID)
       postResults(c+1_pInt:c+prm%totalNslip) = stt%s_slip(1:prm%totalNslip,of)
       c = c + prm%totalNslip
     case (accumulatedshear_slip_ID)
       postResults(c+1_pInt:c+prm%totalNslip) = stt%accshear_slip(1:prm%totalNslip,of)
       c = c + prm%totalNslip
     case (shearrate_slip_ID)
       call kinetics_slip(prm,stt,of,S,gdot_slip_pos,gdot_slip_neg)
       postResults(c+1_pInt:c+prm%totalNslip) = gdot_slip_pos+gdot_slip_neg
       c = c + prm%totalNslip
     case (resolvedstress_slip_ID)
       do i = 1_pInt, prm%totalNslip
         tau_slip_pos = math_mul33xx33(S,prm%Schmid_slip(1:3,1:3,i))
         tau_slip_neg = tau_slip_pos
         do j = 1,size(prm%nonSchmidCoeff)
           tau_slip_pos = tau_slip_pos + math_mul33xx33(S,prm%nonSchmid_pos(1:3,1:3,j,i))
           tau_slip_neg = tau_slip_neg + math_mul33xx33(S,prm%nonSchmid_neg(1:3,1:3,j,i))
         enddo
         postResults(c+i) = 0.5_pReal*(tau_slip_pos+tau_slip_neg)
       enddo
       c = c + prm%totalNslip

     case (resistance_twin_ID)
       postResults(c+1_pInt:c+prm%totalNtwin) = stt%s_twin(1:prm%totalNtwin,of)
       c = c + prm%totalNtwin
     case (accumulatedshear_twin_ID)
       postResults(c+1_pInt:c+prm%totalNtwin) = stt%accshear_twin(1:prm%totalNtwin,of)
       c = c + prm%totalNtwin
     case (shearrate_twin_ID)
       call kinetics_twin(prm,stt,of,S,postResults(c+1_pInt:c+prm%totalNtwin))
       c = c + prm%totalNtwin
     case (resolvedstress_twin_ID)
       do i = 1_pInt, prm%totalNtwin
         postResults(c+i) = math_mul33xx33(S,prm%Schmid_twin(1:3,1:3,i))
       enddo
       c = c + prm%totalNtwin

     case (totalvolfrac_twin_ID)
       postResults(c+1_pInt) = stt%sumF(of)
       c = c + 1_pInt
     case (totalshear_ID)
       postResults(c+1_pInt) = stt%sumGamma(of)
       c = c + 1_pInt

   end select
 enddo outputsLoop
 end associate

end function plastic_phenopowerlaw_postResults

end module plastic_phenopowerlaw
