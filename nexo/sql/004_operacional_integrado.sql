-- Pacote operacional. Supabase > SQL Editor > New query. Executar inteiro.
-- Pré-requisito: 002 e 003 aplicados. Não exclui registros nem altera tipos existentes.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$ BEGIN IF to_regprocedure('public.nexo_pode_executar(uuid)') IS NULL THEN RAISE EXCEPTION 'Aplique as etapas 002 e 003 antes deste pacote'; END IF; END $$;
ALTER TABLE public.demandas ADD COLUMN IF NOT EXISTS motivo_gestao text;
SET LOCAL lock_timeout='5s';
CREATE TABLE IF NOT EXISTS public.nexo_governanca (
 empresa_id uuid PRIMARY KEY, pontuacao text NOT NULL DEFAULT 'TODOS'
 CHECK(pontuacao IN ('TODOS','GESTAO','DESATIVADA')), atualizado_por uuid, atualizado_em timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.nexo_governanca_historico (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), empresa_id uuid NOT NULL,
 anterior text, novo text NOT NULL, ator_id uuid NOT NULL, ocorrido_em timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.nexo_governanca ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nexo_governanca_historico ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.nexo_governanca,public.nexo_governanca_historico FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.nexo_governanca,public.nexo_governanca_historico TO authenticated;
DROP POLICY IF EXISTS leitura ON public.nexo_governanca;
CREATE POLICY leitura ON public.nexo_governanca FOR SELECT TO authenticated USING(empresa_id=nexo_usuario_empresa_id());
DROP POLICY IF EXISTS leitura ON public.nexo_governanca_historico;
CREATE POLICY leitura ON public.nexo_governanca_historico FOR SELECT TO authenticated USING(empresa_id=nexo_usuario_empresa_id() AND nexo_usuario_perfil() IN ('ADMIN','DIRETORIA'));

-- Equipe = próprio setor ou subordinados na cadeia gestor_id. UNION encerra ciclos.
CREATE OR REPLACE FUNCTION public.nexo_pessoa_no_escopo(p_pessoa uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 WITH RECURSIVE equipe AS (
 SELECT id FROM pessoas WHERE id=nexo_usuario_pessoa_id() AND empresa_id=nexo_usuario_empresa_id()
 UNION SELECT p.id FROM pessoas p JOIN equipe e ON p.gestor_id=e.id WHERE p.empresa_id=nexo_usuario_empresa_id())
 SELECT EXISTS(SELECT 1 FROM pessoas p WHERE p.id=p_pessoa AND p.empresa_id=nexo_usuario_empresa_id()
 AND (nexo_perfil_empresa() OR p.id=nexo_usuario_pessoa_id()
 OR (nexo_perfil_setor() AND (p.setor_id=nexo_usuario_setor_id() OR p.id IN (SELECT id FROM equipe)))))
$$;
CREATE OR REPLACE FUNCTION public.nexo_configurar_pontuacao(p_modo text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_anterior text; v_empresa uuid:=nexo_usuario_empresa_id();
BEGIN
 IF v_empresa IS NULL OR nexo_usuario_perfil() NOT IN ('ADMIN','DIRETORIA') THEN RAISE EXCEPTION 'Somente a diretoria pode configurar a pontuação.'; END IF;
 IF p_modo IS NULL OR p_modo NOT IN ('TODOS','GESTAO','DESATIVADA') THEN RAISE EXCEPTION 'Modo inválido'; END IF;
 PERFORM pg_advisory_xact_lock(hashtext(v_empresa::text));
 SELECT pontuacao INTO v_anterior FROM nexo_governanca WHERE empresa_id=v_empresa;
 INSERT INTO nexo_governanca VALUES(v_empresa,p_modo,nexo_usuario_pessoa_id(),now())
 ON CONFLICT(empresa_id) DO UPDATE SET pontuacao=excluded.pontuacao,atualizado_por=excluded.atualizado_por,atualizado_em=excluded.atualizado_em;
 INSERT INTO nexo_governanca_historico(empresa_id,anterior,novo,ator_id) VALUES(v_empresa,coalesce(v_anterior,'TODOS'),p_modo,nexo_usuario_pessoa_id());
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
        OR (public.nexo_perfil_setor() AND public.nexo_pessoa_no_escopo(e.responsavel_id))
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
 SELECT EXISTS(SELECT 1 FROM demandas d WHERE d.id=p_demanda AND d.empresa_id=nexo_usuario_empresa_id()
 AND (nexo_perfil_empresa() OR d.responsavel_id=nexo_usuario_pessoa_id() OR d.solicitante_id=nexo_usuario_pessoa_id()
 OR (nexo_perfil_setor() AND (d.setor_id=nexo_usuario_setor_id() OR nexo_pessoa_no_escopo(d.responsavel_id)))))
$$;
DROP POLICY IF EXISTS nexo_004_escopo ON public.demandas;
CREATE POLICY nexo_004_escopo ON public.demandas AS RESTRICTIVE FOR SELECT TO authenticated USING(nexo_pode_ver_demanda(id));
DROP POLICY IF EXISTS nexo_004_leitura ON public.demandas;
CREATE POLICY nexo_004_leitura ON public.demandas FOR SELECT TO authenticated USING(nexo_pode_ver_demanda(id));
DROP POLICY IF EXISTS nexo_004_leitura ON public.demanda_status_historico;
CREATE POLICY nexo_004_leitura ON public.demanda_status_historico FOR SELECT TO authenticated USING(nexo_pode_ver_demanda(demanda_id));
DROP POLICY IF EXISTS nexo_004_escopo ON public.demanda_status_historico;
CREATE POLICY nexo_004_escopo ON public.demanda_status_historico AS RESTRICTIVE FOR SELECT TO authenticated USING(nexo_pode_ver_demanda(demanda_id));
DROP POLICY IF EXISTS nexo_004_escopo ON public.execucoes;
CREATE POLICY nexo_004_escopo ON public.execucoes AS RESTRICTIVE FOR SELECT TO authenticated USING(nexo_pode_ver_execucao(id));

CREATE OR REPLACE FUNCTION public.nexo_painel_operacional(p_dias integer DEFAULT 30)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE v jsonb; v_modo text; v_score boolean; v_inicio timestamptz;
BEGIN
 IF nexo_usuario_empresa_id() IS NULL THEN RAISE EXCEPTION 'Acesso inativo'; END IF;
 IF p_dias IS NULL OR p_dias NOT IN (7,30,90) THEN RAISE EXCEPTION 'Período inválido'; END IF;
 v_inicio:=date_trunc('day',now() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC' - (p_dias-1)*interval '1 day';
 SELECT pontuacao INTO v_modo FROM nexo_governanca WHERE empresa_id=nexo_usuario_empresa_id();
 v_modo:=coalesce(v_modo,'TODOS');
 v_score:=v_modo='TODOS' OR (v_modo='GESTAO' AND nexo_usuario_perfil() IN ('ADMIN','DIRETORIA','LIDER','GESTOR','GERENTE'));
 WITH e AS MATERIALIZED (
 SELECT e.*,o.nome operacao,s.nome setor,
 EXISTS(SELECT 1 FROM bloqueios b WHERE b.execucao_id=e.id AND b.ativo) bloqueada,
 EXISTS(SELECT 1 FROM dependencias d WHERE d.execucao_id=e.id AND d.ativo) dependente,
 EXISTS(SELECT 1 FROM retrabalhos r WHERE r.execucao_id=e.id) retrabalho
 FROM execucoes e JOIN operacoes o ON o.id=e.operacao_id LEFT JOIN setores s ON s.id=o.setor_id
 WHERE o.empresa_id=nexo_usuario_empresa_id() AND nexo_pode_ver_execucao(e.id)),
 abertas AS (SELECT * FROM e WHERE status NOT IN ('CONCLUIDA','CANCELADA')),
 feitas AS (SELECT * FROM e WHERE status='CONCLUIDA' AND data_conclusao>=v_inicio AND data_conclusao<=now()),
 equipe AS (SELECT p.id,p.nome,
 (SELECT count(*) FROM abertas a WHERE a.responsavel_id=p.id) abertas,
 (SELECT count(*) FROM abertas a WHERE a.responsavel_id=p.id AND a.data_prevista<now()) atrasadas,
 count(f.id) entregues,count(f.id) FILTER(WHERE f.data_prevista IS NOT NULL) amostra,
 CASE WHEN v_score THEN round(100.0*count(f.id) FILTER(WHERE f.data_conclusao<=f.data_prevista)/nullif(count(f.id) FILTER(WHERE f.data_prevista IS NOT NULL),0),1) END pontuacao
 FROM pessoas p LEFT JOIN feitas f ON f.responsavel_id=p.id
 WHERE p.empresa_id=nexo_usuario_empresa_id() AND p.ativo AND nexo_pessoa_no_escopo(p.id) GROUP BY p.id,p.nome)
 SELECT jsonb_build_object(
 'gerado_em',now(),'inicio',v_inicio,'modo',v_modo,'pontuacao_visivel',v_score,
 'abertas',(SELECT count(*) FROM abertas),
 'atrasadas',(SELECT count(*) FROM abertas WHERE data_prevista<now()),
 'sem_prazo',(SELECT count(*) FROM abertas WHERE data_prevista IS NULL),
 'bloqueadas',(SELECT count(*) FROM abertas WHERE bloqueada),
 'dependencias',(SELECT count(*) FROM abertas WHERE dependente),
 'entregues',(SELECT count(*) FROM feitas),
 'amostra_prazo',(SELECT count(*) FROM feitas WHERE data_prevista IS NOT NULL),
 'no_prazo',(SELECT round(100.0*count(*) FILTER(WHERE data_conclusao<=data_prevista)/nullif(count(*) FILTER(WHERE data_prevista IS NOT NULL),0),1) FROM feitas),
 'retrabalho',(SELECT round(100.0*count(*) FILTER(WHERE retrabalho)/nullif(count(*),0),1) FROM feitas),
 'ciclo_horas',(SELECT round(avg(extract(epoch FROM (data_conclusao-data_inicio))/3600)::numeric,1) FROM feitas WHERE data_inicio IS NOT NULL AND data_conclusao>=data_inicio),
 'sla', (SELECT round(100.0*count(*) FILTER(WHERE data_conclusao<=data_inicio+sla_minutos*interval '1 minute')/nullif(count(*),0),1) FROM feitas WHERE data_inicio IS NOT NULL AND sla_minutos>0 AND data_conclusao>=data_inicio),
 'idade',coalesce((SELECT jsonb_agg(x ORDER BY x.ordem) FROM (SELECT CASE WHEN created_at IS NULL THEN 'Sem data' WHEN created_at>=now()-interval '2 days' THEN 'Até 2 dias' WHEN created_at>=now()-interval '7 days' THEN '3 a 7 dias' WHEN created_at>=now()-interval '14 days' THEN '8 a 14 dias' ELSE 'Mais de 14 dias' END nome, CASE WHEN created_at IS NULL THEN 5 WHEN created_at>=now()-interval '2 days' THEN 1 WHEN created_at>=now()-interval '7 days' THEN 2 WHEN created_at>=now()-interval '14 days' THEN 3 ELSE 4 END ordem,count(*) valor FROM abertas GROUP BY 1,2) x),'[]'::jsonb),
 'causas',coalesce((SELECT jsonb_agg(x) FROM (SELECT coalesce(nullif(trim(b.motivo),''),'Sem motivo') nome,count(*) valor FROM bloqueios b JOIN abertas a ON a.id=b.execucao_id WHERE b.ativo GROUP BY 1 ORDER BY count(*) DESC LIMIT 10) x),'[]'::jsonb),
 'demandas_abertas',(SELECT count(*) FROM demandas WHERE nexo_pode_ver_demanda(id) AND status NOT IN ('CONCLUIDA','CANCELADA') AND execucao_id IS NULL),
 'status',coalesce((SELECT jsonb_agg(x) FROM (SELECT status nome,count(*) valor FROM abertas GROUP BY status ORDER BY count(*) DESC) x),'[]'::jsonb),
 'gargalos',coalesce((SELECT jsonb_agg(x) FROM (SELECT coalesce(setor,'Sem setor') nome,count(*) valor,count(*) FILTER(WHERE data_prevista<now()) atrasadas FROM abertas GROUP BY setor ORDER BY count(*) DESC) x),'[]'::jsonb),
 'fluxo',coalesce((SELECT jsonb_agg(x ORDER BY x.dia) FROM (SELECT to_char(d,'DD/MM') nome,to_char(d,'YYYY-MM-DD') dia,
 (SELECT count(*) FROM e WHERE created_at>=d AND created_at<d+interval '1 day') entradas,
 (SELECT count(*) FROM feitas WHERE data_conclusao>=d AND data_conclusao<d+interval '1 day') valor
 FROM generate_series(v_inicio,date_trunc('day',now() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC',interval '1 day') d) x),'[]'::jsonb),
 'equipe',coalesce((SELECT jsonb_agg(equipe ORDER BY atrasadas DESC,abertas DESC,nome) FROM equipe),'[]'::jsonb),
 'fila',coalesce((SELECT jsonb_agg(x) FROM (SELECT id,titulo,operacao,status,data_prevista,bloqueada,dependente FROM abertas ORDER BY (data_prevista<now()) DESC NULLS LAST,bloqueada DESC,data_prevista ASC NULLS LAST,id LIMIT 50) x),'[]'::jsonb),
 'decisoes',coalesce((SELECT jsonb_agg(x) FROM (
 SELECT c.execucao_id,e.titulo,'Conferência' etapa FROM conferencias c JOIN e ON e.id=c.execucao_id WHERE c.resultado='PENDENTE' AND c.conferente_id=nexo_usuario_pessoa_id()
 UNION ALL SELECT a.execucao_id,e.titulo,'Aprovação' FROM aprovacoes a JOIN e ON e.id=a.execucao_id WHERE a.status='PENDENTE' AND a.aprovador_id=nexo_usuario_pessoa_id()) x),'[]'::jsonb)
 ) INTO v;
 RETURN v;
END $$;
REVOKE ALL ON FUNCTION public.nexo_pessoa_no_escopo(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.nexo_pessoa_no_escopo(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.nexo_configurar_pontuacao(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.nexo_configurar_pontuacao(text) TO authenticated;
REVOKE ALL ON FUNCTION public.nexo_pode_ver_demanda(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.nexo_pode_ver_demanda(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.nexo_painel_operacional(integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.nexo_painel_operacional(integer) TO authenticated;
-- Pessoas completas seguem o escopo; diretório mínimo permite selecionar conferentes.
DROP POLICY IF EXISTS nexo_004_escopo ON public.pessoas;
CREATE POLICY nexo_004_escopo ON public.pessoas AS RESTRICTIVE FOR SELECT TO authenticated
USING(id=nexo_identidade_pessoa_id() OR nexo_pessoa_no_escopo(id));
CREATE OR REPLACE FUNCTION public.nexo_diretorio()
RETURNS TABLE(id uuid,nome text,setor_id uuid) LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT p.id,p.nome,p.setor_id FROM pessoas p WHERE p.empresa_id=nexo_usuario_empresa_id() AND p.ativo ORDER BY p.nome
$$;
CREATE OR REPLACE FUNCTION public.nexo_pode_atribuir(p_pessoa uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT nexo_usuario_perfil()<>'AUDITOR' AND EXISTS(SELECT 1 FROM pessoas WHERE id=p_pessoa
 AND empresa_id=nexo_usuario_empresa_id() AND ativo)
 AND (p_pessoa=nexo_usuario_pessoa_id() OR (nexo_usuario_perfil() IN ('ADMIN','DIRETORIA','LIDER','GESTOR','GERENTE') AND nexo_pessoa_no_escopo(p_pessoa)))
$$;
CREATE OR REPLACE FUNCTION public.nexo_pode_editar_demanda(p_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
 SELECT nexo_usuario_perfil()<>'AUDITOR' AND EXISTS(SELECT 1 FROM demandas d WHERE d.id=p_id
 AND d.empresa_id=nexo_usuario_empresa_id() AND
 (nexo_usuario_perfil() IN ('ADMIN','DIRETORIA') OR d.responsavel_id=nexo_usuario_pessoa_id()
 OR (d.execucao_id IS NOT NULL AND nexo_pode_executar(d.execucao_id)) OR (d.responsavel_id IS NULL AND d.solicitante_id=nexo_usuario_pessoa_id())
 OR (nexo_perfil_setor() AND (d.setor_id=nexo_usuario_setor_id() OR nexo_pessoa_no_escopo(d.responsavel_id)))))
$$;
DROP POLICY IF EXISTS nexo_004_criar ON public.demandas;
CREATE POLICY nexo_004_criar ON public.demandas FOR INSERT TO authenticated WITH CHECK(empresa_id=nexo_usuario_empresa_id() AND solicitante_id=nexo_usuario_pessoa_id() AND nexo_usuario_perfil()<>'AUDITOR');
DROP POLICY IF EXISTS nexo_004_editar ON public.demandas;
CREATE POLICY nexo_004_editar ON public.demandas FOR UPDATE TO authenticated USING(nexo_pode_editar_demanda(id)) WITH CHECK(nexo_pode_editar_demanda(id));
DROP POLICY IF EXISTS nexo_004_editar_limite ON public.demandas;
CREATE POLICY nexo_004_editar_limite ON public.demandas AS RESTRICTIVE FOR UPDATE TO authenticated USING(nexo_pode_editar_demanda(id)) WITH CHECK(nexo_pode_editar_demanda(id));
DROP POLICY IF EXISTS nexo_004_excluir ON public.demandas;
CREATE POLICY nexo_004_excluir ON public.demandas AS RESTRICTIVE FOR DELETE TO authenticated USING(false);

CREATE OR REPLACE FUNCTION public.nexo_004_guardar_demanda()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF new.empresa_id IS DISTINCT FROM nexo_usuario_empresa_id() OR nexo_usuario_perfil()='AUDITOR' THEN RAISE EXCEPTION 'Sem permissão'; END IF;
 IF tg_op='INSERT' THEN
   IF new.solicitante_id IS DISTINCT FROM nexo_usuario_pessoa_id() OR new.status<>'ABERTA' OR new.execucao_id IS NOT NULL THEN RAISE EXCEPTION 'Criação inválida'; END IF;
   new.created_at:=now(); new.data_inicio:=null; new.data_conclusao:=null; new.percentual_conclusao:=0;
 ELSE
   IF NOT nexo_pode_editar_demanda(old.id) THEN RAISE EXCEPTION 'Sem permissão para editar demanda'; END IF;
   IF new.id IS DISTINCT FROM old.id OR new.empresa_id IS DISTINCT FROM old.empresa_id OR new.solicitante_id IS DISTINCT FROM old.solicitante_id OR new.created_at IS DISTINCT FROM old.created_at THEN RAISE EXCEPTION 'Identificação imutável'; END IF;
   IF old.status IN ('CONCLUIDA','CANCELADA') AND NOT (old.execucao_id IS NOT NULL AND nexo_usuario_perfil() IN ('ADMIN','DIRETORIA','LIDER','GESTOR','GERENTE') AND EXISTS(SELECT 1 FROM execucoes WHERE id=old.execucao_id AND status='EM_EXECUCAO')) THEN RAISE EXCEPTION 'Demanda encerrada'; END IF;
   IF old.execucao_id IS NOT NULL AND (new.execucao_id IS DISTINCT FROM old.execucao_id OR new.operacao_id IS DISTINCT FROM old.operacao_id) THEN RAISE EXCEPTION 'Vínculo operacional imutável'; END IF;
   IF old.execucao_id IS NOT NULL AND (new.status IS DISTINCT FROM old.status OR new.percentual_conclusao IS DISTINCT FROM old.percentual_conclusao) AND NOT EXISTS(SELECT 1 FROM execucoes WHERE id=old.execucao_id AND (CASE WHEN status IN ('CONCLUIDA','CANCELADA') THEN status WHEN status LIKE 'AGUARDANDO%' OR status='BLOQUEADA' THEN 'AGUARDANDO' ELSE 'EM_EXECUCAO' END)=new.status AND percentual_conclusao=new.percentual_conclusao) THEN RAISE EXCEPTION 'Atualize a execução vinculada'; END IF;
 END IF;
 IF new.responsavel_id IS NOT NULL AND (tg_op='INSERT' OR new.responsavel_id IS DISTINCT FROM old.responsavel_id) AND NOT nexo_pode_atribuir(new.responsavel_id) THEN RAISE EXCEPTION 'Responsável fora do seu escopo'; END IF;
 IF new.setor_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM setores WHERE id=new.setor_id AND empresa_id=new.empresa_id) THEN RAISE EXCEPTION 'Setor inválido'; END IF;
 IF new.processo_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM processos WHERE id=new.processo_id AND empresa_id=new.empresa_id AND (new.setor_id IS NULL OR setor_id=new.setor_id)) THEN RAISE EXCEPTION 'Processo inválido'; END IF;
 IF new.operacao_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM operacoes WHERE id=new.operacao_id AND empresa_id=new.empresa_id AND (new.setor_id IS NULL OR setor_id=new.setor_id) AND (new.processo_id IS NULL OR processo_id=new.processo_id)) THEN RAISE EXCEPTION 'Operação inválida'; END IF;
 IF new.execucao_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM execucoes WHERE id=new.execucao_id AND operacao_id=new.operacao_id AND responsavel_id=new.responsavel_id AND nexo_pode_executar(id)) THEN RAISE EXCEPTION 'Execução inválida'; END IF;
 IF new.titulo IS NULL OR length(trim(new.titulo))=0 OR new.percentual_conclusao NOT BETWEEN 0 AND 100 THEN RAISE EXCEPTION 'Título ou progresso inválido'; END IF;
 new.updated_at:=now();
 IF new.status='EM_EXECUCAO' THEN new.data_inicio:=coalesce(new.data_inicio,now()); new.data_conclusao:=NULL; END IF;
 IF new.status IN ('CONCLUIDA','CANCELADA') THEN new.data_conclusao:=now(); END IF;
 IF new.status='CONCLUIDA' THEN new.percentual_conclusao:=100; END IF;
 RETURN new;
END $$;
DROP TRIGGER IF EXISTS nexo_004_guardar_demanda ON public.demandas;
CREATE TRIGGER nexo_004_guardar_demanda BEFORE INSERT OR UPDATE ON public.demandas FOR EACH ROW EXECUTE FUNCTION nexo_004_guardar_demanda();
CREATE OR REPLACE FUNCTION public.nexo_004_historico_demanda()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF tg_op='INSERT' OR new.status IS DISTINCT FROM old.status THEN
 INSERT INTO demanda_status_historico(id,demanda_id,status_anterior,status_novo,alterado_por,motivo,created_at)
 VALUES(gen_random_uuid(),new.id,CASE WHEN tg_op='UPDATE' THEN old.status END,new.status,nexo_usuario_pessoa_id(),CASE WHEN tg_op='INSERT' THEN 'Demanda criada' ELSE coalesce(nullif(new.motivo_gestao,''),'Atualização operacional') END,now());
 END IF; RETURN new;
END $$;
DROP TRIGGER IF EXISTS nexo_004_historico_demanda ON public.demandas;
CREATE TRIGGER nexo_004_historico_demanda AFTER INSERT OR UPDATE ON public.demandas FOR EACH ROW EXECUTE FUNCTION nexo_004_historico_demanda();

DROP POLICY IF EXISTS nexo_004_criar ON public.execucoes;
CREATE POLICY nexo_004_criar ON public.execucoes FOR INSERT TO authenticated WITH CHECK(nexo_pode_atribuir(responsavel_id) AND EXISTS(SELECT 1 FROM operacoes WHERE id=operacao_id AND empresa_id=nexo_usuario_empresa_id()));
CREATE OR REPLACE FUNCTION public.nexo_004_criar_execucao()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF NOT nexo_pode_atribuir(new.responsavel_id) OR NOT EXISTS(SELECT 1 FROM operacoes WHERE id=new.operacao_id AND empresa_id=nexo_usuario_empresa_id() AND ativo) THEN RAISE EXCEPTION 'Operação ou responsável fora do seu escopo'; END IF;
 IF new.status IS DISTINCT FROM 'NAO_INICIADA' THEN RAISE EXCEPTION 'Execuções devem iniciar como não iniciadas'; END IF;
 new.created_at:=now(); new.updated_at:=now(); new.data_inicio:=null; new.data_conclusao:=null; new.percentual_conclusao:=0;
 RETURN new;
END $$;
DROP TRIGGER IF EXISTS nexo_004_criar_execucao ON public.execucoes;
CREATE TRIGGER nexo_004_criar_execucao BEFORE INSERT ON public.execucoes FOR EACH ROW EXECUTE FUNCTION nexo_004_criar_execucao();
CREATE OR REPLACE FUNCTION public.nexo_004_iniciar_execucao()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 INSERT INTO execucao_participantes(id,execucao_id,pessoa_id,papel,ativo,created_at) VALUES(gen_random_uuid(),new.id,new.responsavel_id,'RESPONSAVEL',true,now());
 INSERT INTO execucao_status_historico(id,execucao_id,status_novo,alterado_por,motivo,created_at) VALUES(gen_random_uuid(),new.id,new.status,nexo_usuario_pessoa_id(),'Execução criada',now());
 RETURN new;
END $$;
DROP TRIGGER IF EXISTS nexo_004_iniciar_execucao ON public.execucoes;
CREATE TRIGGER nexo_004_iniciar_execucao AFTER INSERT ON public.execucoes FOR EACH ROW EXECUTE FUNCTION nexo_004_iniciar_execucao();
CREATE OR REPLACE FUNCTION public.nexo_converter_demanda(p_demanda uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE d demandas%rowtype; v_id uuid:=gen_random_uuid();
BEGIN
 SELECT * INTO d FROM demandas WHERE id=p_demanda FOR UPDATE;
 IF NOT FOUND OR NOT nexo_pode_editar_demanda(d.id) THEN RAISE EXCEPTION 'Demanda indisponível'; END IF;
 IF d.execucao_id IS NOT NULL THEN RETURN d.execucao_id; END IF;
 IF d.status IN ('CONCLUIDA','CANCELADA') OR d.operacao_id IS NULL OR d.responsavel_id IS NULL THEN RAISE EXCEPTION 'Defina operação e responsável em uma demanda aberta'; END IF;
 INSERT INTO execucoes(id,operacao_id,responsavel_id,titulo,descricao,status,prioridade,data_prevista,percentual_conclusao)
 VALUES(v_id,d.operacao_id,d.responsavel_id,d.titulo,d.descricao,'NAO_INICIADA',d.prioridade,d.data_prevista,0);
 UPDATE demandas SET execucao_id=v_id,status='EM_EXECUCAO',data_inicio=coalesce(data_inicio,now()) WHERE id=d.id;
 RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION public.nexo_diretorio(),public.nexo_pode_atribuir(uuid),public.nexo_pode_editar_demanda(uuid),public.nexo_converter_demanda(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.nexo_diretorio(),public.nexo_pode_atribuir(uuid),public.nexo_pode_editar_demanda(uuid),public.nexo_converter_demanda(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.nexo_004_guardar_demanda(),public.nexo_004_historico_demanda(),public.nexo_004_criar_execucao(),public.nexo_004_iniciar_execucao() FROM PUBLIC,anon,authenticated;

ALTER TABLE public.execucoes ADD COLUMN IF NOT EXISTS motivo_gestao text;
ALTER TABLE public.demandas ADD COLUMN IF NOT EXISTS motivo_gestao text;
CREATE TABLE IF NOT EXISTS public.nexo_gestao_historico (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),empresa_id uuid NOT NULL,entidade text NOT NULL,registro_id uuid NOT NULL,
 ator_id uuid NOT NULL,motivo text NOT NULL,antes jsonb NOT NULL,depois jsonb NOT NULL,ocorrido_em timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.nexo_gestao_historico ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.nexo_gestao_historico FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.nexo_gestao_historico TO authenticated;
DROP POLICY IF EXISTS leitura ON public.nexo_gestao_historico;
CREATE POLICY leitura ON public.nexo_gestao_historico FOR SELECT TO authenticated USING(empresa_id=nexo_usuario_empresa_id() AND CASE WHEN entidade='execucoes' THEN nexo_pode_ver_execucao(registro_id) ELSE nexo_pode_ver_demanda(registro_id) END);
CREATE OR REPLACE FUNCTION public.nexo_004_auditar_gestao()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF new.responsavel_id IS DISTINCT FROM old.responsavel_id OR new.data_prevista IS DISTINCT FROM old.data_prevista OR new.operacao_id IS DISTINCT FROM old.operacao_id OR (old.status IN ('CONCLUIDA','CANCELADA') AND new.status IS DISTINCT FROM old.status) THEN
 IF nullif(trim(new.motivo_gestao),'') IS NULL THEN RAISE EXCEPTION 'Informe uma justificativa de gestão'; END IF;
 INSERT INTO nexo_gestao_historico(empresa_id,entidade,registro_id,ator_id,motivo,antes,depois)
 VALUES(nexo_usuario_empresa_id(),tg_table_name,new.id,nexo_usuario_pessoa_id(),new.motivo_gestao,
 jsonb_build_object('responsavel',old.responsavel_id,'prazo',old.data_prevista,'operacao',old.operacao_id,'status',old.status),
 jsonb_build_object('responsavel',new.responsavel_id,'prazo',new.data_prevista,'operacao',new.operacao_id,'status',new.status));
 END IF;
 IF tg_table_name='execucoes' AND new.responsavel_id IS DISTINCT FROM old.responsavel_id THEN
 UPDATE execucao_participantes SET ativo=false WHERE execucao_id=new.id AND pessoa_id=old.responsavel_id AND papel='RESPONSAVEL';
 IF EXISTS(SELECT 1 FROM execucao_participantes WHERE execucao_id=new.id AND pessoa_id=new.responsavel_id AND papel='RESPONSAVEL') THEN
 UPDATE execucao_participantes SET ativo=true WHERE execucao_id=new.id AND pessoa_id=new.responsavel_id AND papel='RESPONSAVEL';
 ELSE INSERT INTO execucao_participantes(id,execucao_id,pessoa_id,papel,ativo,created_at) VALUES(gen_random_uuid(),new.id,new.responsavel_id,'RESPONSAVEL',true,now()); END IF;
 END IF; RETURN new;
END $$;
DROP TRIGGER IF EXISTS nexo_004_auditar_gestao ON public.execucoes;
CREATE TRIGGER nexo_004_auditar_gestao AFTER UPDATE ON public.execucoes FOR EACH ROW EXECUTE FUNCTION nexo_004_auditar_gestao();
DROP TRIGGER IF EXISTS nexo_004_auditar_gestao ON public.demandas;
CREATE TRIGGER nexo_004_auditar_gestao AFTER UPDATE ON public.demandas FOR EACH ROW EXECUTE FUNCTION nexo_004_auditar_gestao();
CREATE OR REPLACE FUNCTION public.nexo_gerir_atividade(p_tipo text,p_id uuid,p_responsavel uuid,p_prazo timestamptz,p_motivo text,p_operacao uuid DEFAULT NULL,p_reabrir boolean DEFAULT false)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_id uuid;
BEGIN
 IF nexo_usuario_perfil() NOT IN ('ADMIN','DIRETORIA','LIDER','GESTOR','GERENTE') OR NOT nexo_pode_atribuir(p_responsavel) THEN RAISE EXCEPTION 'Gestão fora do escopo'; END IF;
 IF nullif(trim(p_motivo),'') IS NULL THEN RAISE EXCEPTION 'Informe uma justificativa'; END IF;
 IF p_tipo='execucoes' THEN
 SELECT id INTO v_id FROM execucoes WHERE id=p_id FOR UPDATE;
 IF v_id IS NULL OR NOT nexo_pode_executar(v_id) OR NOT EXISTS(SELECT 1 FROM execucoes e JOIN operacoes o ON o.id=e.operacao_id WHERE e.id=v_id AND (nexo_usuario_perfil() IN ('ADMIN','DIRETORIA') OR nexo_pessoa_no_escopo(e.responsavel_id) OR o.setor_id=nexo_usuario_setor_id())) THEN RAISE EXCEPTION 'Atividade indisponível'; END IF;
 UPDATE execucoes SET responsavel_id=p_responsavel,data_prevista=p_prazo,motivo_gestao=p_motivo,
 status=CASE WHEN p_reabrir AND status IN ('CONCLUIDA','CANCELADA') THEN 'EM_EXECUCAO' ELSE status END,
 data_conclusao=CASE WHEN p_reabrir THEN NULL ELSE data_conclusao END,
 percentual_conclusao=CASE WHEN p_reabrir THEN 0 ELSE percentual_conclusao END,updated_at=now() WHERE id=p_id;
 ELSIF p_tipo='demandas' THEN
 SELECT id INTO v_id FROM demandas WHERE id=p_id FOR UPDATE;
 IF v_id IS NULL OR NOT nexo_pode_editar_demanda(v_id) THEN RAISE EXCEPTION 'Demanda indisponível'; END IF;
 UPDATE demandas SET responsavel_id=p_responsavel,data_prevista=p_prazo,operacao_id=p_operacao,motivo_gestao=p_motivo WHERE id=p_id;
 ELSE RAISE EXCEPTION 'Tipo inválido'; END IF;
END $$;
REVOKE ALL ON FUNCTION public.nexo_004_auditar_gestao() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.nexo_gerir_atividade(text,uuid,uuid,timestamptz,text,uuid,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.nexo_gerir_atividade(text,uuid,uuid,timestamptz,text,uuid,boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.nexo_003_guardar_execucao()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public
AS $$
DECLARE v_op public.operacoes%rowtype; v_resultado text;
BEGIN
  IF NOT public.nexo_pode_executar(old.id) THEN RAISE EXCEPTION 'Sem permissão para executar esta atividade.'; END IF;
  IF new.id IS DISTINCT FROM old.id OR new.operacao_id IS DISTINCT FROM old.operacao_id THEN RAISE EXCEPTION 'Identificação imutável'; END IF;
  IF new.responsavel_id IS DISTINCT FROM old.responsavel_id OR new.data_prevista IS DISTINCT FROM old.data_prevista OR old.status IN ('CONCLUIDA','CANCELADA') THEN
    IF public.nexo_usuario_perfil() NOT IN ('ADMIN','DIRETORIA','LIDER','GESTOR','GERENTE') OR NOT public.nexo_pode_atribuir(new.responsavel_id) OR nullif(trim(new.motivo_gestao),'') IS NULL THEN RAISE EXCEPTION 'Alteração exige gestão e justificativa'; END IF;
    IF old.status IN ('CONCLUIDA','CANCELADA') AND new.status<>'EM_EXECUCAO' THEN RAISE EXCEPTION 'Reabra a execução antes de editar'; END IF;
  END IF;
  IF old.status IN ('CONCLUIDA','CANCELADA') THEN new.data_conclusao:=NULL; new.percentual_conclusao:=0; END IF;
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


DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['setores','cargos','processos','operacoes','operacao_responsaveis','operacao_recorrencias','procedimentos','procedimento_etapas','procedimento_versoes'] LOOP
 EXECUTE format('DROP POLICY IF EXISTS nexo_004_diretoria ON public.%I',t);
 EXECUTE format('CREATE POLICY nexo_004_diretoria ON public.%I FOR ALL TO authenticated USING(nexo_usuario_perfil() = ''DIRETORIA'') WITH CHECK(nexo_usuario_perfil() = ''DIRETORIA'')',t);
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.nexo_004_sincronizar_demanda()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF new.status IS DISTINCT FROM old.status OR new.responsavel_id IS DISTINCT FROM old.responsavel_id OR new.data_prevista IS DISTINCT FROM old.data_prevista OR new.percentual_conclusao IS DISTINCT FROM old.percentual_conclusao THEN
 UPDATE demandas SET responsavel_id=new.responsavel_id,data_prevista=new.data_prevista,percentual_conclusao=new.percentual_conclusao,
 motivo_gestao=coalesce(new.motivo_gestao,'Sincronização da execução'),
 status=CASE WHEN new.status IN ('CONCLUIDA','CANCELADA') THEN new.status WHEN new.status LIKE 'AGUARDANDO%' OR new.status='BLOQUEADA' THEN 'AGUARDANDO' ELSE 'EM_EXECUCAO' END
 WHERE execucao_id=new.id;
 END IF; RETURN new;
END $$;
DROP TRIGGER IF EXISTS nexo_004_sincronizar_demanda ON public.execucoes;
CREATE TRIGGER nexo_004_sincronizar_demanda AFTER UPDATE ON public.execucoes FOR EACH ROW EXECUTE FUNCTION nexo_004_sincronizar_demanda();
REVOKE ALL ON FUNCTION public.nexo_004_sincronizar_demanda() FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.nexo_pode_ver_pessoa(p_pessoa_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$ SELECT nexo_pessoa_no_escopo(p_pessoa_id) $$;
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
SELECT 'PACOTE OPERACIONAL APLICADO' AS resultado;
