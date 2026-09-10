-- ============================================================
-- NEXO - FECHAMENTO OPERACIONAL
-- Execute UMA VEZ no Supabase SQL Editor.
-- Mantém as tabelas atuais e adiciona segurança, conclusão,
-- recorrência e alertas.
-- ============================================================

reset role;

alter table public.pessoas
  add column if not exists gestor_id uuid null references public.pessoas(id) on delete set null;

alter table public.operacoes
  add column if not exists peso_complexidade numeric not null default 1;

alter table public.execucoes
  add column if not exists recorrencia_id uuid null references public.operacao_recorrencias(id) on delete set null;

alter table public.execucoes
  add column if not exists data_referencia date null;

create unique index if not exists ux_execucoes_recorrencia_data
on public.execucoes(recorrencia_id, data_referencia)
where recorrencia_id is not null and data_referencia is not null;

create index if not exists ix_execucoes_responsavel_status
on public.execucoes(responsavel_id, status);

create index if not exists ix_execucoes_prazo
on public.execucoes(data_prevista)
where status not in ('CONCLUIDA','CANCELADA');

create index if not exists ix_dependencias_execucao_ativa
on public.dependencias(execucao_id, ativo);

create index if not exists ix_bloqueios_execucao_ativo
on public.bloqueios(execucao_id, ativo);

create index if not exists ix_retrabalhos_execucao_status
on public.retrabalhos(execucao_id, status);

-- ------------------------------------------------------------
-- Helpers de usuário / hierarquia
-- ------------------------------------------------------------

create or replace function public.nexo_usuario_pessoa_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select u.pessoa_id
  from public.usuarios u
  where u.id = auth.uid()
    and u.ativo = true
  limit 1
$$;

create or replace function public.nexo_usuario_empresa_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select p.empresa_id
  from public.usuarios u
  join public.pessoas p on p.id = u.pessoa_id
  where u.id = auth.uid()
    and u.ativo = true
  limit 1
$$;

create or replace function public.nexo_usuario_setor_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select p.setor_id
  from public.usuarios u
  join public.pessoas p on p.id = u.pessoa_id
  where u.id = auth.uid()
    and u.ativo = true
  limit 1
$$;

create or replace function public.nexo_usuario_perfil()
returns text
language sql
security definer
stable
set search_path = public
as $$
  select pf.nome
  from public.usuarios u
  join public.perfis pf on pf.id = u.perfil_id
  where u.id = auth.uid()
    and u.ativo = true
  limit 1
$$;

create or replace function public.nexo_perfil_empresa()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(public.nexo_usuario_perfil() in ('ADMIN','DIRETORIA','AUDITOR'), false)
$$;

create or replace function public.nexo_perfil_setor()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(public.nexo_usuario_perfil() in ('LIDER','GESTOR','GERENTE'), false)
$$;

create or replace function public.nexo_pode_ver_pessoa(p_pessoa_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.pessoas alvo
    where alvo.id = p_pessoa_id
      and alvo.empresa_id = public.nexo_usuario_empresa_id()
      and (
        public.nexo_perfil_empresa()
        or alvo.id = public.nexo_usuario_pessoa_id()
        or (
          public.nexo_perfil_setor()
          and alvo.setor_id is not distinct from public.nexo_usuario_setor_id()
        )
        or alvo.gestor_id = public.nexo_usuario_pessoa_id()
      )
  )
$$;

create or replace function public.nexo_pode_ver_execucao(p_execucao_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.execucoes e
    join public.operacoes o on o.id = e.operacao_id
    where e.id = p_execucao_id
      and o.empresa_id = public.nexo_usuario_empresa_id()
      and (
        public.nexo_perfil_empresa()
        or e.responsavel_id = public.nexo_usuario_pessoa_id()
        or exists (
          select 1
          from public.execucao_participantes ep
          where ep.execucao_id = e.id
            and ep.pessoa_id = public.nexo_usuario_pessoa_id()
            and ep.ativo = true
        )
        or (
          public.nexo_perfil_setor()
          and o.setor_id is not distinct from public.nexo_usuario_setor_id()
        )
      )
  )
$$;

-- ------------------------------------------------------------
-- RLS operacional sem recursão
-- As policies ADMIN antigas podem continuar: policies permissivas somam OR.
-- ------------------------------------------------------------

alter table public.execucoes enable row level security;
drop policy if exists "nexo_final_execucoes_select" on public.execucoes;
create policy "nexo_final_execucoes_select"
on public.execucoes for select to authenticated
using (public.nexo_pode_ver_execucao(id));

drop policy if exists "nexo_final_execucoes_update" on public.execucoes;
create policy "nexo_final_execucoes_update"
on public.execucoes for update to authenticated
using (public.nexo_pode_ver_execucao(id))
with check (public.nexo_pode_ver_execucao(id));

do $$
declare
  t text;
begin
  foreach t in array array[
    'execucao_participantes',
    'execucao_status_historico',
    'dependencias',
    'bloqueios',
    'conferencias',
    'retrabalhos',
    'aprovacoes',
    'evidencias'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

drop policy if exists "nexo_final_participantes_all" on public.execucao_participantes;
create policy "nexo_final_participantes_all"
on public.execucao_participantes for all to authenticated
using (public.nexo_pode_ver_execucao(execucao_id))
with check (public.nexo_pode_ver_execucao(execucao_id));

drop policy if exists "nexo_final_historico_select" on public.execucao_status_historico;
create policy "nexo_final_historico_select"
on public.execucao_status_historico for select to authenticated
using (public.nexo_pode_ver_execucao(execucao_id));

drop policy if exists "nexo_final_historico_insert" on public.execucao_status_historico;
create policy "nexo_final_historico_insert"
on public.execucao_status_historico for insert to authenticated
with check (
  public.nexo_pode_ver_execucao(execucao_id)
  and alterado_por = public.nexo_usuario_pessoa_id()
);

drop policy if exists "nexo_final_dependencias_all" on public.dependencias;
create policy "nexo_final_dependencias_all"
on public.dependencias for all to authenticated
using (public.nexo_pode_ver_execucao(execucao_id))
with check (public.nexo_pode_ver_execucao(execucao_id));

drop policy if exists "nexo_final_bloqueios_all" on public.bloqueios;
create policy "nexo_final_bloqueios_all"
on public.bloqueios for all to authenticated
using (public.nexo_pode_ver_execucao(execucao_id))
with check (public.nexo_pode_ver_execucao(execucao_id));

drop policy if exists "nexo_final_conferencias_all" on public.conferencias;
create policy "nexo_final_conferencias_all"
on public.conferencias for all to authenticated
using (public.nexo_pode_ver_execucao(execucao_id))
with check (public.nexo_pode_ver_execucao(execucao_id));

drop policy if exists "nexo_final_retrabalhos_all" on public.retrabalhos;
create policy "nexo_final_retrabalhos_all"
on public.retrabalhos for all to authenticated
using (public.nexo_pode_ver_execucao(execucao_id))
with check (public.nexo_pode_ver_execucao(execucao_id));

drop policy if exists "nexo_final_aprovacoes_all" on public.aprovacoes;
create policy "nexo_final_aprovacoes_all"
on public.aprovacoes for all to authenticated
using (public.nexo_pode_ver_execucao(execucao_id))
with check (public.nexo_pode_ver_execucao(execucao_id));

drop policy if exists "nexo_final_evidencias_all" on public.evidencias;
create policy "nexo_final_evidencias_all"
on public.evidencias for all to authenticated
using (public.nexo_pode_ver_execucao(execucao_id))
with check (public.nexo_pode_ver_execucao(execucao_id));

-- ------------------------------------------------------------
-- Conclusão transacional e obrigatória
-- ------------------------------------------------------------

create or replace function public.nexo_concluir_execucao(p_execucao_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_exec public.execucoes%rowtype;
  v_op public.operacoes%rowtype;
  v_agora timestamptz := now();
begin
  if auth.uid() is null then
    raise exception 'Usuário não autenticado.';
  end if;

  if not public.nexo_pode_ver_execucao(p_execucao_id) then
    raise exception 'Você não possui acesso a esta execução.';
  end if;

  select * into v_exec
  from public.execucoes
  where id = p_execucao_id
  for update;

  if not found then
    raise exception 'Execução não encontrada.';
  end if;

  if v_exec.status in ('CONCLUIDA','CANCELADA') then
    raise exception 'A execução já está encerrada.';
  end if;

  select * into v_op
  from public.operacoes
  where id = v_exec.operacao_id;

  if exists (
    select 1 from public.bloqueios
    where execucao_id = p_execucao_id and ativo = true
  ) then
    raise exception 'Existe bloqueio ativo. Resolva o bloqueio antes de concluir.';
  end if;

  if exists (
    select 1 from public.dependencias
    where execucao_id = p_execucao_id and ativo = true
  ) then
    raise exception 'Existe dependência ativa. Finalize a dependência antes de concluir.';
  end if;

  if exists (
    select 1 from public.retrabalhos
    where execucao_id = p_execucao_id
      and status in ('PENDENTE','EM_CORRECAO')
  ) then
    raise exception 'Existe retrabalho pendente. Corrija antes de concluir.';
  end if;

  if v_op.exige_conferencia and not exists (
    select 1 from public.conferencias
    where execucao_id = p_execucao_id and resultado = 'APROVADA'
  ) then
    raise exception 'A operação exige conferência aprovada.';
  end if;

  if v_op.exige_aprovacao and not exists (
    select 1 from public.aprovacoes
    where execucao_id = p_execucao_id and status = 'APROVADA'
  ) then
    raise exception 'A operação exige aprovação.';
  end if;

  if v_op.exige_evidencia and not exists (
    select 1 from public.evidencias
    where execucao_id = p_execucao_id
  ) then
    raise exception 'A operação exige pelo menos uma evidência.';
  end if;

  update public.execucoes
  set
    status = 'CONCLUIDA',
    percentual_conclusao = 100,
    data_inicio = coalesce(data_inicio, v_agora),
    data_conclusao = v_agora,
    updated_at = v_agora
  where id = p_execucao_id;

  insert into public.execucao_status_historico (
    execucao_id,
    status_anterior,
    status_novo,
    alterado_por,
    motivo
  )
  values (
    p_execucao_id,
    v_exec.status,
    'CONCLUIDA',
    public.nexo_usuario_pessoa_id(),
    'Conclusão validada pelo NEXO'
  );

  update public.demandas
  set
    status = 'CONCLUIDA',
    percentual_conclusao = 100,
    data_inicio = coalesce(data_inicio, v_exec.data_inicio, v_agora),
    data_conclusao = v_agora,
    updated_at = v_agora
  where execucao_id = p_execucao_id
    and status <> 'CANCELADA';

  return jsonb_build_object(
    'ok', true,
    'execucao_id', p_execucao_id,
    'status', 'CONCLUIDA'
  );
end
$$;

grant execute on function public.nexo_concluir_execucao(uuid) to authenticated;

-- ------------------------------------------------------------
-- Geração automática das rotinas recorrentes
-- É idempotente: não duplica a mesma recorrência/data.
-- ------------------------------------------------------------

create or replace function public.nexo_gerar_recorrencias()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_empresa uuid := public.nexo_usuario_empresa_id();
  v_resp uuid;
  v_data date := current_date;
  v_prazo timestamptz;
  v_geradas integer := 0;
  v_aplica boolean;
begin
  if auth.uid() is null or v_empresa is null then
    return 0;
  end if;

  for r in
    select
      rec.id as recorrencia_id,
      rec.tipo_recorrencia,
      rec.dia_semana,
      rec.dia_mes,
      rec.data_especifica,
      rec.hora_prevista,
      rec.prazo_minutos,
      rec.sla_minutos,
      o.id as operacao_id,
      o.nome,
      o.prioridade,
      o.tempo_estimado_minutos
    from public.operacao_recorrencias rec
    join public.operacoes o on o.id = rec.operacao_id
    where rec.ativo = true
      and o.ativo = true
      and o.empresa_id = v_empresa
  loop
    v_aplica := false;

    if r.tipo_recorrencia = 'DIARIA' then
      v_aplica := true;
    elsif r.tipo_recorrencia = 'SEMANAL' then
      v_aplica := r.dia_semana = extract(isodow from v_data)::int;
    elsif r.tipo_recorrencia = 'MENSAL' then
      v_aplica := r.dia_mes = extract(day from v_data)::int;
    elsif r.tipo_recorrencia = 'DATA_ESPECIFICA' then
      v_aplica := r.data_especifica = v_data;
    elsif r.tipo_recorrencia = 'ANUAL' and r.data_especifica is not null then
      v_aplica :=
        extract(month from r.data_especifica) = extract(month from v_data)
        and extract(day from r.data_especifica) = extract(day from v_data);
    end if;

    if not v_aplica then
      continue;
    end if;

    if exists (
      select 1 from public.execucoes
      where recorrencia_id = r.recorrencia_id
        and data_referencia = v_data
    ) then
      continue;
    end if;

    select orr.pessoa_id
    into v_resp
    from public.operacao_responsaveis orr
    where orr.operacao_id = r.operacao_id
      and orr.ativo = true
      and orr.papel in ('RESPONSAVEL','EXECUTOR')
    order by
      case when orr.principal then 0 else 1 end,
      case when orr.papel = 'RESPONSAVEL' then 0 else 1 end
    limit 1;

    v_prazo :=
      v_data::timestamp
      + coalesce(r.hora_prevista, time '08:00')
      + make_interval(mins => coalesce(r.prazo_minutos, r.sla_minutos, r.tempo_estimado_minutos, 0));

    insert into public.execucoes (
      operacao_id,
      responsavel_id,
      titulo,
      status,
      prioridade,
      data_prevista,
      prazo_minutos,
      sla_minutos,
      percentual_conclusao,
      recorrencia_id,
      data_referencia
    )
    values (
      r.operacao_id,
      v_resp,
      r.nome,
      'NAO_INICIADA',
      r.prioridade,
      v_prazo,
      r.prazo_minutos,
      r.sla_minutos,
      0,
      r.recorrencia_id,
      v_data
    )
    on conflict do nothing;

    if found then
      v_geradas := v_geradas + 1;
    end if;
  end loop;

  return v_geradas;
end
$$;

grant execute on function public.nexo_gerar_recorrencias() to authenticated;

-- ------------------------------------------------------------
-- Alertas operacionais: atraso, bloqueio, dependência,
-- conferência, aprovação e retrabalho.
-- Não duplica alerta ainda não lido.
-- ------------------------------------------------------------

create or replace function public.nexo_atualizar_alertas()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_empresa uuid := public.nexo_usuario_empresa_id();
  v_total integer := 0;
begin
  if auth.uid() is null or v_empresa is null then
    return 0;
  end if;

  insert into public.alertas (execucao_id, pessoa_id, tipo, titulo, mensagem, prioridade)
  select
    e.id,
    e.responsavel_id,
    'ATRASO',
    'Execução atrasada',
    e.titulo || ' está com o prazo ultrapassado.',
    case when e.prioridade in ('CRITICA','ALTA') then 'ALTA' else 'NORMAL' end
  from public.execucoes e
  join public.operacoes o on o.id = e.operacao_id
  where o.empresa_id = v_empresa
    and e.responsavel_id is not null
    and e.data_prevista < now()
    and e.status not in ('CONCLUIDA','CANCELADA')
    and not exists (
      select 1 from public.alertas a
      where a.execucao_id = e.id
        and a.pessoa_id = e.responsavel_id
        and a.tipo = 'ATRASO'
        and a.lido = false
    );
  get diagnostics v_total = row_count;

  insert into public.alertas (execucao_id, pessoa_id, tipo, titulo, mensagem, prioridade)
  select
    e.id,
    e.responsavel_id,
    'BLOQUEIO',
    'Execução bloqueada',
    coalesce(b.motivo, e.titulo),
    'ALTA'
  from public.bloqueios b
  join public.execucoes e on e.id = b.execucao_id
  join public.operacoes o on o.id = e.operacao_id
  where o.empresa_id = v_empresa
    and b.ativo = true
    and e.responsavel_id is not null
    and not exists (
      select 1 from public.alertas a
      where a.execucao_id = e.id
        and a.pessoa_id = e.responsavel_id
        and a.tipo = 'BLOQUEIO'
        and a.lido = false
    );

  insert into public.alertas (execucao_id, pessoa_id, tipo, titulo, mensagem, prioridade)
  select
    e.id,
    e.responsavel_id,
    'DEPENDENCIA',
    'Dependência aguardando retorno',
    d.motivo,
    case when d.impacto in ('CRITICO','ALTO') then 'ALTA' else 'NORMAL' end
  from public.dependencias d
  join public.execucoes e on e.id = d.execucao_id
  join public.operacoes o on o.id = e.operacao_id
  where o.empresa_id = v_empresa
    and d.ativo = true
    and e.responsavel_id is not null
    and not exists (
      select 1 from public.alertas a
      where a.execucao_id = e.id
        and a.pessoa_id = e.responsavel_id
        and a.tipo = 'DEPENDENCIA'
        and a.lido = false
    );

  insert into public.alertas (execucao_id, pessoa_id, tipo, titulo, mensagem, prioridade)
  select
    c.execucao_id,
    c.conferente_id,
    'CONFERENCIA',
    'Conferência pendente',
    e.titulo,
    'NORMAL'
  from public.conferencias c
  join public.execucoes e on e.id = c.execucao_id
  join public.operacoes o on o.id = e.operacao_id
  where o.empresa_id = v_empresa
    and c.resultado = 'PENDENTE'
    and not exists (
      select 1 from public.alertas a
      where a.execucao_id = c.execucao_id
        and a.pessoa_id = c.conferente_id
        and a.tipo = 'CONFERENCIA'
        and a.lido = false
    );

  insert into public.alertas (execucao_id, pessoa_id, tipo, titulo, mensagem, prioridade)
  select
    a0.execucao_id,
    a0.aprovador_id,
    'APROVACAO',
    'Aprovação pendente',
    e.titulo,
    'NORMAL'
  from public.aprovacoes a0
  join public.execucoes e on e.id = a0.execucao_id
  join public.operacoes o on o.id = e.operacao_id
  where o.empresa_id = v_empresa
    and a0.status = 'PENDENTE'
    and not exists (
      select 1 from public.alertas a
      where a.execucao_id = a0.execucao_id
        and a.pessoa_id = a0.aprovador_id
        and a.tipo = 'APROVACAO'
        and a.lido = false
    );

  insert into public.alertas (execucao_id, pessoa_id, tipo, titulo, mensagem, prioridade)
  select
    r.execucao_id,
    r.responsavel_correcao_id,
    'RETRABALHO',
    'Retrabalho pendente',
    r.motivo,
    'ALTA'
  from public.retrabalhos r
  join public.execucoes e on e.id = r.execucao_id
  join public.operacoes o on o.id = e.operacao_id
  where o.empresa_id = v_empresa
    and r.status in ('PENDENTE','EM_CORRECAO')
    and r.responsavel_correcao_id is not null
    and not exists (
      select 1 from public.alertas a
      where a.execucao_id = r.execucao_id
        and a.pessoa_id = r.responsavel_correcao_id
        and a.tipo = 'RETRABALHO'
        and a.lido = false
    );

  return v_total;
end
$$;

grant execute on function public.nexo_atualizar_alertas() to authenticated;

-- ------------------------------------------------------------
-- Proteção do último ADMIN
-- ------------------------------------------------------------

create or replace function public.nexo_proteger_ultimo_admin()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id uuid;
  v_qtd integer;
begin
  select id into v_admin_id from public.perfis where nome = 'ADMIN' limit 1;

  if old.perfil_id = v_admin_id
     and old.ativo = true
     and (new.perfil_id is distinct from v_admin_id or new.ativo = false) then

    select count(*) into v_qtd
    from public.usuarios
    where perfil_id = v_admin_id
      and ativo = true
      and id <> old.id;

    if v_qtd = 0 then
      raise exception 'Não é permitido remover ou desativar o último ADMIN.';
    end if;
  end if;

  return new;
end
$$;

drop trigger if exists trg_nexo_proteger_ultimo_admin on public.usuarios;
create trigger trg_nexo_proteger_ultimo_admin
before update on public.usuarios
for each row execute function public.nexo_proteger_ultimo_admin();

-- ------------------------------------------------------------
-- Encerramento
-- ------------------------------------------------------------

select
  'NEXO FECHAMENTO OPERACIONAL APLICADO' as resultado,
  now() as aplicado_em;
