-- =====================================================
-- DISTRIBUIDORA SGV - Paso 1: base de datos
-- Pegar completo en Supabase > SQL Editor > Run
-- =====================================================

-- USUARIOS (perfil de cada persona que entra)
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nombre text not null,
  puesto_solicitado text,
  rol text not null default 'pendiente'
    check (rol in ('pendiente','ventas','deposito','admin')),
  activo boolean not null default true,
  creado_en timestamptz not null default now()
);

-- Al registrarse alguien se crea su perfil.
-- La PRIMERA persona que se registra queda como admin (vos).
-- El resto queda "pendiente" hasta que el admin le asigne el puesto.
create or replace function public.crear_perfil()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, nombre, puesto_solicitado, rol)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'nombre', split_part(new.email,'@',1)),
    new.raw_user_meta_data->>'puesto',
    case when (select count(*) from public.profiles) = 0 then 'admin' else 'pendiente' end
  );
  return new;
end $$;

create trigger al_registrarse after insert on auth.users
for each row execute function public.crear_perfil();

-- Helper: rol del usuario logueado (solo si está activo)
create or replace function public.mi_rol()
returns text language sql stable security definer set search_path = public as $$
  select rol from public.profiles where id = auth.uid() and activo
$$;

-- PEDIDOS (cada uno es un remito)
create table public.pedidos (
  id bigint generated always as identity primary key,
  numero_remito bigint generated always as identity (start with 1) unique,
  cliente text not null,
  estado text not null default 'pendiente'
    check (estado in ('pendiente','listo','entregado','anulado')),
  modalidad text not null default 'retira' check (modalidad in ('retira','despacho')),
  fecha_entrega date,
  comentarios text,
  creado_por uuid references public.profiles(id),
  creado_en timestamptz not null default now(),
  fecha_listo timestamptz,
  fecha_entregado timestamptz,
  enargas_transferido boolean  -- null = no corresponde / aún no se respondió
);

-- PRODUCTOS DE CADA PEDIDO
create table public.pedido_items (
  id bigint generated always as identity primary key,
  pedido_id bigint not null references public.pedidos(id) on delete cascade,
  producto text not null,
  cantidad numeric not null check (cantidad > 0),
  lleva_serie boolean not null default false
);

-- NÚMEROS DE SERIE (los carga depósito a mano; no se pueden repetir)
create table public.series (
  id bigint generated always as identity primary key,
  pedido_id bigint not null references public.pedidos(id) on delete cascade,
  item_id bigint not null references public.pedido_items(id) on delete cascade,
  numero_serie text not null unique,
  cargado_por uuid references public.profiles(id),
  creado_en timestamptz not null default now()
);

create index on public.pedidos (cliente);
create index on public.pedidos (estado);
create index on public.pedidos (fecha_entrega);
create index on public.pedido_items (pedido_id);
create index on public.series (pedido_id);

-- Fechas automáticas al cambiar de estado
create or replace function public.marcar_fechas()
returns trigger language plpgsql as $$
begin
  if new.estado = 'listo' and old.estado <> 'listo' then new.fecha_listo := now(); end if;
  if new.estado = 'entregado' and old.estado <> 'entregado' then new.fecha_entregado := now(); end if;
  return new;
end $$;

create trigger fechas_pedido before update on public.pedidos
for each row execute function public.marcar_fechas();

-- =====================================================
-- SEGURIDAD (qué puede hacer cada rol)
-- =====================================================
alter table public.profiles     enable row level security;
alter table public.pedidos      enable row level security;
alter table public.pedido_items enable row level security;
alter table public.series       enable row level security;

-- profiles
create policy "ver mi perfil o todos si admin" on public.profiles for select
  using (id = auth.uid() or public.mi_rol() = 'admin');
create policy "admin edita perfiles" on public.profiles for update
  using (public.mi_rol() = 'admin') with check (public.mi_rol() = 'admin');

-- pedidos: ven todos los que tengan rol; crea ventas/admin; actualiza ventas/deposito/admin
create policy "ver pedidos" on public.pedidos for select
  using (public.mi_rol() in ('ventas','deposito','admin'));
create policy "crear pedidos" on public.pedidos for insert
  with check (public.mi_rol() in ('ventas','admin'));
create policy "actualizar pedidos" on public.pedidos for update
  using (public.mi_rol() in ('ventas','deposito','admin'));
create policy "borrar pedidos (solo admin)" on public.pedidos for delete
  using (public.mi_rol() = 'admin');

-- items
create policy "ver items" on public.pedido_items for select
  using (public.mi_rol() in ('ventas','deposito','admin'));
create policy "crear items" on public.pedido_items for insert
  with check (public.mi_rol() in ('ventas','admin'));
create policy "actualizar items" on public.pedido_items for update
  using (public.mi_rol() in ('ventas','deposito','admin'));
create policy "borrar items" on public.pedido_items for delete
  using (public.mi_rol() in ('ventas','admin'));

-- series
create policy "ver series" on public.series for select
  using (public.mi_rol() in ('ventas','deposito','admin'));
create policy "cargar series" on public.series for insert
  with check (public.mi_rol() in ('deposito','admin'));
create policy "editar series" on public.series for update
  using (public.mi_rol() in ('deposito','admin'));
create policy "borrar series" on public.series for delete
  using (public.mi_rol() in ('deposito','admin'));

-- Avisos en tiempo real (para las notificaciones del paso 4)
alter publication supabase_realtime add table public.pedidos;
