-- 0033: las funciones del candado del plan no se llaman desde fuera (Supabase las marcaba como expuestas).
-- Los triggers siguen funcionando: Postgres no revisa EXECUTE al disparar un trigger. plan_has se queda
-- abierta para los que tienen cuenta porque la usan las reglas de las fotos en Storage.
revoke execute on function public.enforce_plan_module() from public, anon, authenticated;
revoke execute on function public.enforce_plan_products() from public, anon, authenticated;
revoke execute on function public.enforce_plan_lots() from public, anon, authenticated;
revoke execute on function public.enforce_plan_logo() from public, anon, authenticated;
revoke execute on function public.plan_of(uuid) from authenticated;
revoke execute on function public.plan_limit(uuid, text) from authenticated;
revoke execute on function public.plan_label(uuid) from authenticated;
