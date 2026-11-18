-- 0025: logo del negocio en el ticket.
-- El logo va en el mismo bucket privado que las fotos de producto, en la carpeta del negocio:
-- "<business_id>/logo-<hora>.png", y su ruta en businesses.logo_path (la columna ya existía).
-- Lo suben solo el dueño y los administradores (las mismas reglas de 0023); lo ven todos los del negocio.
-- Es PNG con fondo blanco: las letras de un logo salen más nítidas que en JPEG.
update storage.buckets
   set allowed_mime_types = array['image/jpeg', 'image/png']
 where id = 'product-photos';
