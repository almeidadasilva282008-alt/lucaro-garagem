-- LUCARO GARAGEM — banco de dados inicial (Supabase)
create extension if not exists pgcrypto;
create table if not exists public.services (id text primary key, name text not null, description text, price text, duration_minutes integer, active boolean not null default true, created_at timestamptz not null default now());
create table if not exists public.bookings (id uuid primary key default gen_random_uuid(), service_id text references public.services(id), service_name text, customer_name text not null, vehicle text not null, phone text not null, booking_date date not null, booking_time time not null, notes text, status text not null default 'pending' check (status in ('pending','confirmed','cancelled','completed')), created_at timestamptz not null default now());
create table if not exists public.site_settings (key text primary key, value text, updated_at timestamptz not null default now());
create table if not exists public.stories (id uuid primary key default gen_random_uuid(), media_url text not null, media_type text not null default 'image', caption text, active boolean not null default true, created_at timestamptz not null default now());
create table if not exists public.chat_conversations (id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, customer_name text default 'Visitante', created_at timestamptz not null default now());
create table if not exists public.chat_messages (id uuid primary key default gen_random_uuid(), conversation_id uuid not null references public.chat_conversations(id) on delete cascade, sender text not null check (sender in ('customer','owner')), body text not null, created_at timestamptz not null default now());

-- Horários ocupados: considera a duração cadastrada. Se ainda estiver em branco,
-- reserva o restante do dia para evitar dois carros no mesmo período por engano.
create or replace function public.create_booking(p_service_id text,p_customer_name text,p_vehicle text,p_phone text,p_date date,p_time time,p_notes text default null) returns uuid language plpgsql security definer set search_path=public as $$
declare new_id uuid; service_label text; new_duration integer; new_start timestamp; new_end timestamp;
begin
 if p_date < current_date then raise exception 'date_in_past'; end if;
 select name,coalesce(duration_minutes,1440) into service_label,new_duration from public.services where id=p_service_id and active=true;
 if service_label is null then raise exception 'service_not_found'; end if;
 new_start := p_date + p_time; new_end := new_start + make_interval(mins=>new_duration);
 perform pg_advisory_xact_lock(hashtext(p_date::text));
 if exists(
   select 1 from public.bookings b left join public.services s on s.id=b.service_id
   where b.booking_date=p_date and b.status in ('pending','confirmed')
   and new_start < (b.booking_date + b.booking_time + make_interval(mins=>coalesce(s.duration_minutes,1440)))
   and (b.booking_date + b.booking_time) < new_end
 ) then raise exception 'slot_unavailable'; end if;
 insert into public.bookings(service_id,service_name,customer_name,vehicle,phone,booking_date,booking_time,notes) values(p_service_id,service_label,p_customer_name,p_vehicle,p_phone,p_date,p_time,p_notes) returning id into new_id;
 return new_id;
end; $$;

create or replace function public.is_lucaro_admin() returns boolean language sql stable security definer set search_path=public as $$
 select coalesce((auth.jwt()->'app_metadata'->>'role')='admin',false);
$$;

alter table public.services enable row level security;
alter table public.bookings enable row level security;
alter table public.site_settings enable row level security;
alter table public.stories enable row level security;
alter table public.chat_conversations enable row level security;
alter table public.chat_messages enable row level security;
create policy "public read active services" on public.services for select using (active=true);
create policy "admin manage services" on public.services for all to authenticated using (public.is_lucaro_admin()) with check (public.is_lucaro_admin());
create policy "admin manage bookings" on public.bookings for all to authenticated using (public.is_lucaro_admin()) with check (public.is_lucaro_admin());
create policy "public read settings" on public.site_settings for select using (true);
create policy "admin manage settings" on public.site_settings for all to authenticated using (public.is_lucaro_admin()) with check (public.is_lucaro_admin());
create policy "public read active stories" on public.stories for select using (active=true);
create policy "admin manage stories" on public.stories for all to authenticated using (public.is_lucaro_admin()) with check (public.is_lucaro_admin());
create policy "customer create own conversation" on public.chat_conversations for insert to authenticated with check (user_id=auth.uid());
create policy "customer or admin read conversation" on public.chat_conversations for select to authenticated using (user_id=auth.uid() or public.is_lucaro_admin());
create policy "customer or admin read messages" on public.chat_messages for select to authenticated using (exists(select 1 from public.chat_conversations c where c.id=conversation_id and (c.user_id=auth.uid() or public.is_lucaro_admin())));
create policy "customer send own message" on public.chat_messages for insert to authenticated with check (sender='customer' and exists(select 1 from public.chat_conversations c where c.id=conversation_id and c.user_id=auth.uid()));
create policy "admin reply messages" on public.chat_messages for insert to authenticated with check (sender='owner' and public.is_lucaro_admin());

-- Crie bucket público lucaro-stories e limite upload/delete ao usuário admin.
insert into storage.buckets(id,name,public) values('lucaro-stories','lucaro-stories',true) on conflict(id) do nothing;
create policy "public view lucaro stories" on storage.objects for select using (bucket_id='lucaro-stories');
create policy "admin upload lucaro stories" on storage.objects for insert to authenticated with check (bucket_id='lucaro-stories' and public.is_lucaro_admin());
create policy "admin delete lucaro stories" on storage.objects for delete to authenticated using (bucket_id='lucaro-stories' and public.is_lucaro_admin());
-- Ative Realtime para bookings e chat_messages em Database > Replication.
