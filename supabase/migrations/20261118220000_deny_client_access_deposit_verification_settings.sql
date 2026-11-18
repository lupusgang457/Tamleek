create policy "Block client access to deposit verification settings"
on public.deposit_verification_settings
for all to anon, authenticated
using (false)
with check (false);
