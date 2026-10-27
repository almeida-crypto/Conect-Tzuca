-- La función de trigger no debe ser invocable vía API.
revoke execute on function public.apply_stock_movement() from public, anon, authenticated;

-- Las funciones de RLS solo las necesitan usuarios con sesión.
revoke execute on function public.is_member(uuid) from public, anon;
revoke execute on function public.has_role(uuid, public.member_role[]) from public, anon;
grant  execute on function public.is_member(uuid) to authenticated;
grant  execute on function public.has_role(uuid, public.member_role[]) to authenticated;
