-- 1) Columnas nuevas (obligatorio)
alter table pedido_items add column if not exists cantidad_preparada numeric not null default 0;
alter table pedido_items add column if not exists series_requeridas integer;  -- null = usa la cantidad del producto

-- 2) Permisos para que Depósito pueda editar el pedido (solo si te da error de permisos al editar/quitar)
create policy "deposito inserta items" on pedido_items for insert to authenticated
  with check (exists (select 1 from profiles where id = auth.uid() and activo and rol in ('deposito','admin')));
create policy "deposito edita items" on pedido_items for update to authenticated
  using (exists (select 1 from profiles where id = auth.uid() and activo and rol in ('deposito','admin')));
create policy "deposito borra items" on pedido_items for delete to authenticated
  using (exists (select 1 from profiles where id = auth.uid() and activo and rol in ('deposito','admin')));
create policy "deposito borra series" on series for delete to authenticated
  using (exists (select 1 from profiles where id = auth.uid() and activo and rol in ('deposito','admin')));
