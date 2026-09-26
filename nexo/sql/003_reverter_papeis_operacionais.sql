BEGIN;

DROP POLICY IF EXISTS nexo_003_executor ON public.execucoes;

DROP POLICY IF EXISTS nexo_003_excluir_execucao ON public.execucoes;

DROP POLICY IF EXISTS nexo_003_solicitar ON public.conferencias;

DROP POLICY IF EXISTS nexo_003_responder ON public.conferencias;

DROP POLICY IF EXISTS nexo_003_decisao_delete ON public.conferencias;

DROP TRIGGER IF EXISTS trg_nexo_003_decisao ON public.conferencias;

DROP TRIGGER IF EXISTS trg_nexo_003_registrar_decisao ON public.conferencias;

DROP POLICY IF EXISTS nexo_003_solicitar ON public.aprovacoes;

DROP POLICY IF EXISTS nexo_003_responder ON public.aprovacoes;

DROP POLICY IF EXISTS nexo_003_decisao_delete ON public.aprovacoes;

DROP TRIGGER IF EXISTS trg_nexo_003_decisao ON public.aprovacoes;

DROP TRIGGER IF EXISTS trg_nexo_003_registrar_decisao ON public.aprovacoes;

DROP POLICY IF EXISTS nexo_003_insert ON public.dependencias;

DROP POLICY IF EXISTS nexo_003_update ON public.dependencias;

DROP POLICY IF EXISTS nexo_003_delete ON public.dependencias;

DROP POLICY IF EXISTS nexo_003_insert ON public.bloqueios;

DROP POLICY IF EXISTS nexo_003_update ON public.bloqueios;

DROP POLICY IF EXISTS nexo_003_delete ON public.bloqueios;

DROP POLICY IF EXISTS nexo_003_insert ON public.retrabalhos;

DROP POLICY IF EXISTS nexo_003_update ON public.retrabalhos;

DROP POLICY IF EXISTS nexo_003_delete ON public.retrabalhos;

DROP POLICY IF EXISTS nexo_003_insert ON public.evidencias;

DROP POLICY IF EXISTS nexo_003_update ON public.evidencias;

DROP POLICY IF EXISTS nexo_003_delete ON public.evidencias;

DROP POLICY IF EXISTS nexo_003_insert ON public.execucao_participantes;

DROP POLICY IF EXISTS nexo_003_update ON public.execucao_participantes;

DROP POLICY IF EXISTS nexo_003_delete ON public.execucao_participantes;

DROP POLICY IF EXISTS nexo_003_insert ON public.execucao_status_historico;

DROP POLICY IF EXISTS nexo_003_update ON public.execucao_status_historico;

DROP POLICY IF EXISTS nexo_003_delete ON public.execucao_status_historico;

DROP TRIGGER IF EXISTS trg_nexo_003_execucao ON public.execucoes;

DROP FUNCTION IF EXISTS public.nexo_003_guardar_execucao();

DROP FUNCTION IF EXISTS public.nexo_003_guardar_decisao();

DROP FUNCTION IF EXISTS public.nexo_003_registrar_decisao();

CREATE OR REPLACE FUNCTION public.nexo_pode_ver_execucao(p_execucao_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.nexo_concluir_execucao(p_execucao_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
;

DROP FUNCTION IF EXISTS public.nexo_pode_executar(uuid);

-- A reversão mantém a restrição de chamada anônima na RPC de conclusão.

-- A tabela nexo_decisao_historico é preservada, com os registros existentes.
COMMIT;