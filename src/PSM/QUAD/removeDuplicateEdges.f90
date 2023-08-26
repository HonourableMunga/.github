subroutine removeDuplicateEdges(nedge0, nedge, ids, &
     edges0, edgeCon0, edges, edgeCon)

  implicit none

  !Fortran-python interface directives
  !f2py intent(in) nedge0, nedge, ids, edges0, edgeCon0
  !f2py intent(out) edges, edgeCon
  !f2py depend(nedge0) ids, edges0, edgeCon0
  !f2py depend(nedge) edges, edgeCon

  !Input
  integer, intent(in) ::  nedge0, nedge, ids(nedge0), edges0(nedge0,2)
  logical, intent(in) ::  edgeCon0(nedge0)

  !Output
  integer, intent(out) ::  edges(nedge,2)
  logical, intent(out) ::  edgeCon(nedge)

  !Working
  integer iedge0

  do iedge0=1,nedge0
     edges(ids(iedge0),:) = edges0(iedge0,:)
     edgeCon(ids(iedge0)) = edgeCon0(iedge0)
  end do

end subroutine removeDuplicateEdges




subroutine computeUniqueEdges(nedge, edges, nid, ids)

  implicit none

  !Fortran-python interface directives
  !f2py intent(in) nedge, edges
  !f2py intent(out) nid, ids
  !f2py depend(nedge) edges

  !Input
  integer, intent(in) ::  nedge, edges(nedge,2)

  !Output
  integer, intent(out) ::  nid, ids(nedge)

  !Working
  integer i1, i2

  ids(:) = 0
  nid = 0
  do i1=1,nedge
     if (ids(i1) .eq. 0) then
        nid = nid + 1
        ids(i1) = nid
        do i2=i1+1,nedge
           if (ids(i2) .eq. 0) then
              if ((edges(i1,1).eq.edges(i2,1)) .and. &
                   (edges(i1,2).eq.edges(i2,2))) then
                 ids(i2) = ids(i1)
              else if ((edges(i1,2).eq.edges(i2,1)) .and. &
                   (edges(i1,1).eq.edges(i2,2))) then
                 ids(i2) = ids(i1)
              end if
           end if
        end do
     end if
  end do

end subroutine computeUniqueEdges
