
!##############################################################
 MODULE mesh     
!##############################################################

 use prec, only: pReal,pInt
 implicit none

! ---------------------------
! _Nelems    : total number of elements in mesh
! _NcpElems  : total number of CP elements in mesh
! _Nnodes    : total number of nodes in mesh
! _maxNnodes : max number of nodes in any CP element
! _maxNips   : max number of IPs in any CP element
! _maxNipNeighbors   : max number of IP neighbors in any CP element
! _maxNsharedElems : max number of CP elements sharing a node
!
! _element    : FEid, type(internal representation), material, texture, node indices
! _node       : x,y,z coordinates (initially!)
! _sharedElem : entryCount and list of elements containing node
!
! _mapFEtoCPelem : [sorted FEid, corresponding CPid]
! _mapFEtoCPnode : [sorted FEid, corresponding CPid]
!
! MISSING: these definitions should actually reside in the
! FE-solver specific part (different for MARC/ABAQUS)..!
! Hence, I suggest to prefix with "FE_"
!
! _mapElementtype   : map MARC/ABAQUS elemtype to 1...maxN 
!
! _Nnodes            : # nodes in a specific type of element
! _Nips              : # IPs in a specific type of element
! _NipNeighbors      : # IP neighbors in a specific type of element
! _ipNeighbor        : +x,-x,+y,-y,+z,-z list of intra-element IPs and
!     (negative) neighbor faces per own IP in a specific type of element
! _NfaceNodes        : # nodes per face in a specific type of element

! _nodeOnFace        : list of node indices on each face of a specific type of element
! _ipAtNode          : map node index to IP index in a specific type of element
! _nodeAtIP          : map IP index to node index in a specific type of element
! _ipNeighborhood    : 6 or less neighboring IPs as [element_num, IP_index]
! _NsubNodes        : # subnodes required to fully define all IP volumes

!     order is +x,-x,+y,-y,+z,-z but meaning strongly depends on Elemtype
! ---------------------------
 integer(pInt) mesh_Nelems,mesh_NcpElems,mesh_NelemSets,mesh_maxNelemInSet
 integer(pInt) mesh_Nnodes,mesh_maxNnodes,mesh_maxNips,mesh_maxNipNeighbors,mesh_maxNsharedElems,mesh_maxNsubNodes
 integer(pInt), dimension(2) :: mesh_maxValStateVar = 0_pInt
 character(len=64), dimension(:),   allocatable :: mesh_nameElemSet
 integer(pInt), dimension(:,:),     allocatable :: mesh_mapElemSet
 integer(pInt), dimension(:,:),     allocatable, target :: mesh_mapFEtoCPelem,mesh_mapFEtoCPnode
 integer(pInt), dimension(:,:),     allocatable :: mesh_element, mesh_sharedElem
 integer(pInt), dimension(:,:,:,:), allocatable :: mesh_ipNeighborhood

 real(pReal),   dimension(:,:,:),   allocatable :: mesh_subNodeCoord    ! coordinates of subnodes per element
 real(pReal),   dimension(:,:),     allocatable :: mesh_ipVolume        ! volume associated with IP
 real(pReal),   dimension(:,:,:),   allocatable :: mesh_ipArea          ! area of interface to neighboring IP
 real(pReal),   dimension(:,:,:,:), allocatable :: mesh_ipAreaNormal    ! area normal of interface to neighboring IP
 real(pReal),                       allocatable :: mesh_node (:,:)

 integer(pInt) :: hypoelasticTableStyle = 0
 integer(pInt) :: initialcondTableStyle = 0
 integer(pInt), parameter :: FE_Nelemtypes = 6
 integer(pInt), parameter :: FE_maxNnodes = 8
 integer(pInt), parameter :: FE_maxNsubNodes = 19
 integer(pInt), parameter :: FE_maxNips = 9
 integer(pInt), parameter :: FE_maxNipNeighbors = 6
 integer(pInt), parameter :: FE_NipFaceNodes = 4
 integer(pInt), dimension(FE_Nelemtypes), parameter :: FE_Nnodes = &
 (/8, & ! element 7
   4, & ! element 134
   4, & ! element 11
   8, & ! element 27
   4, & ! element 157
   6  & ! element 136
  /)
 integer(pInt), dimension(FE_Nelemtypes), parameter :: FE_Nips = &
 (/8, & ! element 7
   1, & ! element 134
   4, & ! element 11
   9, & ! element 27
   4, & ! element 157
   6  & ! element 136
  /)
 integer(pInt), dimension(FE_Nelemtypes), parameter :: FE_NipNeighbors = &
 (/6, & ! element 7
   4, & ! element 134
   4, & ! element 11
   4, & ! element 27
   6, & ! element 157
   6  & ! element 136
  /)
 integer(pInt), dimension(FE_Nelemtypes), parameter :: FE_NsubNodes = &
 (/19, & ! element 7
   0, & ! element 134
   0, & ! element 11
   0, & ! element 27
   0, & ! element 157
   0  & ! element 136
  /)
 integer(pInt), dimension(FE_maxNipNeighbors,FE_Nelemtypes), parameter :: FE_NfaceNodes = &
 reshape((/&
  4,4,4,4,4,4, & ! element 7
  3,3,3,3,0,0, & ! element 134
  2,2,2,2,0,0, & ! element 11
  3,3,3,3,0,0, & ! element 27
  3,3,3,3,0,0, & ! element 157
  3,4,4,4,3,0  & ! element 136
   /),(/FE_maxNipNeighbors,FE_Nelemtypes/))
 integer(pInt), dimension(FE_maxNips,FE_Nelemtypes), parameter :: FE_nodeAtIP = &
 reshape((/&
  1,2,4,3,5,6,8,7,0, & ! element 7
  1,0,0,0,0,0,0,0,0, & ! element 134
  1,2,4,3,0,0,0,0,0, & ! element 11
  1,5,2,8,0,6,4,7,3, & ! element 27
  1,2,3,4,0,0,0,0,0, & ! element 157
  1,2,3,4,5,6,0,0,0  & ! element 136
   /),(/FE_maxNips,FE_Nelemtypes/))
 integer(pInt), dimension(FE_maxNnodes,FE_Nelemtypes), parameter :: FE_ipAtNode = &
 reshape((/&
  1,2,4,3,5,6,8,7, & ! element 7
  1,1,1,1,0,0,0,0, & ! element 134
  1,2,4,3,0,0,0,0, & ! element 11
  1,3,9,7,2,6,8,4, & ! element 27
  1,2,3,4,0,0,0,0, & ! element 157
  1,2,3,4,5,6,0,0  & ! element 136
   /),(/FE_maxNnodes,FE_Nelemtypes/))
 integer(pInt), dimension(FE_NipFaceNodes,FE_maxNipNeighbors,FE_Nelemtypes), parameter :: FE_nodeOnFace = &
 reshape((/&
  1,2,3,4 , & ! element 7
  2,1,5,6 , &
  3,2,6,7 , &
  4,3,7,8 , &
  4,1,5,8 , &
  8,7,6,5 , &
  1,2,3,0 , & ! element 134
  1,4,2,0 , &
  2,3,4,0 , &
  1,3,4,0 , &
  0,0,0,0 , &
  0,0,0,0 , &
  1,2,0,0 , & ! element 11
  2,3,0,0 , &
  3,4,0,0 , &
  4,1,0,0 , &
  0,0,0,0 , &
  0,0,0,0 , &
  1,5,2,0 , & ! element 27
  2,6,3,0 , &
  3,7,4,0 , &
  4,8,1,0 , &
  0,0,0,0 , &
  0,0,0,0 , &
  1,2,3,0 , & ! element 157
  1,4,2,0 , &
  2,3,4,0 , &
  1,3,4,0 , &
  0,0,0,0 , &
  0,0,0,0 , &
  1,2,3,0 , & ! element 136
  1,4,5,2 , &
  2,5,6,3 , &
  1,3,6,4 , &
  4,6,5,0 , &
  0,0,0,0 &
   /),(/FE_NipFaceNodes,FE_maxNipNeighbors,FE_Nelemtypes/))
 integer(pInt), dimension(FE_maxNipNeighbors,FE_maxNips,FE_Nelemtypes), parameter :: FE_ipNeighbor = &
 reshape((/&
   2,-5, 3,-2, 5,-1 , & ! element 7
  -3, 1, 4,-2, 6,-1 , &
   4,-5,-4, 1, 7,-1 , &
  -3, 3,-4, 2, 8,-1 , &
   6,-5, 7,-2,-6, 1 , &
  -3, 5, 8,-2,-6, 2 , &
   8,-5,-4, 5,-6, 3 , &
  -3, 7,-4, 6,-6, 4 , &
   0, 0, 0, 0, 0, 0 , &
  -1,-2,-3,-4, 0, 0 , & ! element 134
   0, 0, 0, 0, 0, 0 , &
   0, 0, 0, 0, 0, 0 , &
   0, 0, 0, 0, 0, 0 , &
   0, 0, 0, 0, 0, 0 , &
   0, 0, 0, 0, 0, 0 , &
   0, 0, 0, 0, 0, 0 , &
   0, 0, 0, 0, 0, 0 , &
   0, 0, 0, 0, 0, 0 , &
   2,-4, 3,-1, 0, 0 , & ! element 11
  -2, 1, 4,-1, 0, 0 , &
   4,-4,-3, 1, 0, 0 , &
  -2, 3,-3, 2, 0, 0 , &
   0, 0, 0, 0, 0, 0 , &
   0, 0, 0, 0, 0, 0 , &
   0, 0, 0, 0, 0, 0 , &
   0, 0, 0, 0, 0, 0 , &
   0, 0, 0, 0, 0, 0 , &
   2,-4, 4,-1, 0, 0 , & ! element 27
   3, 1, 5,-1, 0, 0 , &
  -2, 2, 6,-1, 0, 0 , &
   5,-4, 7, 1, 0, 0 , &
   6, 4, 8, 2, 0, 0 , &
  -2, 5, 9, 3, 0, 0 , &
   8,-4,-3, 4, 0, 0 , &
   9, 7,-3, 5, 0, 0 , &
  -2, 8,-3, 6, 0, 0 , &
   2,-4, 3,-2, 4,-1 , & ! element 157
   3,-2, 1,-3, 4,-1 , &
   1,-3, 2,-4, 4,-1 , &
   1,-3, 2,-4, 3,-2 , &
   0, 0, 0, 0, 0, 0 , &
   0, 0, 0, 0, 0, 0 , &
   0, 0, 0, 0, 0, 0 , &
   0, 0, 0, 0, 0, 0 , &
   0, 0, 0, 0, 0, 0 , &
   2,-4, 3,-2, 4,-1 , & ! element 136
  -3, 1, 3,-2, 5,-1 , &
   2,-4,-3, 1, 6,-1 , &
   5,-4, 6,-2,-5, 1 , &
  -3, 4, 6,-2,-5, 2 , &
   5,-4,-3, 4,-5, 3 , &
   0, 0, 0, 0, 0, 0 , &
   0, 0, 0, 0, 0, 0 , &
   0, 0, 0, 0, 0, 0   &
   /),(/FE_maxNipNeighbors,FE_maxNips,FE_Nelemtypes/))
 integer(pInt), dimension(FE_maxNnodes,FE_maxNsubNodes,FE_Nelemtypes), parameter :: FE_subNodeParent = &
 reshape((/&
   1, 2, 0, 0, 0, 0, 0, 0, & ! element 7
   2, 3, 0, 0, 0, 0, 0, 0, &
   3, 4, 0, 0, 0, 0, 0, 0, &
   4, 1, 0, 0, 0, 0, 0, 0, &
   1, 5, 0, 0, 0, 0, 0, 0, &
   2, 6, 0, 0, 0, 0, 0, 0, &
   3, 7, 0, 0, 0, 0, 0, 0, &
   4, 8, 0, 0, 0, 0, 0, 0, &
   5, 6, 0, 0, 0, 0, 0, 0, &
   6, 7, 0, 0, 0, 0, 0, 0, &
   7, 8, 0, 0, 0, 0, 0, 0, &
   8, 5, 0, 0, 0, 0, 0, 0, &
   1, 2, 3, 4, 0, 0, 0, 0, &
   1, 2, 6, 5, 0, 0, 0, 0, &
   2, 3, 7, 6, 0, 0, 0, 0, &
   3, 4, 8, 7, 0, 0, 0, 0, &
   1, 4, 8, 5, 0, 0, 0, 0, &
   5, 6, 7, 8, 0, 0, 0, 0, &
   1, 2, 3, 4, 5, 6, 7, 8, &
   0, 0, 0, 0, 0, 0, 0, 0, & ! element 134
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & ! element 11
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & ! element 27
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & ! element 157
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & ! element 136
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0, & 
   0, 0, 0, 0, 0, 0, 0, 0  &
   /),(/FE_maxNnodes,FE_maxNsubNodes,FE_Nelemtypes/))
 integer(pInt), dimension(FE_NipFaceNodes,FE_maxNipNeighbors,FE_maxNips,FE_Nelemtypes), parameter :: FE_subNodeOnIPFace = &
 reshape((/&
   9,21,27,22, & ! element 7
   1,13,25,12, &
  12,25,27,21, &
   1, 9,22,13, &
  13,22,27,25, &
   1,12,21, 9, &
   2,10,23,14, & ! 
   9,22,27,21, &
  10,21,27,23, &
   2,14,22, 9, &
  14,23,27,22, &
   2, 9,21,10, &
  11,24,27,21, & ! 
   4,12,25,16, &
   4,16,24,11, &
  12,21,27,25, &
  16,25,27,24, &
   4,11,21,12, &
   3,15,23,10, & ! 
  11,21,27,24, &
   3,11,24,15, &
  10,23,27,21, &
  15,24,27,23, &
   3,10,21,11, &
  17,22,27,26, & ! 
   5,20,25,13, &
  20,26,27,25, &
   5,13,22,17, &
   5,17,26,20, &
  13,25,27,22, &
   6,14,23,18, & ! 
  17,26,27,22, &
  18,23,27,26, &
   6,17,22,14, &
   6,18,26,17, &
  14,22,27,23, &
  19,26,27,24, & ! 
   8,16,25,20, &
   8,19,24,16, &
  20,25,27,26, &
   8,20,26,19, &
  16,24,27,25, &
   7,18,23,15, & ! 
  19,24,27,26, &
   7,15,24,19, &
  18,26,27,23, &
   7,19,26,18, &
  15,23,27,24, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   1, 1, 3, 2, & ! element 134
   1, 1, 2, 4, &
   2, 2, 3, 4, &
   1, 1, 4, 3, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! element 11
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! element 27
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! element 157
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! element 136
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, & ! 
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0, &
   0, 0, 0, 0  &
   /),(/FE_NipFaceNodes,FE_maxNipNeighbors,FE_maxNips,FE_Nelemtypes/))
   
 CONTAINS
! ---------------------------
! subroutine mesh_init()
! function mesh_FEtoCPelement(FEid)
! function mesh_build_ipNeighorhood()
! ---------------------------


!***********************************************************
! initialization 
!***********************************************************
 SUBROUTINE mesh_init ()

 use prec, only: pInt
 use IO, only: IO_error,IO_open_InputFile
 use FEsolving, only: parallelExecution
 
 implicit none
 
 integer(pInt), parameter :: fileUnit = 222

 mesh_Nelems          = 0_pInt
 mesh_NcpElems        = 0_pInt
 mesh_Nnodes          = 0_pInt
 mesh_maxNips         = 0_pInt
 mesh_maxNnodes       = 0_pInt
 mesh_maxNipNeighbors = 0_pInt
 mesh_maxNsharedElems = 0_pInt
 mesh_maxNsubNodes    = 0_pInt
 mesh_NelemSets       = 0_pInt
 mesh_maxNelemInSet   = 0_pInt



! call to various subroutines to parse the stuff from the input file...
 if (IO_open_inputFile(fileUnit)) then

   call mesh_get_meshDimensions(fileUnit)
   call mesh_build_nodeMapping(fileUnit)
   call mesh_build_elemMapping(fileUnit)
   call mesh_build_elemSetMapping(fileUnit)
   call mesh_get_nodeElemDimensions(fileUnit)
   call mesh_build_nodes(fileUnit)
   call mesh_build_elements(fileUnit)
   call mesh_build_sharedElems(fileUnit)
   call mesh_build_ipNeighborhood()
   call mesh_build_subNodeCoords()
   call mesh_build_ipVolumes()
   call mesh_build_ipAreas()
   call mesh_tell_statistics()
   close (fileUnit)

   parallelExecution = (mesh_Nelems == mesh_NcpElems)      ! plus potential killer from non-local constitutive
 else
   call IO_error(100) ! cannot open input file
 endif
 
 END SUBROUTINE
 


!***********************************************************
! mapping of FE element types to internal representation
!***********************************************************
 FUNCTION FE_mapElemtype(what)

 implicit none
 
 character(len=*), intent(in) :: what
 integer(pInt) FE_mapElemtype
  
 select case (what)
    case ('7', 'C3D8')
	   FE_mapElemtype = 1            ! Three-dimensional Arbitrarily Distorted Brick
    case ('134')
	   FE_mapElemtype = 2            ! Three-dimensional Four-node Tetrahedron
    case ('11')
	   FE_mapElemtype = 3            ! Arbitrary Quadrilateral Plane-strain
    case ('27')
	   FE_mapElemtype = 4            ! Plane Strain, Eight-node Distorted Quadrilateral
    case ('157')
	   FE_mapElemtype = 5            ! Three-dimensional, Low-order, Tetrahedron, Herrmann Formulations
    case ('136')
	   FE_mapElemtype = 6            ! Three-dimensional Arbitrarily Distorted Pentahedral
	case default 
	   FE_mapElemtype = 0            ! unknown element --> should raise an error upstream..!
 end select

 END FUNCTION



!***********************************************************
! FE to CP id mapping by binary search thru lookup array
!
! valid questions are 'elem', 'node'
!***********************************************************
 FUNCTION mesh_FEasCP(what,id)
 
 use prec, only: pInt
 use IO, only: IO_lc
 implicit none
 
 character(len=*), intent(in) :: what
 integer(pInt), intent(in) :: id
 integer(pInt), dimension(:,:), pointer :: lookupMap
 integer(pInt) mesh_FEasCP, lower,upper,center
 
 mesh_FEasCP = 0_pInt
 select case(IO_lc(what(1:4)))
   case('elem')
     lookupMap => mesh_mapFEtoCPelem
   case('node')
     lookupMap => mesh_mapFEtoCPnode
   case default
     return
 end select
 
 lower = 1_pInt
 upper = size(lookupMap,2)
 
 ! check at bounds QUESTION is it valid to extend bounds by 1 and just do binary search w/o init check at bounds?
 if (lookupMap(1,lower) == id) then
   mesh_FEasCP = lookupMap(2,lower)
   return
 elseif (lookupMap(1,upper) == id) then
   mesh_FEasCP = lookupMap(2,upper)
   return
 endif
 
 ! binary search in between bounds
 do while (upper-lower > 1)
   center = (lower+upper)/2
   if (lookupMap(1,center) < id) then
     lower = center
   elseif (lookupMap(1,center) > id) then
     upper = center
   else
     mesh_FEasCP = lookupMap(2,center)
     exit
   end if
 end do
 return
 
 END FUNCTION


!***********************************************************
! find face-matching element of same type
!!***********************************************************
 FUNCTION mesh_faceMatch(face,elem)

 use prec, only: pInt
 implicit none

 integer(pInt) face,elem
 integer(pInt) mesh_faceMatch
 integer(pInt), dimension(FE_NfaceNodes(face,mesh_element(2,elem))) :: nodeMap
 integer(pInt) minN,NsharedElems,lonelyNode,faceNode,i,n,t
 
 minN = mesh_maxNsharedElems+1 ! init to worst case
 mesh_faceMatch = 0_pInt       ! intialize to "no match found"
 t = mesh_element(2,elem)      ! figure elemType

 do faceNode=1,FE_NfaceNodes(face,t)  ! loop over nodes on face
   nodeMap(faceNode) = mesh_FEasCP('node',mesh_element(4+FE_nodeOnFace(faceNode,face,t),elem)) ! CP id of face node
   NsharedElems = mesh_sharedElem(1,nodeMap(faceNode)) ! figure # shared elements for this node
   if (NsharedElems < minN) then
     minN = NsharedElems       ! remember min # shared elems
     lonelyNode = faceNode     ! remember most lonely node
   endif
 end do
candidate: do i=1,minN  ! iterate over lonelyNode's shared elements
   mesh_faceMatch = mesh_sharedElem(1+i,nodeMap(lonelyNode)) ! present candidate elem
   if (mesh_faceMatch == elem) then   ! my own element ?
     mesh_faceMatch = 0_pInt          ! disregard
     cycle candidate
   endif
   do faceNode=1,FE_NfaceNodes(face,t) ! check remaining face nodes to match
     if (faceNode == lonelyNode) cycle ! disregard lonely node (matches anyway)
	 n = nodeMap(faceNode)
     if (all(mesh_sharedElem(2:1+mesh_sharedElem(1,n),n) /= mesh_faceMatch)) then  ! no ref to candidate elem?
       mesh_faceMatch = 0_pInt         ! set to "no match" (so far)
       cycle candidate                 ! next candidate elem
     endif
   end do
   exit        ! surviving candidate
 end do candidate
  
 return
 
 END FUNCTION


!********************************************************************
! get count of elements, nodes, and cp elements in mesh
! for subsequent array allocations
!
! assign globals:
! _Nelems, _Nnodes, _NcpElems
!********************************************************************
 SUBROUTINE mesh_get_meshDimensions (unit)

 use prec, only: pInt
 use IO
 implicit none

 integer(pInt) unit,i,pos(41)
 character*300 line

610 FORMAT(A300)

 rewind(unit)
 do 
   read (unit,610,END=620) line
   pos = IO_stringPos(line,20)

   select case ( IO_lc(IO_StringValue(line,pos,1)))
     case('table')
       if (pos(1) == 6) then
         initialcondTableStyle = IO_IntValue (line,pos,4)
         hypoelasticTableStyle = IO_IntValue (line,pos,5)
       endif
     case('sizing')
       mesh_Nelems = IO_IntValue (line,pos,3)
       mesh_Nnodes = IO_IntValue (line,pos,4)
     case('define')
       select case (IO_lc(IO_StringValue(line,pos,2)))
          case('element')                                ! Count the number of encountered element sets
            mesh_NelemSets=mesh_NelemSets+1
            mesh_maxNelemInSet = max(mesh_maxNelemInSet,IO_countContinousIntValues(unit))
        end select
     case('hypoelastic')
       do i=1,3+hypoelasticTableStyle  ! Skip 3 or 4 lines
         read (unit,610,END=620) line
       end do
       mesh_NcpElems = mesh_NcpElems + IO_countContinousIntValues(unit)
   end select

 end do

620 return
 
 END SUBROUTINE

 
!!********************************************************************
! get maximum count of nodes, IPs, IP neighbors, and shared elements
! for subsequent array allocations
!
! assign globals:
! _maxNnodes, _maxNips, _maxNipNeighbors, _maxNsharedElems
!********************************************************************
 SUBROUTINE mesh_get_nodeElemDimensions (unit)
 
 use prec, only: pInt
 use IO
 implicit none
 
 integer(pInt), dimension (mesh_Nnodes) :: node_count
 integer(pInt), dimension (:), allocatable :: node_seen
 integer(pInt) unit,i,j,n,t,e
 integer(pInt), dimension (133) :: pos
 character*300 line
 
610 FORMAT(A300)
 
 node_count = 0_pInt
 allocate(node_seen(maxval(FE_Nnodes)))
 
 rewind(unit)
 do
   read (unit,610,END=630) line
   pos = IO_stringPos(line,1)
   if( IO_lc(IO_stringValue(line,pos,1)) == 'connectivity' ) then
     read (unit,610,END=630) line  ! Garbage line
     do i=1,mesh_Nelems            ! read all elements
       read (unit,610,END=630) line
       pos = IO_stringPos(line,66)  ! limit to 64 nodes max (plus ID, type)
       e = mesh_FEasCP('elem',IO_intValue(line,pos,1))
       if (e /= 0) then
         t = FE_mapElemtype(IO_StringValue(line,pos,2))
         mesh_maxNnodes =       max(mesh_maxNnodes,FE_Nnodes(t))
         mesh_maxNips =         max(mesh_maxNips,FE_Nips(t))
         mesh_maxNipNeighbors = max(mesh_maxNipNeighbors,FE_NipNeighbors(t))

         mesh_maxNsubNodes =    max(mesh_maxNsubNodes,FE_NsubNodes(t))

         node_seen = 0_pInt
         do j=1,FE_Nnodes(t)
           n = mesh_FEasCP('node',IO_IntValue (line,pos,j+2))
           if (all(node_seen /= n)) then
             node_count(n) = node_count(n)+1
           end if
           node_seen(j) = n
         end do
       end if
     end do
     exit
   end if
 end do
 
630 mesh_maxNsharedElems = maxval(node_count)
 
 return
 END SUBROUTINE
 
!********************************************************************
! Build element set mapping 
!
! allocate globals: mesh_nameElemSet, mesh_mapElemSet
!********************************************************************
 SUBROUTINE mesh_build_elemSetMapping (unit)

 use prec, only: pInt
 use IO

 implicit none

 integer unit, elem_set
 character*300 line
 integer(pInt), dimension (9) :: pos          ! count plus 4 entities on a line

610 FORMAT(A300)

 allocate (mesh_nameElemSet(mesh_NelemSets))
 allocate (mesh_mapElemSet(1+mesh_maxNelemInSet,mesh_NelemSets)) ; mesh_mapElemSet = 0_pInt
 elem_set = 0_pInt

 rewind(unit)
 do
   read (unit,610,END=620) line
   pos = IO_stringPos(line,4)
   if( (IO_lc(IO_stringValue(line,pos,1)) == 'define' ).and.   &
       (IO_lc(IO_stringValue(line,pos,2)) == 'element' ) )then
      elem_set = elem_set+1
      mesh_nameElemSet(elem_set) = IO_stringValue(line,pos,4)
      mesh_mapElemSet(:,elem_set) = IO_continousIntValues(unit,mesh_maxNelemInSet,mesh_nameElemSet,mesh_mapElemSet,mesh_NelemSets)
   end if
 end do

620 return
 END SUBROUTINE

 
!********************************************************************
! Build node mapping from FEM to CP
!
! allocate globals:
! _mapFEtoCPnode
!********************************************************************
 SUBROUTINE mesh_build_nodeMapping (unit)

 use prec, only: pInt
 use math, only: qsort
 use IO
 implicit none

 integer(pInt), dimension (mesh_Nnodes) :: node_count
 integer(pInt) unit,i
 integer(pInt), dimension (133) :: pos
 character*300 line

610 FORMAT(A300)

 allocate (mesh_mapFEtoCPnode(2,mesh_Nnodes)) ; mesh_mapFEtoCPnode = 0_pInt
 node_count(:) = 0_pInt

 rewind(unit)
 do
   read (unit,610,END=620) line
   pos = IO_stringPos(line,1)
   if( IO_lc(IO_stringValue(line,pos,1)) == 'coordinates' ) then
     read (unit,610,END=620) line  ! skip crap line
     do i=1,mesh_Nnodes
       read (unit,610,END=620) line
       mesh_mapFEtoCPnode(1,i) = IO_fixedIntValue (line,(/0,10/),1)
       mesh_mapFEtoCPnode(2,i) = i
     end do
	 exit
   end if
 end do

620 call qsort(mesh_mapFEtoCPnode,1,size(mesh_mapFEtoCPnode,2))

 return
 END SUBROUTINE


!********************************************************************
! Build element mapping from FEM to CP
!
! allocate globals:
! _mapFEtoCPelem
!********************************************************************
 SUBROUTINE mesh_build_elemMapping (unit)

 use prec, only: pInt
 use math, only: qsort
 use IO

 implicit none

 integer unit, i,CP_elem
 character*300 line
 integer(pInt), dimension (3) :: pos
 integer(pInt), dimension (1+mesh_NcpElems) :: contInts


610 FORMAT(A300)

 allocate (mesh_mapFEtoCPelem(2,mesh_NcpElems)) ; mesh_mapFEtoCPelem = 0_pInt
 CP_elem = 0_pInt

 rewind(unit)
 do
   read (unit,610,END=620) line
   pos = IO_stringPos(line,1)
   if( IO_lc(IO_stringValue(line,pos,1)) == 'hypoelastic' ) then
     do i=1,3+hypoelasticTableStyle          ! skip three (or four if new table style!) lines
       read (unit,610,END=620) line 
     end do
     contInts = IO_continousIntValues(unit,mesh_NcpElems,mesh_nameElemSet,mesh_mapElemSet,mesh_NelemSets)
     do i = 1,contInts(1)
       CP_elem = CP_elem+1
       mesh_mapFEtoCPelem(1,CP_elem) = contInts(1+i)
       mesh_mapFEtoCPelem(2,CP_elem) = CP_elem
     enddo
   end if
 end do

620 call qsort(mesh_mapFEtoCPelem,1,size(mesh_mapFEtoCPelem,2))  ! should be mesh_NcpElems

 return
 END SUBROUTINE


!********************************************************************
! store x,y,z coordinates of all nodes in mesh
!
! allocate globals:
! _node
!********************************************************************
 SUBROUTINE mesh_build_nodes (unit)

 use prec, only: pInt
 use IO
 implicit none

 integer unit,i,j,m
 integer(pInt), dimension(3) :: pos
 integer(pInt), dimension(5), parameter :: node_ends = (/0,10,30,50,70/)
 character*300 line

 allocate ( mesh_node (3,mesh_Nnodes) )
 mesh_node(:,:) = 0_pInt

610 FORMAT(A300)

 rewind(unit)
 do
   read (unit,610,END=620) line
   pos = IO_stringPos(line,1)
   if( IO_lc(IO_stringValue(line,pos,1)) == 'coordinates' ) then
     read (unit,610,END=620) line ! skip crap line
     do i=1,mesh_Nnodes
       read (unit,610,END=620) line
       m = mesh_FEasCP('node',IO_fixedIntValue (line,node_ends,1))
       do j=1,3
         mesh_node(j,m) = IO_fixedNoEFloatValue (line,node_ends,j+1)
       end do
     end do
     exit
   end if
 end do

620 return

 END SUBROUTINE


!********************************************************************
! store FEid, type, mat, tex, and node list per element
!
! allocate globals:
! _element
!********************************************************************
 SUBROUTINE mesh_build_elements (unit)

 use prec, only: pInt
 use IO
 implicit none

 integer unit,i,j,sv,val,CP_elem
 integer(pInt), dimension(133) :: pos
 integer(pInt), dimension(1+mesh_NcpElems) :: contInts
 character*300 line

 allocate (mesh_element (4+mesh_maxNnodes,mesh_NcpElems)) ; mesh_element = 0_pInt

610 FORMAT(A300)


 rewind(unit)
 do
   read (unit,610,END=620) line
   pos = IO_stringPos(line,2)
   if( IO_lc(IO_stringValue(line,pos,1)) == 'connectivity' ) then
     read (unit,610,END=620) line  ! Garbage line
	 do i=1,mesh_Nelems
	   read (unit,610,END=620) line
	   pos = IO_stringPos(line,66)  ! limit to 64 nodes max (plus ID, type)
	   CP_elem = mesh_FEasCP('elem',IO_intValue(line,pos,1))
	   if (CP_elem /= 0) then ! disregard non CP elems
	     mesh_element (1,CP_elem) = IO_IntValue (line,pos,1)                     ! FE id
	     mesh_element (2,CP_elem) = FE_mapElemtype(IO_StringValue (line,pos,2))  ! elem type
         do j=1,FE_Nnodes(mesh_element(2,CP_elem))
           mesh_element(j+4,CP_elem) = IO_IntValue (line,pos,j+2) ! copy FE ids of nodes
	     end do
	   end if
     end do
     exit
   endif
 enddo
 
 rewind(unit) ! just in case "initial state" apears before "connectivity"
 read (unit,610,END=620) line
 do
   pos = IO_stringPos(line,2)
   if( (IO_lc(IO_stringValue(line,pos,1)) == 'initial').and.    &
       (IO_lc(IO_stringValue(line,pos,2)) == 'state') ) then
     if (initialcondTableStyle == 2) read (unit,610,END=620) line  ! read extra line for new style     
     read (unit,610,END=620) line       ! read line with index of state var
     pos = IO_stringPos(line,1)
     sv = IO_IntValue (line,pos,1)      ! figure state variable index
     if( (sv == 2).or.(sv == 3) ) then  ! only state vars 2 and 3 of interest
       read (unit,610,END=620) line     ! read line with value of state var
       pos = IO_stringPos(line,1)
       do while (scan(IO_stringValue(line,pos,1),'+-',back=.true.)>1)  ! is noEfloat value?
         val = NINT(IO_fixedNoEFloatValue (line,(/0,20/),1)) ! state var's value
         mesh_maxValStateVar(sv-1) = max(val,mesh_maxValStateVar(sv-1))  ! remember max val of material and texture index
         if (initialcondTableStyle == 2) then
           read (unit,610,END=620) line  ! read extra line     
           read (unit,610,END=620) line  ! read extra line     
         endif
         contInts = IO_continousIntValues(unit,mesh_Nelems,mesh_nameElemSet,mesh_mapElemSet,mesh_NelemSets)  ! get affected elements
         do i = 1,contInts(1)
           CP_elem = mesh_FEasCP('elem',contInts(1+i))
           mesh_element(1+sv,CP_elem) = val
         enddo
         if (initialcondTableStyle == 0) read (unit,610,END=620) line  ! ignore IP range for old table style
         read (unit,610,END=620) line
         pos = IO_stringPos(line,1)
       enddo
     endif
   else   
     read (unit,610,END=620) line
   endif
 enddo

620 return

 END SUBROUTINE

 
!********************************************************************
! build list of elements shared by each node in mesh
!
! allocate globals:
! _sharedElem
!********************************************************************
 SUBROUTINE mesh_build_sharedElems (unit)

 use prec, only: pInt
 use IO
 implicit none

 integer(pint) unit,i,j,n,e
 integer(pInt), dimension (133) :: pos
 integer(pInt), dimension (:), allocatable :: node_seen
 character*300 line

610 FORMAT(A300)

 allocate(node_seen(maxval(FE_Nnodes)))
 allocate ( mesh_sharedElem( 1+mesh_maxNsharedElems,mesh_Nnodes) )
 mesh_sharedElem(:,:) = 0_pInt

 rewind(unit)
 do
   read (unit,610,END=620) line
   pos = IO_stringPos(line,1)
   if( IO_lc(IO_stringValue(line,pos,1)) == 'connectivity' ) then
     read (unit,610,END=620) line  ! Garbage line
	 do i=1,mesh_Nelems
	   read (unit,610,END=620) line
	   pos = IO_stringPos(line,66)  ! limit to 64 nodes max (plus ID, type)
	   e = mesh_FEasCP('elem',IO_IntValue(line,pos,1))
	   if (e /= 0) then  ! disregard non CP elems
	     node_seen = 0_pInt
         do j = 1,FE_Nnodes(FE_mapElemtype(IO_StringValue(line,pos,2)))
           n = mesh_FEasCP('node',IO_IntValue (line,pos,j+2))
           if (all(node_seen /= n)) then
		     mesh_sharedElem(1,n) = mesh_sharedElem(1,n) + 1
		     mesh_sharedElem(1+mesh_sharedElem(1,n),n) = e
           end if
           node_seen(j) = n
		 enddo
	   end if
     end do
     exit
   end if
 end do

620 return

 END SUBROUTINE
 

!***********************************************************
! build up of IP neighborhood
!
! allocate globals
! _ipNeighborhood
!***********************************************************
 SUBROUTINE mesh_build_ipNeighborhood()
 
 use prec, only: pInt
 implicit none
 
 integer(pInt) e,t,i,j,k,n
 integer(pInt) neighbor,neighboringElem,neighboringIP,matchingElem,faceNode,linkingNode

 allocate(mesh_ipNeighborhood(2,mesh_maxNipNeighbors,mesh_maxNips,mesh_NcpElems)) ; mesh_ipNeighborhood = 0_pInt
 
 do e = 1,mesh_NcpElems                  ! loop over cpElems
   t = mesh_element(2,e)                 ! get elemType
   do i = 1,FE_Nips(t)                   ! loop over IPs of elem
     do n = 1,FE_NipNeighbors(t)         ! loop over neighbors of IP
       neighbor = FE_ipNeighbor(n,i,t)
      if (neighbor > 0) then ! intra-element IP
         neighboringElem = e
         neighboringIP   = neighbor
       else                   ! neighboring element's IP
         neighboringElem = 0_pInt
         neighboringIP = 0_pInt
         matchingElem = mesh_faceMatch(-neighbor,e)   ! get CP elem id of face match
         if (matchingElem > 0 .and. &
		     mesh_element(2,matchingElem) == t) then  ! found match of same type?
matchFace: do j = 1,FE_NfaceNodes(-neighbor,t)        ! count over nodes on matching face
             faceNode = FE_nodeOnFace(j,-neighbor,t)  ! get face node id
             if (i == FE_ipAtNode(faceNode,t)) then   ! ip linked to face node is me?
               linkingNode = mesh_element(4+faceNode,e) ! FE id of this facial node
               do k = 1,FE_Nnodes(t)   ! loop over nodes in matching element
                 if (linkingNode == mesh_element(4+k,matchingElem)) then
                   neighboringElem = matchingElem
                   neighboringIP = FE_ipAtNode(k,t)
                   exit matchFace
                 endif
               end do
             endif
           end do matchFace
         endif
       endif
       mesh_ipNeighborhood(1,n,i,e) = neighboringElem
       mesh_ipNeighborhood(2,n,i,e) = neighboringIP
     end do
   end do
 end do
 
 return

 END SUBROUTINE



!***********************************************************
! assignment of coordinates for subnodes in each cp element
!
! allocate globals
! _subNodeCoord
!***********************************************************
 SUBROUTINE mesh_build_subNodeCoords()
 
 use prec, only: pInt,pReal
 implicit none

 integer(pInt) e,t,n,p

 allocate(mesh_subNodeCoord(3,mesh_maxNnodes+mesh_maxNsubNodes,mesh_NcpElems)) ; mesh_subNodeCoord = 0.0_pReal
 
 do e = 1,mesh_NcpElems                   ! loop over cpElems
   t = mesh_element(2,e)                  ! get elemType
   do n = 1,FE_Nnodes(t)
     mesh_subNodeCoord(:,n,e) = mesh_node(:,mesh_FEasCP('node',mesh_element(4+n,e))) ! loop over nodes of this element type
   enddo
   do n = 1,FE_NsubNodes(t)               ! now for the true subnodes
     do p = 1,FE_Nnodes(t)                ! loop through parents
	   if (FE_subNodeParent(p,n,t) > 0) & ! valid parent node
         mesh_subNodeCoord(:,n+FE_Nnodes(t),e) = &
		 mesh_subNodeCoord(:,n+FE_Nnodes(t),e) + &
		 mesh_node(:,mesh_FEasCP('node',mesh_element(4+FE_subNodeParent(p,n,t),e))) ! add up parents
	 enddo
     mesh_subNodeCoord(:,n+FE_Nnodes(t),e) = mesh_subNodeCoord(:,n+FE_Nnodes(t),e) / count(FE_subNodeParent(:,n,t) > 0)
   enddo
 enddo 

 return
 
 END SUBROUTINE


!***********************************************************
! calculation of IP volume
!
! allocate globals
! _ipVolume
!***********************************************************
 SUBROUTINE mesh_build_ipVolumes()
 
 use prec, only: pInt
 use math, only: math_volTetrahedron
 implicit none
 
 integer(pInt) e,f,t,i,j,k,n
 integer(pInt), parameter :: Ntriangles = FE_NipFaceNodes-2                     ! each interface is made up of this many triangles
 integer(pInt), dimension(mesh_maxNnodes+mesh_maxNsubNodes) :: gravityNode      ! flagList to find subnodes determining center of grav
 real(pReal), dimension(3,mesh_maxNnodes+mesh_maxNsubNodes) :: gravityNodePos   ! coordinates of subnodes determining center of grav
 real(pReal), dimension (3,FE_NipFaceNodes) :: nPos                             ! coordinates of nodes on IP face
 real(pReal), dimension(Ntriangles,FE_NipFaceNodes) :: volume                   ! volumes of possible tetrahedra
 real(pReal), dimension(3) :: centerOfGravity

 allocate(mesh_ipVolume(mesh_maxNips,mesh_NcpElems)) ; mesh_ipVolume = 0.0_pReal
 
 do e = 1,mesh_NcpElems                  ! loop over cpElems
   t = mesh_element(2,e)                 ! get elemType
   do i = 1,FE_Nips(t)                   ! loop over IPs of elem
     gravityNode = 0_pInt                ! reset flagList
     gravityNodePos = 0.0_pReal          ! reset coordinates
     do f = 1,FE_NipNeighbors(t)         ! loop over interfaces of IP
	   do n = 1,FE_NipFaceNodes          ! loop over nodes on interface
         gravityNode(FE_subNodeOnIPFace(n,f,i,t)) = 1
         gravityNodePos(:,FE_subNodeOnIPFace(n,f,i,t)) = mesh_subNodeCoord(:,FE_subNodeOnIPFace(n,f,i,t),e)
       enddo
     enddo
     
	 do j = 1,mesh_maxNnodes+mesh_maxNsubNodes-1        ! walk through entire flagList except last
       if (gravityNode(j) > 0_pInt) then                ! valid node index
         do k = j+1,mesh_maxNnodes+mesh_maxNsubNodes    ! walk through remainder of list
           if (all((gravityNodePos(:,j) - gravityNodePos(:,k)) == 0.0_pReal)) then   ! found match
		     gravityNode(j) = 0_pInt                    ! delete first instance
		     gravityNodePos(:,j) = 0.0_pReal
		     exit                                       ! continue with next suspect
		   endif
		 enddo
	   endif
	 enddo
     centerOfGravity = sum(gravityNodePos,2)/count(gravityNode > 0)

     do f = 1,FE_NipNeighbors(t)         ! loop over interfaces of IP and add tetrahedra which connect to CoG
	   forall (n = 1:FE_NipFaceNodes) nPos(:,n) = mesh_subNodeCoord(:,FE_subNodeOnIPFace(n,f,i,t),e)
       forall (n = 1:FE_NipFaceNodes, j = 1:Ntriangles) &  ! start at each interface node and build valid triangles to cover interface
         volume(j,n) = math_volTetrahedron(nPos(:,n), &    ! calc volume of respective tetrahedron to CoG
                                           nPos(:,1+mod(n+j-1,FE_NipFaceNodes)), &
                                           nPos(:,1+mod(n+j-0,FE_NipFaceNodes)), &
                                           centerOfGravity)
       mesh_ipVolume(i,e) = mesh_ipVolume(i,e) + sum(volume)    ! add contribution from this interface
	 enddo
     mesh_ipVolume(i,e) = mesh_ipVolume(i,e) / FE_NipFaceNodes  ! renormalize with interfaceNodeNum due to loop over them
   enddo
 enddo
 return
 
 END SUBROUTINE


!***********************************************************
! calculation of IP interface areas
!
! allocate globals
! _ipArea, _ipAreaNormal
!***********************************************************
 SUBROUTINE mesh_build_ipAreas()
 
 use prec, only: pInt,pReal
 use math
 implicit none
 
 integer(pInt) e,f,t,i,j,k,n
 integer(pInt), parameter :: Ntriangles = FE_NipFaceNodes-2    ! each interface is made up of this many triangles
 real(pReal), dimension (3,FE_NipFaceNodes) :: nPos            ! coordinates of nodes on IP face
 real(pReal), dimension(3,Ntriangles,FE_NipFaceNodes) :: normal
 real(pReal), dimension(Ntriangles,FE_NipFaceNodes)   :: area

 allocate(mesh_ipArea(mesh_maxNipNeighbors,mesh_maxNips,mesh_NcpElems)) ;         mesh_ipArea       = 0.0_pReal
 allocate(mesh_ipAreaNormal(3,mesh_maxNipNeighbors,mesh_maxNips,mesh_NcpElems)) ; mesh_ipAreaNormal = 0.0_pReal
 
 do e = 1,mesh_NcpElems                     ! loop over cpElems
   t = mesh_element(2,e)                    ! get elemType
   do i = 1,FE_Nips(t)                      ! loop over IPs of elem
     do f = 1,FE_NipNeighbors(t)            ! loop over interfaces of IP 
	   forall (n = 1:FE_NipFaceNodes) nPos(:,n) = mesh_subNodeCoord(:,FE_subNodeOnIPFace(n,f,i,t),e)
       forall (n = 1:FE_NipFaceNodes, j = 1:Ntriangles)   ! start at each interface node and build valid triangles to cover interface
         normal(:,j,n) = math_vectorproduct(nPos(:,1+mod(n+j-1,FE_NipFaceNodes)) - nPos(:,n), &    ! calc their normal vectors
                                            nPos(:,1+mod(n+j-0,FE_NipFaceNodes)) - nPos(:,n))
         area(j,n) = dsqrt(sum(normal(:,j,n)*normal(:,j,n)))                                       ! and area
       end forall
	   forall (n = 1:FE_NipFaceNodes, j = 1:Ntriangles, area(j,n) > 0.0_pReal) &
	     normal(:,j,n) = normal(:,j,n) / area(j,n)        ! make unit normal

       mesh_ipArea(f,i,e) = sum(area) / (FE_NipFaceNodes*2.0_pReal)          ! area of parallelograms instead of triangles
	   mesh_ipAreaNormal(:,f,i,e) = sum(sum(normal,3),2) / count(area > 0.0_pReal)  ! average of all valid normals
     enddo
   enddo
 enddo
 return
 
 END SUBROUTINE


!***********************************************************
! write statistics regarding input file parsing
! to the output file
! 
!***********************************************************
 SUBROUTINE mesh_tell_statistics()

 use prec, only: pInt
 use math, only: math_range
 use IO, only: IO_error

 implicit none

 integer(pInt), dimension (:,:), allocatable :: mesh_MatTex
 character(len=64) fmt

 integer(pInt) i,e,f

 if (mesh_maxValStateVar(1) == 0) call IO_error(110) ! no materials specified
 if (mesh_maxValStateVar(2) == 0) call IO_error(120) ! no textures specified
   
 allocate (mesh_MatTex(mesh_maxValStateVar(1),mesh_maxValStateVar(2)))
 mesh_MatTex = 0_pInt
 do i=1,mesh_NcpElems
   mesh_MatTex(mesh_element(3,i),mesh_element(4,i)) = &
   mesh_MatTex(mesh_element(3,i),mesh_element(4,i)) + 1 ! count combinations of material and texture
 enddo
 
!$OMP CRITICAL (write2out)

 write (6,*)
 write (6,*) "Input Parser: IP NEIGHBORHOOD"
 write (6,*)
 write (6,"(a13,x,e15.8)") "total volume", sum(mesh_ipVolume)
 write (6,*)
 write (6,"(a5,x,a5,x,a15,x,a5,x,a15,x,a16)") "elem","IP","volume","face","area","-- normal --"
 do e = 1,mesh_NcpElems
   do i = 1,FE_Nips(mesh_element(2,e))
     write (6,"(i5,x,i5,x,e15.8)") e,i,mesh_IPvolume(i,e)
     do f = 1,FE_NipNeighbors(mesh_element(2,e))
!       write (6,"(i33,x,e15.8,x,3(f6.3,x))") f,mesh_ipArea(f,i,e),mesh_ipAreaNormal(:,f,i,e)
     enddo
   enddo
 enddo
 write (6,*)
 write (6,*) "Input Parser: STATISTICS"
 write (6,*)
 write (6,*) mesh_Nelems,           " : total number of elements in mesh"
 write (6,*) mesh_NcpElems,         " : total number of CP elements in mesh"
 write (6,*) mesh_Nnodes,           " : total number of nodes in mesh"
 write (6,*) mesh_maxNnodes,        " : max number of nodes in any CP element"
 write (6,*) mesh_maxNips,          " : max number of IPs in any CP element"
 write (6,*) mesh_maxNipNeighbors,  " : max number of IP neighbors in any CP element"
 write (6,*) mesh_maxNsubNodes,     " : max number of (additional) subnodes in any CP element"
 write (6,*) mesh_maxNsharedElems,  " : max number of CP elements sharing a node"
 write (6,*)
 write (6,*) "Input Parser: HOMOGENIZATION/MICROSTRUCTURE"
 write (6,*)
 write (6,*) mesh_maxValStateVar(1), " : maximum homogenization index"
 write (6,*) mesh_maxValStateVar(2), " : maximum microstructure index"
 write (6,*)
 write (fmt,"(a,i3,a)") "(9(x),a1,x,",mesh_maxValStateVar(2),"(i8))"
 write (6,fmt) "+",math_range(mesh_maxValStateVar(2))
 write (fmt,"(a,i3,a)") "(i8,x,a1,x,",mesh_maxValStateVar(2),"(i8))"
 do i=1,mesh_maxValStateVar(1)      ! loop over all (possibly assigned) materials
   write (6,fmt) i,"|",mesh_MatTex(i,:) ! loop over all (possibly assigned) textures
 enddo
 write (6,*)
!$OMP END CRITICAL (write2out)


 return
 
 END SUBROUTINE
 
 
 END MODULE mesh
 
