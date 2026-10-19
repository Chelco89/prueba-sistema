-- =====================================================
-- DISTRIBUIDORA SGV - Lista de productos
-- Pegar en Supabase > SQL Editor > Run
-- =====================================================
create table public.productos (
  id bigint generated always as identity primary key,
  nombre text not null,
  lleva_serie boolean not null default false,
  activo boolean not null default true,
  creado_en timestamptz not null default now()
);

-- No permite repetir un producto (sin importar mayúsculas ni espacios)
create unique index productos_nombre_unico on public.productos (upper(trim(nombre)));

alter table public.productos enable row level security;

create policy "ver productos" on public.productos for select
  using (public.mi_rol() in ('ventas','deposito','admin'));
create policy "crear productos" on public.productos for insert
  with check (public.mi_rol() in ('ventas','admin'));
create policy "editar productos" on public.productos for update
  using (public.mi_rol() in ('ventas','admin'));

grant select, insert, update on public.productos to authenticated;
grant usage, select on all sequences in schema public to authenticated;
