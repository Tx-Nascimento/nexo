-- Instalar no SQL Editor como postgres, após 005. Não arquiva nada sozinho.
BEGIN;
SET LOCAL lock_timeout='5s';
CREATE TABLE IF NOT EXISTS public.nexo_arquivo_testes (
 entidade text NOT NULL CHECK(entidade IN ('execucoes','demandas','operacoes','documentos')),
 registro_id uuid NOT NULL, empresa_id uuid NOT NULL, original jsonb NOT NULL,
 arquivado_em timestamptz NOT NULL DEFAULT now(), restaurado_em timestamptz,
 PRIMARY KEY(entidade,registro_id));
ALTER TABLE public.nexo_arquivo_testes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.nexo_arquivo_testes FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.nexo_teste_arquivado(p_entidade text,p_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT EXISTS(SELECT 1 FROM nexo_arquivo_testes WHERE entidade=p_entidade AND registro_id=p_id AND restaurado_em IS NULL)
$$;
REVOKE ALL ON FUNCTION public.nexo_teste_arquivado(text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.nexo_teste_arquivado(text,uuid) TO authenticated;
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['execucoes','demandas','operacoes','documentos'] LOOP
 EXECUTE format('DROP POLICY IF EXISTS nexo_006_arquivo ON public.%I',t);
 EXECUTE format('CREATE POLICY nexo_006_arquivo ON public.%I AS RESTRICTIVE FOR ALL TO authenticated USING(NOT nexo_teste_arquivado(%L,id)) WITH CHECK(NOT nexo_teste_arquivado(%L,id))',t,t,t);
 END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.nexo_pode_executar(p_execucao_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.execucoes e JOIN public.operacoes o ON o.id=e.operacao_id
    WHERE NOT public.nexo_teste_arquivado('execucoes',e.id) AND e.id=p_execucao_id AND o.empresa_id=public.nexo_usuario_empresa_id()
      AND public.nexo_usuario_perfil() <> 'AUDITOR'
      AND (
        public.nexo_usuario_perfil() IN ('ADMIN','DIRETORIA')
        OR e.responsavel_id=public.nexo_usuario_pessoa_id()
        OR EXISTS (SELECT 1 FROM public.execucao_participantes ep
          WHERE ep.execucao_id=e.id AND ep.ativo
            AND ep.pessoa_id=public.nexo_usuario_pessoa_id()
            AND ep.papel IN ('RESPONSAVEL','EXECUTOR'))
        OR (public.nexo_perfil_setor() AND public.nexo_pessoa_no_escopo(e.responsavel_id))
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
    WHERE NOT public.nexo_teste_arquivado('execucoes',e.id) AND e.id=p_execucao_id AND o.empresa_id=public.nexo_usuario_empresa_id()
    AND (
      public.nexo_perfil_empresa() OR e.responsavel_id=public.nexo_usuario_pessoa_id()
      OR EXISTS (SELECT 1 FROM public.execucao_participantes ep WHERE ep.execucao_id=e.id
        AND ep.ativo AND ep.pessoa_id=public.nexo_usuario_pessoa_id())
      OR (public.nexo_perfil_setor() AND public.nexo_pessoa_no_escopo(e.responsavel_id))
        OR (public.nexo_perfil_setor() AND o.setor_id IS NOT NULL
        AND o.setor_id=public.nexo_usuario_setor_id())
      OR EXISTS (SELECT 1 FROM public.conferencias c WHERE c.execucao_id=e.id
        AND c.conferente_id=public.nexo_usuario_pessoa_id())
      OR EXISTS (SELECT 1 FROM public.aprovacoes a WHERE a.execucao_id=e.id
        AND a.aprovador_id=public.nexo_usuario_pessoa_id())
    )
  )
$$;
CREATE OR REPLACE FUNCTION public.nexo_pode_ver_demanda(p_demanda uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT EXISTS(SELECT 1 FROM demandas d WHERE NOT public.nexo_teste_arquivado('demandas',d.id) AND d.id=p_demanda AND d.empresa_id=nexo_usuario_empresa_id()
 AND (nexo_perfil_empresa() OR d.responsavel_id=nexo_usuario_pessoa_id() OR d.solicitante_id=nexo_usuario_pessoa_id()
 OR (nexo_perfil_setor() AND (d.setor_id=nexo_usuario_setor_id() OR nexo_pessoa_no_escopo(d.responsavel_id)))))
$$;
CREATE OR REPLACE FUNCTION public.nexo_pode_editar_demanda(p_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT nexo_usuario_perfil()<>'AUDITOR' AND EXISTS(SELECT 1 FROM demandas d WHERE NOT public.nexo_teste_arquivado('demandas',d.id) AND d.id=p_id
 AND d.empresa_id=nexo_usuario_empresa_id() AND
 (nexo_usuario_perfil() IN ('ADMIN','DIRETORIA') OR d.responsavel_id=nexo_usuario_pessoa_id()
 OR (d.execucao_id IS NOT NULL AND nexo_pode_executar(d.execucao_id)) OR (d.responsavel_id IS NULL AND d.solicitante_id=nexo_usuario_pessoa_id())
 OR (nexo_perfil_setor() AND (d.setor_id=nexo_usuario_setor_id() OR nexo_pessoa_no_escopo(d.responsavel_id)))))
$$;
CREATE OR REPLACE FUNCTION public.nexo_filtros_painel()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 WITH ops AS MATERIALIZED (
 SELECT o.id,o.nome,o.setor_id FROM operacoes o WHERE NOT nexo_teste_arquivado('operacoes',o.id) AND o.empresa_id=nexo_usuario_empresa_id()
 AND (nexo_perfil_empresa() OR (nexo_perfil_setor() AND o.setor_id=nexo_usuario_setor_id())
 OR EXISTS(SELECT 1 FROM execucoes e WHERE e.operacao_id=o.id AND nexo_pode_ver_execucao(e.id))
 OR EXISTS(SELECT 1 FROM demandas d WHERE d.operacao_id=o.id AND nexo_pode_ver_demanda(d.id))
 OR EXISTS(SELECT 1 FROM operacao_responsaveis r WHERE r.operacao_id=o.id AND r.ativo AND r.pessoa_id=nexo_usuario_pessoa_id())))
 SELECT jsonb_build_object('operacoes',coalesce((SELECT jsonb_agg(ops ORDER BY nome,id) FROM ops),'[]'::jsonb),
 'setores',coalesce((SELECT jsonb_agg(x ORDER BY x.nome,x.id) FROM (SELECT s.id,s.nome FROM setores s WHERE s.empresa_id=nexo_usuario_empresa_id()
 AND (nexo_perfil_empresa() OR (nexo_perfil_setor() AND s.id=nexo_usuario_setor_id()) OR s.id IN (SELECT setor_id FROM ops)
 OR EXISTS(SELECT 1 FROM demandas d WHERE d.setor_id=s.id AND nexo_pode_ver_demanda(d.id)))) x),'[]'::jsonb))
$$;

-- A execução é exclusiva do dono do banco. Não há botão/RPC de limpeza para usuários.
CREATE OR REPLACE FUNCTION public.nexo_arquivar_testes(p_lista jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE r record; v jsonb; v_empresa uuid; v_total integer; v_resultado jsonb;
BEGIN
 IF jsonb_typeof(p_lista) IS DISTINCT FROM 'array' OR jsonb_array_length(p_lista)=0 THEN RAISE EXCEPTION 'Informe a lista do diagnóstico'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_to_recordset(p_lista) AS x(entidade text,id uuid,empresa_id uuid,nome text)
 WHERE entidade IS NULL OR entidade NOT IN ('execucoes','demandas','operacoes','documentos') OR id IS NULL OR empresa_id IS NULL OR nome IS NULL) THEN RAISE EXCEPTION 'Lista inválida'; END IF;
 IF (SELECT count(DISTINCT empresa_id) FROM jsonb_to_recordset(p_lista) AS x(empresa_id uuid))<>1 THEN RAISE EXCEPTION 'Execute uma empresa por vez'; END IF;
 IF (SELECT count(*) FROM jsonb_to_recordset(p_lista) AS x(entidade text,id uuid))<>(SELECT count(DISTINCT (entidade,id)) FROM jsonb_to_recordset(p_lista) AS x(entidade text,id uuid)) THEN RAISE EXCEPTION 'IDs repetidos'; END IF;
 SELECT empresa_id INTO v_empresa FROM jsonb_to_recordset(p_lista) AS x(empresa_id uuid) LIMIT 1;
 -- Bloqueia concorrência durante validação, snapshot e inativação de cadastros.
 LOCK TABLE execucoes,demandas,operacoes,documentos,operacao_recorrencias,nexo_arquivo_testes IN SHARE ROW EXCLUSIVE MODE;
 FOR r IN SELECT * FROM jsonb_to_recordset(p_lista) AS x(entidade text,id uuid,empresa_id uuid,nome text) LOOP
 EXECUTE format('SELECT to_jsonb(t) FROM public.%I t WHERE id=$1',r.entidade) INTO v USING r.id;
 IF v IS NULL THEN RAISE EXCEPTION 'Registro não encontrado: % / %',r.entidade,r.id; END IF;
 IF r.entidade='execucoes' THEN
 IF NOT EXISTS(SELECT 1 FROM operacoes WHERE id=(v->>'operacao_id')::uuid AND empresa_id=v_empresa) THEN RAISE EXCEPTION 'Empresa divergente: %',r.id; END IF;
 ELSIF (v->>'empresa_id')::uuid IS DISTINCT FROM v_empresa THEN RAISE EXCEPTION 'Empresa divergente: %',r.id; END IF;
 IF coalesce(v->>'titulo',v->>'nome') IS DISTINCT FROM r.nome OR r.nome !~* '^\[(TESTE|TESTE OPERACIONAL|DEMO)\]' THEN RAISE EXCEPTION 'Nome alterado ou sem identificação explícita de teste: %',r.id; END IF;
 END LOOP;
 -- Não ocultar uma atividade real vinculada a um cadastro de demonstração.
 IF EXISTS(SELECT 1 FROM execucoes e WHERE e.operacao_id IN (SELECT id FROM jsonb_to_recordset(p_lista) AS x(entidade text,id uuid) WHERE entidade='operacoes') AND e.id NOT IN (SELECT id FROM jsonb_to_recordset(p_lista) AS x(entidade text,id uuid) WHERE entidade='execucoes') AND NOT nexo_teste_arquivado('execucoes',e.id)) THEN RAISE EXCEPTION 'Há execuções fora da lista vinculadas às operações de teste. Nada foi arquivado.'; END IF;
 IF EXISTS(SELECT 1 FROM demandas d WHERE (d.operacao_id IN (SELECT id FROM jsonb_to_recordset(p_lista) AS x(entidade text,id uuid) WHERE entidade='operacoes') OR d.execucao_id IN (SELECT id FROM jsonb_to_recordset(p_lista) AS x(entidade text,id uuid) WHERE entidade='execucoes')) AND d.id NOT IN (SELECT id FROM jsonb_to_recordset(p_lista) AS x(entidade text,id uuid) WHERE entidade='demandas') AND NOT nexo_teste_arquivado('demandas',d.id)) THEN RAISE EXCEPTION 'Há demandas fora da lista vinculadas aos testes. Nada foi arquivado.'; END IF;
 FOR r IN SELECT * FROM jsonb_to_recordset(p_lista) AS x(entidade text,id uuid,empresa_id uuid,nome text) LOOP
 EXECUTE format('SELECT to_jsonb(t) FROM public.%I t WHERE id=$1',r.entidade) INTO v USING r.id;
 IF r.entidade='operacoes' THEN v:=v || jsonb_build_object('recorrencias_antes',coalesce((SELECT jsonb_agg(to_jsonb(rc)) FROM operacao_recorrencias rc WHERE rc.operacao_id=r.id),'[]'::jsonb)); END IF;
 INSERT INTO nexo_arquivo_testes(entidade,registro_id,empresa_id,original) VALUES(r.entidade,r.id,v_empresa,v)
 ON CONFLICT(entidade,registro_id) DO UPDATE SET original=CASE WHEN nexo_arquivo_testes.restaurado_em IS NOT NULL THEN excluded.original ELSE nexo_arquivo_testes.original END,restaurado_em=NULL;
 IF r.entidade IN ('operacoes','documentos') THEN EXECUTE format('UPDATE public.%I SET ativo=false WHERE id=$1',r.entidade) USING r.id; END IF;
 IF r.entidade='operacoes' THEN UPDATE operacao_recorrencias SET ativo=false WHERE operacao_id=r.id; END IF;
 END LOOP;
 SELECT jsonb_object_agg(entidade,total) INTO v_resultado FROM (SELECT entidade,count(*) total FROM jsonb_to_recordset(p_lista) AS x(entidade text) GROUP BY entidade) c;
 v_total:=jsonb_array_length(p_lista);
 RETURN jsonb_build_object('resultado','TESTES ARQUIVADOS','total',v_total,'por_entidade',v_resultado,'exclusoes',0);
END $$;
REVOKE ALL ON FUNCTION public.nexo_arquivar_testes(jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.nexo_restaurar_testes(p_empresa uuid)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE r record; n integer:=0;
BEGIN
 LOCK TABLE execucoes,demandas,operacoes,documentos,operacao_recorrencias,nexo_arquivo_testes IN SHARE ROW EXCLUSIVE MODE;
 FOR r IN SELECT * FROM nexo_arquivo_testes WHERE empresa_id=p_empresa AND restaurado_em IS NULL LOOP
 IF r.entidade IN ('operacoes','documentos') THEN EXECUTE format('UPDATE public.%I SET ativo=$1 WHERE id=$2 AND ativo=false',r.entidade) USING (r.original->>'ativo')::boolean,r.registro_id; END IF;
 IF r.entidade='operacoes' THEN UPDATE operacao_recorrencias rc SET ativo=(x->>'ativo')::boolean FROM jsonb_array_elements(coalesce(r.original->'recorrencias_antes','[]'::jsonb)) x WHERE rc.id=(x->>'id')::uuid AND rc.operacao_id=r.registro_id AND rc.ativo=false; END IF;
 UPDATE nexo_arquivo_testes SET restaurado_em=now() WHERE entidade=r.entidade AND registro_id=r.registro_id;
 n:=n+1;
 END LOOP; RETURN n;
END $$;
REVOKE ALL ON FUNCTION public.nexo_restaurar_testes(uuid) FROM PUBLIC,anon,authenticated;
COMMIT;
SELECT 'ARQUIVAMENTO PREPARADO. EXECUTE A LISTA DO DIAGNÓSTICO.' AS resultado;
