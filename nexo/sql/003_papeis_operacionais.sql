-- Supabase > SQL Editor > New query > executar TODO como postgres.
-- Pré-requisito: ETAPA 2A APLICADA. Sem exclusão de registros.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';
DO $$ BEGIN
  IF to_regprocedure('public.nexo_identidade_pessoa_id()') IS NULL THEN
    RAISE EXCEPTION 'Aplique a etapa 2A antes da etapa 3.';
  END IF;
END $$;

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
REVOKE ALL ON FUNCTION public.nexo_pode_executar(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nexo_pode_executar(uuid) TO authenticated;

-- Conferente/aprovador precisa enxergar a execução, sem virar executor.
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

-- AND com as policies existentes, inclusive admin_total_*.
DROP POLICY IF EXISTS nexo_003_executor ON public.execucoes;
CREATE POLICY nexo_003_executor ON public.execucoes AS RESTRICTIVE
FOR UPDATE TO authenticated USING (public.nexo_pode_executar(id))
WITH CHECK (public.nexo_pode_executar(id));
DROP POLICY IF EXISTS nexo_003_excluir_execucao ON public.execucoes;
CREATE POLICY nexo_003_excluir_execucao ON public.execucoes AS RESTRICTIVE
FOR DELETE TO authenticated USING (false);

-- Função reutilizada por policies e triggers: não confundir leitura com escrita.
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
REVOKE ALL ON FUNCTION public.nexo_003_guardar_execucao() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS trg_nexo_003_execucao ON public.execucoes;
CREATE TRIGGER trg_nexo_003_execucao BEFORE UPDATE ON public.execucoes
FOR EACH ROW EXECUTE FUNCTION public.nexo_003_guardar_execucao();

-- Valida também alterações diretas pela API e chamadas SECURITY DEFINER.
CREATE OR REPLACE FUNCTION public.nexo_003_guardar_decisao()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public
AS $$
DECLARE v_exec public.execucoes%rowtype; v_pessoa uuid; v_decisao text; v_anterior text;
BEGIN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Decisões não podem ser excluídas.'; END IF;
  SELECT * INTO v_exec FROM public.execucoes WHERE id=new.execucao_id FOR UPDATE;
  IF NOT FOUND OR NOT public.nexo_pode_ver_execucao(v_exec.id) THEN
    RAISE EXCEPTION 'Execução indisponível para este usuário.';
  END IF;
  IF v_exec.status IN ('CONCLUIDA','CANCELADA') THEN RAISE EXCEPTION 'Execução encerrada.'; END IF;
  IF TG_TABLE_NAME='conferencias' THEN
    v_pessoa := new.conferente_id; v_decisao := new.resultado;
    IF TG_OP='UPDATE' THEN v_anterior := old.resultado; END IF;
  ELSE
    v_pessoa := new.aprovador_id; v_decisao := new.status;
    IF TG_OP='UPDATE' THEN v_anterior := old.status; END IF;
  END IF;
  IF TG_OP='INSERT' THEN
    IF NOT public.nexo_pode_executar(v_exec.id) OR v_decisao IS DISTINCT FROM 'PENDENTE' THEN
      RAISE EXCEPTION 'Somente executor pode solicitar uma decisão pendente.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.pessoas p JOIN public.usuarios u ON u.pessoa_id=p.id
      JOIN public.perfis pf ON pf.id=u.perfil_id
      WHERE p.id=v_pessoa AND p.empresa_id=public.nexo_usuario_empresa_id()
        AND p.ativo AND u.ativo AND pf.nome<>'AUDITOR') THEN
      RAISE EXCEPTION 'Indique uma pessoa da empresa com acesso ativo e perfil diferente de AUDITOR.';
    END IF;
    IF (TG_TABLE_NAME='conferencias' AND EXISTS (SELECT 1 FROM public.conferencias WHERE execucao_id=v_exec.id AND resultado='PENDENTE'))
      OR (TG_TABLE_NAME='aprovacoes' AND EXISTS (SELECT 1 FROM public.aprovacoes WHERE execucao_id=v_exec.id AND status='PENDENTE')) THEN
      RAISE EXCEPTION 'Já existe uma solicitação pendente desta etapa.';
    END IF;
    new.created_at := clock_timestamp();
    new.observacao := NULL;
    IF TG_TABLE_NAME='conferencias' THEN new.iniciado_em:=new.created_at; new.finalizado_em:=NULL;
    ELSE new.solicitado_em:=new.created_at; new.respondido_em:=NULL; END IF;
  ELSE
    IF new.id IS DISTINCT FROM old.id OR new.execucao_id IS DISTINCT FROM old.execucao_id
      OR new.created_at IS DISTINCT FROM old.created_at THEN RAISE EXCEPTION 'Não altere a identidade da solicitação.'; END IF;
    IF TG_TABLE_NAME='conferencias' THEN
      IF new.conferente_id IS DISTINCT FROM old.conferente_id OR new.iniciado_em IS DISTINCT FROM old.iniciado_em THEN
        RAISE EXCEPTION 'Não altere o conferente ou a data de solicitação.';
      END IF;
    ELSE
      IF new.aprovador_id IS DISTINCT FROM old.aprovador_id OR new.solicitado_em IS DISTINCT FROM old.solicitado_em THEN
        RAISE EXCEPTION 'Não altere o aprovador ou a data de solicitação.';
      END IF;
    END IF;
    IF v_pessoa IS DISTINCT FROM public.nexo_usuario_pessoa_id() OR public.nexo_usuario_perfil()='AUDITOR' THEN
      RAISE EXCEPTION 'Somente a pessoa indicada pode responder esta etapa.';
    END IF;
    IF v_anterior IS DISTINCT FROM 'PENDENTE' THEN RAISE EXCEPTION 'Esta etapa já foi respondida.'; END IF;
    IF v_decisao IS NULL OR v_decisao NOT IN ('APROVADA','REJEITADA') THEN RAISE EXCEPTION 'Decisão inválida.'; END IF;
    IF v_decisao='REJEITADA' AND nullif(trim(new.observacao),'') IS NULL THEN RAISE EXCEPTION 'Informe o motivo da rejeição.'; END IF;
    IF TG_TABLE_NAME='conferencias' THEN new.finalizado_em:=clock_timestamp();
    ELSE new.respondido_em:=clock_timestamp(); END IF;
  END IF;
  new.updated_at:=clock_timestamp();
  RETURN new;
END $$;
REVOKE ALL ON FUNCTION public.nexo_003_guardar_decisao() FROM PUBLIC, anon, authenticated;

-- Políticas de decisão: leitura existente; criação por executor; resposta pelo indicado.
DO $$ DECLARE t text; pessoa text; BEGIN
  FOREACH t IN ARRAY ARRAY['conferencias','aprovacoes'] LOOP
    pessoa := CASE WHEN t='conferencias' THEN 'conferente_id' ELSE 'aprovador_id' END;
    EXECUTE format('DROP POLICY IF EXISTS nexo_003_solicitar ON public.%I',t);
    EXECUTE format('CREATE POLICY nexo_003_solicitar ON public.%I AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.nexo_pode_executar(execucao_id))',t);
    EXECUTE format('DROP POLICY IF EXISTS nexo_003_responder ON public.%I',t);
    EXECUTE format('CREATE POLICY nexo_003_responder ON public.%I AS RESTRICTIVE FOR UPDATE TO authenticated USING (%I=public.nexo_usuario_pessoa_id() AND public.nexo_usuario_perfil()<>''AUDITOR'') WITH CHECK (%I=public.nexo_usuario_pessoa_id() AND public.nexo_usuario_perfil()<>''AUDITOR'')',t,pessoa,pessoa);
    EXECUTE format('DROP POLICY IF EXISTS nexo_003_decisao_delete ON public.%I',t);
    EXECUTE format('CREATE POLICY nexo_003_decisao_delete ON public.%I AS RESTRICTIVE FOR DELETE TO authenticated USING (false)',t);
    EXECUTE format('DROP TRIGGER IF EXISTS trg_nexo_003_decisao ON public.%I',t);
    EXECUTE format('CREATE TRIGGER trg_nexo_003_decisao BEFORE INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.nexo_003_guardar_decisao()',t);
  END LOOP;
END $$;

-- Escrita operacional não é concedida a quem apenas acompanha/conhece a execução.
DO $$ DECLARE t text; acao text; BEGIN
  FOREACH t IN ARRAY ARRAY['dependencias','bloqueios','retrabalhos','evidencias','execucao_participantes','execucao_status_historico'] LOOP
    FOREACH acao IN ARRAY ARRAY['INSERT','UPDATE','DELETE'] LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I','nexo_003_'||lower(acao),t);
      IF acao='INSERT' THEN
        EXECUTE format('CREATE POLICY %I ON public.%I AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK (public.nexo_pode_executar(execucao_id))','nexo_003_'||lower(acao),t);
      ELSIF acao='UPDATE' THEN
        EXECUTE format('CREATE POLICY %I ON public.%I AS RESTRICTIVE FOR UPDATE TO authenticated USING (public.nexo_pode_executar(execucao_id)) WITH CHECK (public.nexo_pode_executar(execucao_id))','nexo_003_'||lower(acao),t);
      ELSE
        EXECUTE format('CREATE POLICY %I ON public.%I AS RESTRICTIVE FOR DELETE TO authenticated USING (false)','nexo_003_'||lower(acao),t);
      END IF;
    END LOOP;
  END LOOP;
END $$;

-- A função de conclusão atualizada e COMMIT são definidos abaixo.

-- Histórico específico: evita depender das regras da auditoria genérica.
CREATE TABLE IF NOT EXISTS public.nexo_decisao_historico (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  execucao_id uuid NOT NULL,
  solicitacao_id uuid NOT NULL,
  etapa text NOT NULL CHECK (etapa IN ('CONFERENCIA','APROVACAO')),
  acao text NOT NULL CHECK (acao IN ('SOLICITADA','APROVADA','REJEITADA')),
  ator_id uuid NOT NULL,
  ocorrido_em timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE public.nexo_decisao_historico ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.nexo_decisao_historico FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.nexo_decisao_historico TO authenticated;
DROP POLICY IF EXISTS nexo_003_historico_select ON public.nexo_decisao_historico;
CREATE POLICY nexo_003_historico_select ON public.nexo_decisao_historico FOR SELECT TO authenticated
USING (public.nexo_pode_ver_execucao(execucao_id));

CREATE OR REPLACE FUNCTION public.nexo_003_registrar_decisao()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public
AS $$
DECLARE v_anterior text; v_proximo text;
BEGIN
  INSERT INTO public.nexo_decisao_historico(execucao_id,solicitacao_id,etapa,acao,ator_id)
  VALUES (new.execucao_id,new.id,
    CASE WHEN TG_TABLE_NAME='conferencias' THEN 'CONFERENCIA' ELSE 'APROVACAO' END,
    CASE WHEN TG_OP='INSERT' THEN 'SOLICITADA'
      ELSE to_jsonb(new)->>CASE WHEN TG_TABLE_NAME='conferencias' THEN 'resultado' ELSE 'status' END END,
    public.nexo_usuario_pessoa_id());
  IF TG_OP='INSERT' THEN
    SELECT status INTO v_anterior FROM public.execucoes WHERE id=new.execucao_id;
    v_proximo := CASE WHEN TG_TABLE_NAME='conferencias' THEN 'AGUARDANDO_CONFERENCIA' ELSE 'AGUARDANDO_APROVACAO' END;
    UPDATE public.execucoes SET status=v_proximo,updated_at=clock_timestamp() WHERE id=new.execucao_id;
    IF v_anterior IS DISTINCT FROM v_proximo THEN
      INSERT INTO public.execucao_status_historico(id,execucao_id,status_anterior,status_novo,alterado_por,motivo,created_at)
      VALUES(gen_random_uuid(),new.execucao_id,v_anterior,v_proximo,public.nexo_usuario_pessoa_id(),'Solicitação de etapa',clock_timestamp());
    END IF;
  END IF;
  RETURN new;
END $$;
REVOKE ALL ON FUNCTION public.nexo_003_registrar_decisao() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS trg_nexo_003_registrar_decisao ON public.conferencias;
CREATE TRIGGER trg_nexo_003_registrar_decisao AFTER INSERT OR UPDATE ON public.conferencias
FOR EACH ROW EXECUTE FUNCTION public.nexo_003_registrar_decisao();
DROP TRIGGER IF EXISTS trg_nexo_003_registrar_decisao ON public.aprovacoes;
CREATE TRIGGER trg_nexo_003_registrar_decisao AFTER INSERT OR UPDATE ON public.aprovacoes
FOR EACH ROW EXECUTE FUNCTION public.nexo_003_registrar_decisao();
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
REVOKE EXECUTE ON FUNCTION public.nexo_concluir_execucao(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nexo_concluir_execucao(uuid) TO authenticated;
COMMIT;
SELECT 'ETAPA 3 APLICADA' AS resultado;
