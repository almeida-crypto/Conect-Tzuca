-- 0023: fotos de producto en Supabase Storage.
-- Bucket privado "product-photos". Cada foto va en una carpeta con el id del negocio:
-- "<business_id>/<product_id>-<hora>.jpg". La app ya la manda chica (600×600 JPEG, ~50 KB).
-- * Las ve cualquier miembro del negocio (meseros y cocina también: no tienen precios ni costos).
-- * Las suben, cambian o borran solo el dueño y los administradores (los que cambian el catálogo).

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('product-photos', 'product-photos', false, 524288, array['image/jpeg'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Id del negocio a partir de la carpeta; null si no es un uuid (así ninguna regla deja pasar rutas raras).
create or replace function public.photo_business(p_name text)
returns uuid
language plpgsql immutable
set search_path = ''
as $$
begin
  return (storage.foldername(p_name))[1]::uuid;
exception when others then
  return null;
end;
$$;

create policy product_photos_select on storage.objects for select to authenticated
  using (bucket_id = 'product-photos' and public.is_member(public.photo_business(name)));

create policy product_photos_insert on storage.objects for insert to authenticated
  with check (
    bucket_id = 'product-photos'
    and public.has_role(public.photo_business(name), array['owner', 'admin']::public.member_role[])
  );

create policy product_photos_update on storage.objects for update to authenticated
  using (
    bucket_id = 'product-photos'
    and public.has_role(public.photo_business(name), array['owner', 'admin']::public.member_role[])
  )
  with check (
    bucket_id = 'product-photos'
    and public.has_role(public.photo_business(name), array['owner', 'admin']::public.member_role[])
  );

create policy product_photos_delete on storage.objects for delete to authenticated
  using (
    bucket_id = 'product-photos'
    and public.has_role(public.photo_business(name), array['owner', 'admin']::public.member_role[])
  );
