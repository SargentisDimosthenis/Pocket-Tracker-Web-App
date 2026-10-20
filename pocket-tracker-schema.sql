-- Pocket Tracker: σχήμα βάσης για Supabase (PostgreSQL)
-- Επικόλλησε ολόκληρο το αρχείο στο SQL Editor και πάτα Run.

create table public.transactions (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid() references auth.users(id) on delete cascade,
  type           text not null check (type in ('expense','income')),
  amount_cents   bigint not null check (amount_cents > 0 and amount_cents <= 10000000000),
  category_key   text not null check (char_length(category_key) <= 30),
  occurred_at    timestamptz not null,
  payment_method text not null check (char_length(payment_method) <= 50),
  merchant       text not null default '' check (char_length(merchant) <= 100),
  note           text not null default '' check (char_length(note) <= 200),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- category_key = 'overall' για το συνολικό μηνιαίο budget
create table public.budgets (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  category_key text not null check (char_length(category_key) <= 30),
  amount_cents bigint not null check (amount_cents >= 0 and amount_cents <= 10000000000),
  updated_at   timestamptz not null default now(),
  unique (user_id, category_key)
);

create index transactions_user_date_idx on public.transactions (user_id, occurred_at desc);
create index transactions_user_cat_idx  on public.transactions (user_id, category_key);

create or replace function public.set_updated_at() returns trigger
language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

create trigger transactions_updated before update on public.transactions
  for each row execute function public.set_updated_at();
create trigger budgets_updated before update on public.budgets
  for each row execute function public.set_updated_at();

-- Row Level Security: ο κάθε χρήστης βλέπει και αλλάζει μόνο τα δικά του δεδομένα
alter table public.transactions enable row level security;
alter table public.budgets      enable row level security;

create policy "own transactions" on public.transactions
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "own budgets" on public.budgets
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
