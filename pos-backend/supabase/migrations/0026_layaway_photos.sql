-- 0026: foto del artículo apartado.
-- Va en el mismo bucket privado que las de producto, en la carpeta del negocio:
-- "<business_id>/layaway-<apartado>-<hora>.jpg", y su ruta en layaways.photo_path (la columna ya existía).
-- Los apartados los registra también el cajero (0015), así que el cajero puede subir estas fotos.
-- Las de producto y el logo siguen siendo solo del dueño y los administradores (0023).
-- El cajero no borra fotos: al cambiarla se sube una nueva con otra ruta.

create policy layaway_photos_insert on storage.objects for insert to authenticated
  with check (
    bucket_id = 'product-photos'
    and storage.filename(name) like 'layaway-%'
    and public.has_role(public.photo_business(name), array['cashier']::public.member_role[])
  );

-- La app sube con "upsert": si se repite la misma ruta, la sobrescribe.
create policy layaway_photos_update on storage.objects for update to authenticated
  using (
    bucket_id = 'product-photos'
    and storage.filename(name) like 'layaway-%'
    and public.has_role(public.photo_business(name), array['cashier']::public.member_role[])
  )
  with check (
    bucket_id = 'product-photos'
    and storage.filename(name) like 'layaway-%'
    and public.has_role(public.photo_business(name), array['cashier']::public.member_role[])
  );
