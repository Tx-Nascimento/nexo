-- Executar no projeto NEXO: Supabase > SQL Editor > New query > Run.
-- Somente leitura: não altera dados, funções ou permissões.
-- Copie o JSON da coluna diagnostico e envie para revisar as regras efetivas.
-- O resultado contém metadados, sem senhas, tokens ou registros de usuários.
select jsonb_pretty(jsonb_build_object(
  'tabelas', (
    select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
    from (
      select n.nspname as esquema, c.relname as tabela,
             c.relrowsecurity as rls_ativo, c.relforcerowsecurity as rls_forcado
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname in ('public', 'storage') and c.relkind in ('r', 'p')
      order by n.nspname, c.relname
    ) t
  ),
  'politicas', (
    select coalesce(jsonb_agg(to_jsonb(p)), '[]'::jsonb)
    from (
      select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
      from pg_policies where schemaname in ('public', 'storage')
      order by schemaname, tablename, policyname
    ) p
  ),
  'colunas', (
    select coalesce(jsonb_agg(to_jsonb(c)), '[]'::jsonb)
    from (
      select table_name, column_name, data_type, udt_name, is_nullable, column_default
      from information_schema.columns where table_schema = 'public'
      order by table_name, ordinal_position
    ) c
  ),
  'funcoes_acesso', (
    select coalesce(jsonb_agg(to_jsonb(f)), '[]'::jsonb)
    from (
      select p.proname as nome, pg_get_function_identity_arguments(p.oid) as argumentos,
             p.prosecdef as security_definer, p.proconfig as configuracao,
             pg_get_functiondef(p.oid) as definicao,
             has_function_privilege('anon', p.oid, 'EXECUTE') as anon_executa,
             has_function_privilege('authenticated', p.oid, 'EXECUTE') as autenticado_executa
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.prokind = 'f'
        and (p.proname like 'nexo_%' or p.proname like 'usuario_%' or p.prosecdef)
      order by p.proname, p.oid
    ) f
  ),
  'triggers', (
    select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
    from (
      select c.relname as tabela, t.tgname as nome, t.tgenabled as habilitado,
             pg_get_triggerdef(t.oid) as definicao
      from pg_trigger t join pg_class c on c.oid = t.tgrelid
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and not t.tgisinternal
      order by c.relname, t.tgname
    ) t
  ),
  'permissoes_tabelas', (
    select coalesce(jsonb_agg(to_jsonb(g)), '[]'::jsonb)
    from (
      select table_schema, table_name, grantee, privilege_type
      from information_schema.table_privileges
      where table_schema in ('public', 'storage')
        and grantee in ('anon', 'authenticated', 'PUBLIC')
      order by table_schema, table_name, grantee, privilege_type
    ) g
  )
)) as diagnostico;
