!--------------------------------------------------------------------------------------------------
!> @author Martin Diehl, Max-Planck-Institut für Eisenforschung GmbH
!> @brief all DAMASK files without solver
!> @details List of files needed by MSC.Marc
!--------------------------------------------------------------------------------------------------
#include "parallelization.f90"
#include "IO.f90"
#include "YAML_types.f90"
#include "YAML_parse.f90"
#include "future.f90"
#include "config.f90"
#include "LAPACK_interface.f90"
#include "math.f90"
#include "rotations.f90"
#include "element.f90"
#include "HDF5_utilities.f90"
#include "results.f90"
#include "geometry_plastic_nonlocal.f90"
#include "discretization.f90"
#ifdef Marc4DAMASK
#include "marc/discretization_marc.f90"
#endif
#include "material.f90"
#include "lattice.f90"
#include "constitutive.f90"
#include "constitutive_mech.f90"
#include "constitutive_plastic_none.f90"
#include "constitutive_plastic_isotropic.f90"
#include "constitutive_plastic_phenopowerlaw.f90"
#include "constitutive_plastic_kinehardening.f90"
#include "constitutive_plastic_dislotwin.f90"
#include "constitutive_plastic_disloTungsten.f90"
#include "constitutive_plastic_nonlocal.f90"
#include "constitutive_thermal.f90"
#include "constitutive_thermal_dissipation.f90"
#include "constitutive_thermal_externalheat.f90"
#include "kinematics_thermal_expansion.f90"
#include "constitutive_damage.f90"
#include "source_damage_isoBrittle.f90"
#include "source_damage_isoDuctile.f90"
#include "source_damage_anisoBrittle.f90"
#include "source_damage_anisoDuctile.f90"
#include "kinematics_cleavage_opening.f90"
#include "kinematics_slipplane_opening.f90"
#include "damage_none.f90"
#include "damage_nonlocal.f90"
#include "homogenization.f90"
#include "homogenization_mech.f90"
#include "homogenization_mech_none.f90"
#include "homogenization_mech_isostrain.f90"
#include "homogenization_mech_RGC.f90"
#include "homogenization_thermal.f90"
#include "homogenization_damage.f90"
#include "CPFEM.f90"
