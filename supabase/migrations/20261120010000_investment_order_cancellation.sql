alter table public.investment_orders
  drop constraint if exists investment_orders_status_check;

alter table public.investment_orders
  add constraint investment_orders_status_check
  check (status in ('pending', 'approved', 'rejected', 'cancelled'));

alter table public.investment_orders
  add column if not exists cancelled_by uuid
    references auth.users (id) on delete set null,
  add column if not exists cancelled_at timestamptz;

update public.investment_orders
set review_note = case status
  when 'approved' then 'Approuver'
  when 'rejected' then 'Refuser'
end
where status in ('approved', 'rejected')
  and review_note is distinct from case status
    when 'approved' then 'Approuver'
    when 'rejected' then 'Refuser'
  end;

alter table public.investment_orders
  drop constraint if exists investment_orders_review_note_check;

alter table public.investment_orders
  add constraint investment_orders_review_note_check
  check (
    (status in ('pending', 'cancelled') and review_note = '')
    or (status = 'approved' and review_note = 'Approuver')
    or (status = 'rejected' and review_note = 'Refuser')
  );

alter table public.investment_redemption_orders
  drop constraint if exists investment_redemption_orders_status_check;

alter table public.investment_redemption_orders
  add constraint investment_redemption_orders_status_check
  check (status in ('pending', 'approved', 'rejected'));

update public.investment_redemption_orders
set review_note = case status
  when 'approved' then 'Approuver'
  when 'rejected' then 'Refuser'
end
where status in ('approved', 'rejected')
  and review_note is distinct from case status
    when 'approved' then 'Approuver'
    when 'rejected' then 'Refuser'
  end;

alter table public.investment_redemption_orders
  drop constraint if exists investment_redemption_orders_review_note_check;

alter table public.investment_redemption_orders
  add constraint investment_redemption_orders_review_note_check
  check (
    (status = 'pending' and review_note = '')
    or (status = 'approved' and review_note = 'Approuver')
    or (status = 'rejected' and review_note = 'Refuser')
  );

create or replace function public.review_investment_order(
  p_order_id uuid,
  p_status text,
  p_review_note text default ''
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.investment_orders%rowtype;
begin
  if (select auth.uid()) is null or not public.is_tamleek_admin() then
    raise exception 'Administrator access required.';
  end if;
  if p_status is null or p_status not in ('approved', 'rejected') then
    raise exception 'Invalid review status.';
  end if;

  select *
  into v_order
  from public.investment_orders
  where id = p_order_id
  for update;
  if not found then
    raise exception 'Investment order not found.';
  end if;
  if v_order.status <> 'pending' then
    raise exception 'Only pending investment orders can be reviewed.';
  end if;
  if p_status = 'approved' and not exists (
    select 1
    from public.investment_products
    where product_id = v_order.product_id
      and is_active
  ) then
    raise exception 'This investment product is no longer active.';
  end if;

  update public.investment_orders
  set status = p_status,
      review_note = case p_status
        when 'approved' then 'Approuver'
        when 'rejected' then 'Refuser'
      end,
      reviewed_by = (select auth.uid()),
      reviewed_at = now()
  where id = p_order_id;
end;
$$;

revoke all on function public.review_investment_order(uuid, text, text)
from public, anon, authenticated;
grant execute on function public.review_investment_order(uuid, text, text)
to authenticated;

create or replace function public.review_investment_redemption(
  p_redemption_id uuid,
  p_status text,
  p_review_note text default ''
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_redemption public.investment_redemption_orders%rowtype;
begin
  if (select auth.uid()) is null or not public.is_tamleek_admin() then
    raise exception 'Administrator access required.';
  end if;
  if p_status is null or p_status not in ('approved', 'rejected') then
    raise exception 'Invalid redemption status.';
  end if;

  select *
  into v_redemption
  from public.investment_redemption_orders
  where id = p_redemption_id
  for update;
  if not found then
    raise exception 'Investment redemption order not found.';
  end if;
  if v_redemption.status <> 'pending' then
    raise exception 'Only pending redemption requests can be reviewed.';
  end if;

  update public.investment_redemption_orders
  set status = p_status,
      review_note = case p_status
        when 'approved' then 'Approuver'
        when 'rejected' then 'Refuser'
      end,
      reviewed_by = (select auth.uid()),
      reviewed_at = now()
  where id = p_redemption_id;
end;
$$;

revoke all on function public.review_investment_redemption(uuid, text, text)
from public, anon, authenticated;
grant execute on function public.review_investment_redemption(uuid, text, text)
to authenticated;

create or replace function public.cancel_investment_order(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_order public.investment_orders%rowtype;
begin
  if v_user_id is null then
    raise exception 'Authentication required.';
  end if;

  select *
  into v_order
  from public.investment_orders
  where id = p_order_id
  for update;
  if not found then
    raise exception 'Investment order not found.';
  end if;
  if v_order.user_id <> v_user_id and not public.is_tamleek_admin() then
    raise exception 'Order cancellation is not authorized.';
  end if;
  if v_order.status <> 'pending' then
    raise exception 'Only pending investment orders can be cancelled.';
  end if;

  update public.investment_orders
  set status = 'cancelled',
      cancelled_by = v_user_id,
      cancelled_at = now()
  where id = p_order_id;
end;
$$;

revoke all on function public.cancel_investment_order(uuid)
from public, anon, authenticated;
grant execute on function public.cancel_investment_order(uuid)
to authenticated;
