-- Costo de inscripción del gimnasio.
--
-- Se cobra una sola vez, a los clientes nuevos (los que nunca han pagado),
-- en el mismo cobro de su primer abono: queda desglosado en
-- `ingresos.cuota_registro`, columna que ya existía. Vale en los dos modos
-- de cobro (costo fijo y abono libre).
--
-- Null: el gimnasio no cobra inscripción. Lo leen todos los del personal y
-- lo editan dueño y encargado, con las mismas políticas que los precios.

alter table public.gyms
  add column if not exists price_inscripcion numeric
    check (price_inscripcion is null or price_inscripcion > 0);

comment on column public.gyms.price_inscripcion is
  'Inscripción para clientes nuevos (una vez, al primer pago). Null: sin inscripción.';
