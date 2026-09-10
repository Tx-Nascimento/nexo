-- NEXO - consolidação das pendências estruturais
-- Execute no Supabase SQL Editor como postgres.

create or replace function public.usuario_pessoa_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select u.pessoa_id
  from public.usuarios u
  where u.id = auth.uid() and u.ativo = true
  limit 1;
$$;

create or replace function public.usuario_empresa_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select p.empresa_id
  from public.usuarios u
  join public.pessoas p on p.id = u.pessoa_id
  where u.id = auth.uid() and u.ativo = true
  limit 1;
$$;

create or replace function public.usuario_setor_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select p.setor_id
  from public.usuarios u
  join public.pessoas p on p.id = u.pessoa_id
  where u.id = auth.uid() and u.ativo = true
  limit 1;
$$;

create or replace function public.usuario_perfil_nome()
returns text
language sql
security definer
stable
set search_path = public
as $$
  select pf.nome
  from public.usuarios u
  join public.perfis pf on pf.id = u.perfil_id
  where u.id = auth.uid() and u.ativo = true
  limit 1;
$$;

-- Repositório privado
insert into storage.buckets (id, name, public)
values ('nexo-documentos', 'nexo-documentos', false)
on conflict (id) do update set public = false;

-- Acesso ao bucket apenas dentro da empresa do usuário.
drop policy if exists "nexo_documentos_select" on storage.objects;
create policy "nexo_documentos_select"
on storage.objects for select to authenticated
using (
  bucket_id = 'nexo-documentos'
  and (storage.foldername(name))[1] = public.usuario_empresa_id()::text
);

drop policy if exists "nexo_documentos_insert" on storage.objects;
create policy "nexo_documentos_insert"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'nexo-documentos'
  and (storage.foldername(name))[1] = public.usuario_empresa_id()::text
);

drop policy if exists "nexo_documentos_update" on storage.objects;
create policy "nexo_documentos_update"
on storage.objects for update to authenticated
using (
  bucket_id = 'nexo-documentos'
  and (storage.foldername(name))[1] = public.usuario_empresa_id()::text
)
with check (
  bucket_id = 'nexo-documentos'
  and (storage.foldername(name))[1] = public.usuario_empresa_id()::text
);

-- Políticas de leitura por empresa. As policies ADMIN existentes continuam válidas e são combinadas por OR.
do $$
declare t text;
begin
  foreach t in array array['empresas','setores','cargos','pessoas','processos','operacoes','documentos','objetivos','indicadores']
  loop
    execute format('drop policy if exists "nexo_empresa_select_%s" on public.%I', t, t);
  end loop;
end $$;

create policy "nexo_empresa_select_empresas" on public.empresas for select to authenticated using (id = public.usuario_empresa_id());
create policy "nexo_empresa_select_setores" on public.setores for select to authenticated using (empresa_id = public.usuario_empresa_id());
create policy "nexo_empresa_select_cargos" on public.cargos for select to authenticated using (empresa_id = public.usuario_empresa_id());
create policy "nexo_empresa_select_pessoas" on public.pessoas for select to authenticated using (empresa_id = public.usuario_empresa_id());
create policy "nexo_empresa_select_processos" on public.processos for select to authenticated using (empresa_id = public.usuario_empresa_id());
create policy "nexo_empresa_select_operacoes" on public.operacoes for select to authenticated using (empresa_id = public.usuario_empresa_id());
create policy "nexo_empresa_select_documentos" on public.documentos for select to authenticated using (empresa_id = public.usuario_empresa_id());
create policy "nexo_empresa_select_objetivos" on public.objetivos for select to authenticated using (empresa_id = public.usuario_empresa_id());
create policy "nexo_empresa_select_indicadores" on public.indicadores for select to authenticated using (empresa_id = public.usuario_empresa_id());

-- Execuções: leitura por empresa; alteração por responsável/participante ou liderança.
drop policy if exists "nexo_execucoes_select" on public.execucoes;
create policy "nexo_execucoes_select" on public.execucoes for select to authenticated
using (exists (select 1 from public.operacoes o where o.id = operacao_id and o.empresa_id = public.usuario_empresa_id()));

drop policy if exists "nexo_execucoes_update" on public.execucoes;
create policy "nexo_execucoes_update" on public.execucoes for update to authenticated
using (
  responsavel_id = public.usuario_pessoa_id()
  or public.usuario_perfil_nome() in ('ADMIN','LIDER','GESTOR','GERENTE','DIRETORIA')
  or exists (select 1 from public.execucao_participantes ep where ep.execucao_id = id and ep.pessoa_id = public.usuario_pessoa_id() and ep.ativo = true)
)
with check (exists (select 1 from public.operacoes o where o.id = operacao_id and o.empresa_id = public.usuario_empresa_id()));

-- Demandas: empresa inteira pode ler; solicitante/responsável e liderança podem alterar.
drop policy if exists "nexo_demandas_select" on public.demandas;
create policy "nexo_demandas_select" on public.demandas for select to authenticated using (empresa_id = public.usuario_empresa_id());

drop policy if exists "nexo_demandas_insert" on public.demandas;
create policy "nexo_demandas_insert" on public.demandas for insert to authenticated with check (empresa_id = public.usuario_empresa_id() and solicitante_id = public.usuario_pessoa_id());

drop policy if exists "nexo_demandas_update" on public.demandas;
create policy "nexo_demandas_update" on public.demandas for update to authenticated
using (solicitante_id = public.usuario_pessoa_id() or responsavel_id = public.usuario_pessoa_id() or public.usuario_perfil_nome() in ('ADMIN','LIDER','GESTOR','GERENTE','DIRETORIA'))
with check (empresa_id = public.usuario_empresa_id());

-- Documentos: leitura por empresa e criação pelo usuário autenticado.
drop policy if exists "nexo_documentos_insert_table" on public.documentos;
create policy "nexo_documentos_insert_table" on public.documentos for insert to authenticated with check (empresa_id = public.usuario_empresa_id());

-- Procedimentos e vínculos herdados por operação/documento da empresa.
drop policy if exists "nexo_procedimentos_select" on public.procedimentos;
create policy "nexo_procedimentos_select" on public.procedimentos for select to authenticated using (exists (select 1 from public.operacoes o where o.id = operacao_id and o.empresa_id = public.usuario_empresa_id()));

drop policy if exists "nexo_procedimentos_insert" on public.procedimentos;
create policy "nexo_procedimentos_insert" on public.procedimentos for insert to authenticated with check (exists (select 1 from public.operacoes o where o.id = operacao_id and o.empresa_id = public.usuario_empresa_id()));

drop policy if exists "nexo_documento_vinculos_select" on public.documento_vinculos;
create policy "nexo_documento_vinculos_select" on public.documento_vinculos for select to authenticated using (exists (select 1 from public.documentos d where d.id = documento_id and d.empresa_id = public.usuario_empresa_id()));

drop policy if exists "nexo_documento_vinculos_insert" on public.documento_vinculos;
create policy "nexo_documento_vinculos_insert" on public.documento_vinculos for insert to authenticated with check (exists (select 1 from public.documentos d where d.id = documento_id and d.empresa_id = public.usuario_empresa_id()));

-- Segurança contra auto-desativação/auto-rebaixamento acidental do último ADMIN.
create or replace function public.proteger_ultimo_admin()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  perfil_admin uuid;
  qtd_admin integer;
begin
  select id into perfil_admin from public.perfis where nome = 'ADMIN' limit 1;
  if old.perfil_id = perfil_admin and old.ativo = true and (new.perfil_id <> perfil_admin or new.ativo = false) then
    select count(*) into qtd_admin from public.usuarios where perfil_id = perfil_admin and ativo = true and id <> old.id;
    if qtd_admin = 0 then
      raise exception 'Não é permitido remover ou desativar o último usuário ADMIN.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_proteger_ultimo_admin on public.usuarios;
create trigger trg_proteger_ultimo_admin before update on public.usuarios for each row execute function public.proteger_ultimo_admin();

-- Evidências acessíveis pela empresa da execução.
drop policy if exists "nexo_evidencias_select" on public.evidencias;
create policy "nexo_evidencias_select" on public.evidencias for select to authenticated
using (exists (
  select 1 from public.execucoes e
  join public.operacoes o on o.id = e.operacao_id
  where e.id = execucao_id and o.empresa_id = public.usuario_empresa_id()
));

drop policy if exists "nexo_evidencias_insert" on public.evidencias;
create policy "nexo_evidencias_insert" on public.evidencias for insert to authenticated
with check (exists (
  select 1 from public.execucoes e
  join public.operacoes o on o.id = e.operacao_id
  where e.id = execucao_id and o.empresa_id = public.usuario_empresa_id()
));

-- Histórico, conferência, aprovação, bloqueio, dependência e retrabalho:
-- leitura por empresa da execução.
do $$
declare
  t text;
begin
  foreach t in array array['execucao_participantes','execucao_status_historico','dependencias','bloqueios','conferencias','retrabalhos','aprovacoes','carga_trabalho']
  loop
    execute format('drop policy if exists "nexo_fluxo_select_%s" on public.%I', t, t);
  end loop;
end $$;

create policy "nexo_fluxo_select_execucao_participantes" on public.execucao_participantes for select to authenticated using (exists (select 1 from public.execucoes e join public.operacoes o on o.id=e.operacao_id where e.id=execucao_id and o.empresa_id=public.usuario_empresa_id()));
create policy "nexo_fluxo_select_execucao_status_historico" on public.execucao_status_historico for select to authenticated using (exists (select 1 from public.execucoes e join public.operacoes o on o.id=e.operacao_id where e.id=execucao_id and o.empresa_id=public.usuario_empresa_id()));
create policy "nexo_fluxo_select_dependencias" on public.dependencias for select to authenticated using (exists (select 1 from public.execucoes e join public.operacoes o on o.id=e.operacao_id where e.id=execucao_id and o.empresa_id=public.usuario_empresa_id()));
create policy "nexo_fluxo_select_bloqueios" on public.bloqueios for select to authenticated using (exists (select 1 from public.execucoes e join public.operacoes o on o.id=e.operacao_id where e.id=execucao_id and o.empresa_id=public.usuario_empresa_id()));
create policy "nexo_fluxo_select_conferencias" on public.conferencias for select to authenticated using (exists (select 1 from public.execucoes e join public.operacoes o on o.id=e.operacao_id where e.id=execucao_id and o.empresa_id=public.usuario_empresa_id()));
create policy "nexo_fluxo_select_retrabalhos" on public.retrabalhos for select to authenticated using (exists (select 1 from public.execucoes e join public.operacoes o on o.id=e.operacao_id where e.id=execucao_id and o.empresa_id=public.usuario_empresa_id()));
create policy "nexo_fluxo_select_aprovacoes" on public.aprovacoes for select to authenticated using (exists (select 1 from public.execucoes e join public.operacoes o on o.id=e.operacao_id where e.id=execucao_id and o.empresa_id=public.usuario_empresa_id()));
create policy "nexo_fluxo_select_carga_trabalho" on public.carga_trabalho for select to authenticated using (exists (select 1 from public.pessoas p where p.id=pessoa_id and p.empresa_id=public.usuario_empresa_id()));

-- Regras centrais: nenhuma execução pode ser concluída ignorando requisitos.
create or replace function public.validar_conclusao_execucao()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  op record;
begin
  if new.status = 'CONCLUIDA' and old.status is distinct from 'CONCLUIDA' then
    select exige_conferencia, exige_aprovacao, exige_evidencia into op
    from public.operacoes where id = new.operacao_id;

    if exists (select 1 from public.bloqueios b where b.execucao_id = new.id and b.ativo = true) then
      raise exception 'A execução possui bloqueio ativo.';
    end if;

    if exists (select 1 from public.retrabalhos r where r.execucao_id = new.id and r.status in ('PENDENTE','EM_CORRECAO')) then
      raise exception 'A execução possui retrabalho pendente.';
    end if;

    if op.exige_conferencia and not exists (select 1 from public.conferencias c where c.execucao_id = new.id and c.resultado = 'APROVADA') then
      raise exception 'A operação exige conferência aprovada.';
    end if;

    if op.exige_aprovacao and not exists (select 1 from public.aprovacoes a where a.execucao_id = new.id and a.status = 'APROVADA') then
      raise exception 'A operação exige aprovação.';
    end if;

    if op.exige_evidencia and not exists (select 1 from public.evidencias ev where ev.execucao_id = new.id) then
      raise exception 'A operação exige evidência.';
    end if;

    new.percentual_conclusao := 100;
    if new.data_conclusao is null then new.data_conclusao := now(); end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_validar_conclusao_execucao on public.execucoes;
create trigger trg_validar_conclusao_execucao before update on public.execucoes for each row execute function public.validar_conclusao_execucao();

-- Sincroniza a demanda vinculada com o andamento da execução.
create or replace function public.sincronizar_demanda_execucao()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.demandas d
  set
    percentual_conclusao = new.percentual_conclusao,
    status = case
      when new.status = 'CONCLUIDA' then 'CONCLUIDA'
      when new.status = 'CANCELADA' then 'CANCELADA'
      when new.status = 'BLOQUEADA' then 'BLOQUEADA'
      when new.status like 'AGUARDANDO_%' then 'AGUARDANDO'
      when new.status in ('NAO_INICIADA') then 'ABERTA'
      else 'EM_EXECUCAO'
    end,
    data_inicio = coalesce(d.data_inicio, new.data_inicio),
    data_conclusao = case when new.status in ('CONCLUIDA','CANCELADA') then coalesce(new.data_conclusao, now()) else d.data_conclusao end,
    updated_at = now()
  where d.execucao_id = new.id;
  return new;
end;
$$;

drop trigger if exists trg_sincronizar_demanda_execucao on public.execucoes;
create trigger trg_sincronizar_demanda_execucao after update on public.execucoes for each row execute function public.sincronizar_demanda_execucao();
