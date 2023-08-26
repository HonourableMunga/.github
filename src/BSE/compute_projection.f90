subroutine computeproj(npt_proj, nsurf_proj, &
     ncp_str, npt_str, nsurf, ngroup, nrefine, &
     surf_proj, str_indices_cp, str_indices_pt, &
     surf_group, order, num_cp, num_pt, &
     cp_str, pt_str, pt_proj, &
     min_s, min_tu, min_tv)

  implicit none

  !Fortran-python interface directives
  !f2py intent(in) npt_proj, nsurf_proj, ncp_str, npt_str, nsurf, ngroup, nrefine, surf_proj, str_indices_cp, str_indices_pt, surf_group, order, num_cp, num_pt, cp_str, pt_str, pt_proj
  !f2py intent(out) min_s, min_tu, min_tv
  !f2py depend(nsurf_proj) surf_proj
  !f2py depend(nsurf) str_indices_cp, str_indices_pt, surf_group
  !f2py depend(ngroup) order, num_cp, num_pt
  !f2py depend(ncp_str) cp_str
  !f2py depend(npt_str) pt_str
  !f2py depend(npt_proj) pt_proj
  !f2py depend(npt_proj) min_s, min_tu, min_tv

  !Input
  integer, intent(in) ::  npt_proj, nsurf_proj
  integer, intent(in) ::  ncp_str, npt_str, nsurf, ngroup, nrefine
  integer, intent(in) ::  surf_proj(nsurf_proj)
  integer, intent(in) ::  str_indices_cp(nsurf, 2)
  integer, intent(in) ::  str_indices_pt(nsurf, 2)
  integer, intent(in) ::  surf_group(nsurf, 2), order(ngroup)
  integer, intent(in) ::  num_cp(ngroup), num_pt(ngroup)
  double precision, intent(in) ::  cp_str(ncp_str, 3)
  double precision, intent(in) ::  pt_str(npt_str, 3)
  double precision, intent(in) ::  pt_proj(npt_proj, 3)

  !Output
  integer, intent(out) ::  min_s(npt_proj)
  double precision, intent(out) ::  min_tu(npt_proj)
  double precision, intent(out) ::  min_tv(npt_proj)

  !Working
  double precision min_d(npt_proj)
  integer isurf_proj, isurf, ipt_proj
  integer offset_cp, offset_pt, offset_u, offset_v
  integer ku, kv, mu, mv, nu, nv
  integer u, v, uu, vv
  integer u1, u2, v1, v2
  integer lu, lv, hu, hv
  integer min_s_local
  double precision tu, tv
  double precision min_d_local, min_tu_local, min_tv_local
  double precision pt0(3), pt(3), d
  double precision P(3), P00(3), P01(3), P10(3), P11(3)
  double precision x(2), x0(2)
  logical fail
  double precision normal0(3), normal1(3), normal2(3), normal3(3), normal4(3)
  double precision, allocatable, dimension(:) ::  knot_u, knot_v
  double precision, allocatable, dimension(:) ::  param_u, param_v
  double precision, allocatable, dimension(:) ::  bu0, bv0
  double precision, allocatable, dimension(:, :, :) ::  cp

  min_d(:) = 1e10
  min_s(:) = 1
  min_tu(:) = 1.0
  min_tv(:) = 1.0

  do isurf_proj = 1, nsurf_proj
     isurf = surf_proj(isurf_proj)
     offset_cp = str_indices_cp(isurf, 1)
     offset_pt = str_indices_pt(isurf, 1)

     ku = order(surf_group(isurf, 1))
     kv = order(surf_group(isurf, 2))
     mu = num_cp(surf_group(isurf, 1))
     mv = num_cp(surf_group(isurf, 2))
     nu = num_pt(surf_group(isurf, 1))
     nv = num_pt(surf_group(isurf, 2))

     allocate(knot_u(ku + mu))
     call knotopen(ku, ku+mu, knot_u)

     allocate(knot_v(kv + mv))
     call knotopen(kv, kv+mv, knot_v)

     allocate(param_u(nu))
     call paramuni(ku+mu, mu, nu, knot_u, param_u)

     allocate(param_v(nv))
     call paramuni(kv+mv, mv, nv, knot_v, param_v)

     allocate(bu0(ku))
     allocate(bv0(kv))

     allocate(cp(mu, mv, 3))
     do u = 1, mu
        do v = 1, mv
           cp(u, v, :) = &
                cp_str(offset_cp + (v-1)*mu + u, :)
        end do
     end do

     do ipt_proj = 1, npt_proj
        pt0 = pt_proj(ipt_proj, :)

        min_d_local = 1e10
        min_s_local = 1
        min_tu_local = 0.0
        min_tv_local = 0.0
        do u = 1, nu ! ceiling(nu/100.0)
           do v = 1, nv ! ceiling(nv/100.0)
              pt = pt_str(offset_pt + (v-1)*nu + u, :)
              d = abs(dot_product(pt - pt0, pt - pt0))
              if (d .lt. min_d_local) then
                 min_d_local = d
                 min_s_local = isurf
                 min_tu_local = param_u(u)
                 min_tv_local = param_v(v)
              end if
           end do
        end do
        if (min_d_local .lt. min_d(ipt_proj)) then
           min_d(ipt_proj) = min_d_local
           min_s(ipt_proj) = min_s_local
           min_tu(ipt_proj) = min_tu_local
           min_tv(ipt_proj) = min_tv_local
        end if

        x0(1) = min_tu_local
        x0(2) = min_tv_local
        call newtonprojection(ku, kv, mu, mv, x0, pt0, cp, knot_u, knot_v, x, pt, fail)

        d = abs(dot_product(pt - pt0, pt - pt0))
        if (d .lt. min_d(ipt_proj)) then
           min_d(ipt_proj) = d
           min_s(ipt_proj) = isurf
           min_tu(ipt_proj) = x(1)
           min_tv(ipt_proj) = x(2)
        end if

        !Check if Newton Search converged
        if (fail) then !We will refine a cell to get a better starting point for the Newton Search
           do u = 1, nu-1 !Looping over each surface point
              u1 = u
              u2 = u + 1
              do v = 1, nv-1
                 v1 = v
                 v2 = v + 1

                 !Get the corner points of the cell
                 P00 = pt_str(offset_pt + (v1-1)*nu + u1, :)
                 P10 = pt_str(offset_pt + (v1-1)*nu + u2, :)
                 P01 = pt_str(offset_pt + (v2-1)*nu + u1, :)
                 P11 = pt_str(offset_pt + (v2-1)*nu + u2, :)
                 call cross_product(P11 - P00, P01 - P10, normal0) !Find a vector normal to the cell
 
                 !Cross product between cell edges and the CFD point position with respect to point P00
                 call cross_product(pt0 - P00, P01 - P00, normal1) !u=0
                 call cross_product(pt0 - P01, P11 - P01, normal2) !v=1
                 call cross_product(pt0 - P11, P10 - P11, normal3) !u=1
                 call cross_product(pt0 - P10, P00 - P10, normal4) !v=0

                 !Identify if the point is above the cell
                 if (&
                      (dot_product(normal1, normal0) .ge. 0) .and. &
                      (dot_product(normal2, normal0) .ge. 0) .and. &
                      (dot_product(normal3, normal0) .ge. 0) .and. &
                      (dot_product(normal4, normal0) .ge. 0)) then
                    min_d_local = 1e10
                    min_s_local = 1
                    min_tu_local = 0.0
                    min_tv_local = 0.0
                    !Loop over refined points
                    do uu = 1, nrefine
                       tu = param_u(u1) + (param_u(u2) - param_u(u1)) * (uu-1) / (nrefine-1)
                       do vv = 1, nrefine
                          tv = param_v(v1) + (param_v(v2) - param_v(v1)) * (vv-1) / (nrefine-1)

                          !Compute physical coordinates of refined point
                          call basis0(ku, ku+mu, tu, knot_u, bu0, offset_u)
                          call basis0(kv, kv+mv, tv, knot_v, bv0, offset_v)
                          P(:) = 0.0
                          do lu = 1, ku
                             hu = lu + offset_u
                             do lv = 1, kv
                                hv = lv + offset_v
                                P = P + bu0(lu) * bv0(lv) * cp(hu, hv, :)
                             end do
                          end do
                          pt(:) = P(:)

                          !Compare refined point to the CFD mesh point
                          d = abs(dot_product(pt - pt0, pt - pt0))
                          if (d .lt. min_d_local) then
                             min_d_local = d
                             min_s_local = isurf
                             min_tu_local = tu
                             min_tv_local = tv
                          end if
                       end do
                    end do

                    !Compare best candidate with best candidate prior to the refinement
                    if (min_d_local .lt. min_d(ipt_proj)) then
                       min_d(ipt_proj) = min_d_local
                       min_s(ipt_proj) = min_s_local
                       min_tu(ipt_proj) = min_tu_local
                       min_tv(ipt_proj) = min_tv_local
                    end if
                    
                    !Call newton search to find u and v values
                    x0(1) = min_tu_local
                    x0(2) = min_tv_local
                    call newtonprojection(ku, kv, mu, mv, x0, pt0, cp, knot_u, knot_v, x, pt, fail)

                    d = abs(dot_product(pt - pt0, pt - pt0))
                    if (d .lt. min_d(ipt_proj)) then
                       min_d(ipt_proj) = d
                       min_s(ipt_proj) = isurf
                       min_tu(ipt_proj) = x(1)
                       min_tv(ipt_proj) = x(2)
                    end if
                    
                 end if
                 
              end do
           end do
        end if
        
     end do

     deallocate(knot_u)
     deallocate(knot_v)

     deallocate(param_u)
     deallocate(param_v)

     deallocate(bu0)
     deallocate(bv0)

     deallocate(cp)
  end do

end subroutine computeproj



subroutine newtonprojection(ku, kv, mu, mv, &
     x0, pt0, cp, knot_u, knot_v, x, pt, fail)

  implicit none

  !Input
  integer, intent(in) ::  ku, kv, mu, mv
  double precision, intent(in) ::  x0(2), pt0(3)
  double precision, intent(in) ::  cp(mu, mv, 3)
  double precision, intent(in) ::  knot_u(ku + mu), knot_v(kv + mv)

  !Output
  double precision, intent(out) ::  x(2), pt(3)
  logical, intent(out) ::  fail

  !Working
  integer offset_u, offset_v
  double precision bu0(ku), bu1(ku), bu2(ku)
  double precision bv0(kv), bv1(kv), bv2(kv)
  double precision P(3), Pu(3), Pv(3), Puu(3), Puv(3), Pvv(3)
  double precision f(3), g(2), H(2, 2), det
  double precision norm_g, norm_dx, norm_f, W(2, 2), dx(2)
  integer lu, lv, hu, hv, k, counter

  x(:) = x0(:)
  fail = .True.

  do counter = 0, 40
     call basis0(ku, ku+mu, x(1), knot_u, bu0, offset_u)
     call basis1(ku, ku+mu, x(1), knot_u, bu1, offset_u)
     call basis2(ku, ku+mu, x(1), knot_u, bu2, offset_u)
     call basis0(kv, kv+mv, x(2), knot_v, bv0, offset_v)
     call basis1(kv, kv+mv, x(2), knot_v, bv1, offset_v)
     call basis2(kv, kv+mv, x(2), knot_v, bv2, offset_v)

     P(:) = 0.0
     Pu(:) = 0.0
     Pv(:) = 0.0
     Puu(:) = 0.0
     Puv(:) = 0.0
     Pvv(:) = 0.0
     
     do lu = 1, ku
        hu = lu + offset_u
        do lv = 1, kv
           hv = lv + offset_v
           P   = P   + bu0(lu) * bv0(lv) * cp(hu, hv, :)
           Pu  = Pu  + bu1(lu) * bv0(lv) * cp(hu, hv, :)
           Pv  = Pv  + bu0(lu) * bv1(lv) * cp(hu, hv, :)
           Puu = Puu + bu2(lu) * bv0(lv) * cp(hu, hv, :)
           Puv = Puv + bu1(lu) * bv1(lv) * cp(hu, hv, :)
           Pvv = Pvv + bu0(lu) * bv2(lv) * cp(hu, hv, :)
        end do
     end do

     f = P - pt0
     g(1) = 2 * dot_product(f, Pu)
     g(2) = 2 * dot_product(f, Pv)
     H(1, 1) = 2 * dot_product(Pu, Pu) + 2 * dot_product(f, Puu)
     H(1, 2) = 2 * dot_product(Pu, Pv) + 2 * dot_product(f, Puv)
     H(2, 2) = 2 * dot_product(Pv, Pv) + 2 * dot_product(f, Pvv)
     H(2, 1) = H(1, 2)
     do k = 1, 2
        if (((x(k) .eq. 0) .and. (g(k) .gt. 0)) .or. &
             ((x(k) .eq. 1) .and. (g(k) .lt. 0))) then
           g(k) = 0.0
           H(1, 2) = 0.0
           H(2, 1) = 0.0
           H(k, k) = 1.0
        end if
     end do
     det = H(1, 1) * H(2, 2) - H(1, 2) * H(2, 1)
     W(1, 1) = H(2, 2) / det
     W(1, 2) = -H(1, 2) / det
     W(2, 2) = H(1, 1) / det
     W(2, 1) = W(1, 2)
     norm_g = sqrt(dot_product(g, g))
     dx(1) = -dot_product(W(1, :), g)
     dx(2) = -dot_product(W(2, :), g)
     do k = 1, 2
        if (x(k) + dx(k) .lt. 0) then
           dx(k) = -x(k)
        else if (x(k) + dx(k) .gt. 1) then
           dx(k) = 1 - x(k)
        end if
     end do
     norm_dx = sqrt(dot_product(dx, dx))
     norm_f = sqrt(dot_product(f, f))

     ! print *, counter, norm
     if (((norm_g .lt. 1e-13) .or. (norm_dx .lt. 1e-13)) .and. &
          (norm_f .lt. 1e-6)) then
        fail = .False.
        exit
     end if
     x = x + dx

  end do
  pt(:) = P(:)

end subroutine newtonprojection



subroutine cross_product(veca, vecb, vecc)

  implicit none

  double precision, intent(in) ::  veca(3), vecb(3)
  double precision, intent(out) ::  vecc(3)

  vecc(3) = veca(1) * vecb(2) - veca(2) * vecb(1)
  vecc(2) = veca(3) * vecb(1) - veca(1) * vecb(3)
  vecc(1) = veca(2) * vecb(3) - veca(3) * vecb(2)

end subroutine cross_product
