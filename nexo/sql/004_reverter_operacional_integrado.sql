-- Reverter regras da etapa 004, preservando registros e novas tabelas.
BEGIN;
DO $$ DECLARE r record; BEGIN
 FOR r IN SELECT tablename,policyname FROM pg_policies WHERE schemaname='public' AND policyname LIKE 'nexo_004_%' LOOP
 EXECUTE format('DROP POLICY %I ON public.%I',r.policyname,r.tablename); END LOOP;
END $$;
DROP TRIGGER IF EXISTS nexo_004_guardar_demanda ON public.demandas;
DROP TRIGGER IF EXISTS nexo_004_historico_demanda ON public.demandas;
DROP TRIGGER IF EXISTS nexo_004_auditar_gestao ON public.demandas;
DROP TRIGGER IF EXISTS nexo_004_criar_execucao ON public.execucoes;
DROP TRIGGER IF EXISTS nexo_004_iniciar_execucao ON public.execucoes;
DROP TRIGGER IF EXISTS nexo_004_auditar_gestao ON public.execucoes;
DROP TRIGGER IF EXISTS nexo_004_sincronizar_demanda ON public.execucoes;
CREATE OR REPLACE FUNCTION public.nexo_pode_executar(p_execucao_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.execucoes e JOIN public.operacoes o ON o.id=e.operacao_id
    WHERE e.id=p_execucao_id AND o.empresa_id=public.nexo_usuario_empresa_id()
      AND public.nexo_usuario_perfil() <> 'AUDITOR'
      AND (
        public.nexo_usuario_perfil() IN ('ADMIN','DIRETORIA')
        OR e.responsavel_id=public.nexo_usuario_pessoa_id()
        OR EXISTS (SELECT 1 FROM public.execucao_participantes ep
          WHERE ep.execucao_id=e.id AND ep.ativo
            AND ep.pessoa_id=public.nexo_usuario_pessoa_id()
            AND ep.papel IN ('RESPONSAVEL','EXECUTOR'))
        OR (public.nexo_perfil_setor() AND o.setor_id IS NOT NULL
          AND o.setor_id=public.nexo_usuario_setor_id())
      )
  )
$$;
CREATE OR REPLACE FUNCTION public.nexo_pode_ver_execucao(p_execucao_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.execucoes e JOIN public.operacoes o ON o.id=e.operacao_id
    WHERE e.id=p_execucao_id AND o.empresa_id=public.nexo_usuario_empresa_id()
    AND (
      public.nexo_perfil_empresa() OR e.responsavel_id=public.nexo_usuario_pessoa_id()
      OR EXISTS (SELECT 1 FROM public.execucao_participantes ep WHERE ep.execucao_id=e.id
        AND ep.ativo AND ep.pessoa_id=public.nexo_usuario_pessoa_id())
      OR (public.nexo_perfil_setor() AND o.setor_id IS NOT NULL
        AND o.setor_id=public.nexo_usuario_setor_id())
      OR EXISTS (SELECT 1 FROM public.conferencias c WHERE c.execucao_id=e.id
        AND c.conferente_id=public.nexo_usuario_pessoa_id())
      OR EXISTS (SELECT 1 FROM public.aprovacoes a WHERE a.execucao_id=e.id
        AND a.aprovador_id=public.nexo_usuario_pessoa_id())
    )
  )
$$;
CREATE OR REPLACE FUNCTION public.nexo_003_guardar_execucao()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public
AS $$
DECLARE v_op public.operacoes%rowtype; v_resultado text;
BEGIN
  IF NOT public.nexo_pode_executar(old.id) THEN RAISE EXCEPTION 'Sem permissão para executar esta atividade.'; END IF;
  IF new.id IS DISTINCT FROM old.id OR new.operacao_id IS DISTINCT FROM old.operacao_id
     OR new.responsavel_id IS DISTINCT FROM old.responsavel_id THEN
    RAISE EXCEPTION 'Alteração de operação ou responsável exige fluxo de redistribuição.';
  END IF;
  IF old.status IN ('CONCLUIDA','CANCELADA') THEN
    RAISE EXCEPTION 'Execução encerrada. Reabertura exige fluxo específico.';
  END IF;
  IF new.status='CONCLUIDA' THEN
    SELECT * INTO v_op FROM public.operacoes WHERE id=new.operacao_id;
    IF EXISTS (SELECT 1 FROM public.bloqueios WHERE execucao_id=new.id AND ativo)
      OR EXISTS (SELECT 1 FROM public.dependencias WHERE execucao_id=new.id AND ativo)
      OR EXISTS (SELECT 1 FROM public.retrabalhos WHERE execucao_id=new.id AND status IN ('PENDENTE','EM_CORRECAO')) THEN
      RAISE EXCEPTION 'Resolva bloqueios, dependências e retrabalhos antes de concluir.';
    END IF;
    IF EXISTS (SELECT 1 FROM public.conferencias WHERE execucao_id=new.id AND resultado='PENDENTE')
      OR EXISTS (SELECT 1 FROM public.aprovacoes WHERE execucao_id=new.id AND status='PENDENTE') THEN
      RAISE EXCEPTION 'Existe conferência ou aprovação pendente.';
    END IF;
    SELECT resultado INTO v_resultado FROM public.conferencias WHERE execucao_id=new.id
      ORDER BY created_at DESC NULLS LAST, id DESC LIMIT 1;
    IF (v_op.exige_conferencia AND v_resultado IS DISTINCT FROM 'APROVADA') OR v_resultado='REJEITADA' THEN
      RAISE EXCEPTION 'A última conferência precisa estar aprovada.';
    END IF;
    SELECT status INTO v_resultado FROM public.aprovacoes WHERE execucao_id=new.id
      ORDER BY created_at DESC NULLS LAST, id DESC LIMIT 1;
    IF (v_op.exige_aprovacao AND v_resultado IS DISTINCT FROM 'APROVADA') OR v_resultado='REJEITADA' THEN
      RAISE EXCEPTION 'A última aprovação precisa estar aprovada.';
    END IF;
    IF v_op.exige_evidencia AND NOT EXISTS (SELECT 1 FROM public.evidencias WHERE execucao_id=new.id) THEN
      RAISE EXCEPTION 'Registre a evidência obrigatória.';
    END IF;
    new.percentual_conclusao := 100;
    new.data_conclusao := clock_timestamp();
  END IF;
  RETURN new;
END $$;
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

  if not public.nexo_pode_executar(p_execucao_id) then
    raise exception 'Você não possui permissão para executar esta atividade.';
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

CREATE OR REPLACE FUNCTION public.nexo_pode_ver_pessoa(p_pessoa_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
;

REVOKE ALL ON FUNCTION public.nexo_painel_operacional(integer),public.nexo_configurar_pontuacao(text),public.nexo_converter_demanda(uuid),public.nexo_gerir_atividade(text,uuid,uuid,timestamptz,text,uuid,boolean) FROM authenticated;
COMMIT;
SELECT 'REGRAS 004 REVERTIDAS; HISTÓRICOS PRESERVADOS' AS resultado;
