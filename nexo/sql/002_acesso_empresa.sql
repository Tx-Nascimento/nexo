-- ETAPA 2A: sessão, administração de acessos e limite por empresa.
-- Supabase > SQL Editor > New query > executar TODO o arquivo como postgres.
-- Não apaga registros. Tudo é aplicado em uma transação.
-- Não modifica Storage nem define novos papéis operacionais.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.usuarios u JOIN public.pessoas p ON p.id=u.pessoa_id
    JOIN public.perfis pf ON pf.id=u.perfil_id
    WHERE u.ativo AND p.ativo AND pf.nome='ADMIN'
  ) THEN RAISE EXCEPTION 'Nenhum ADMIN ativo com pessoa ativa. Corrija o cadastro antes de executar.';
  END IF;
END $$;

-- Identidade mínima para exibir cadastro inativo sem liberar dados operacionais.
CREATE OR REPLACE FUNCTION public.nexo_identidade_pessoa_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT pessoa_id FROM public.usuarios WHERE id = auth.uid() LIMIT 1 $$;
REVOKE ALL ON FUNCTION public.nexo_identidade_pessoa_id() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nexo_identidade_pessoa_id() TO authenticated;


CREATE OR REPLACE FUNCTION public.nexo_usuario_pessoa_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT u.pessoa_id FROM public.usuarios u
JOIN public.pessoas p ON p.id=u.pessoa_id 
WHERE u.id=auth.uid() AND u.ativo AND p.ativo LIMIT 1 $$;

CREATE OR REPLACE FUNCTION public.nexo_usuario_empresa_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT p.empresa_id FROM public.usuarios u
JOIN public.pessoas p ON p.id=u.pessoa_id 
WHERE u.id=auth.uid() AND u.ativo AND p.ativo LIMIT 1 $$;

CREATE OR REPLACE FUNCTION public.nexo_usuario_setor_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT p.setor_id FROM public.usuarios u
JOIN public.pessoas p ON p.id=u.pessoa_id 
WHERE u.id=auth.uid() AND u.ativo AND p.ativo LIMIT 1 $$;

CREATE OR REPLACE FUNCTION public.nexo_usuario_perfil()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT pf.nome FROM public.usuarios u
JOIN public.pessoas p ON p.id=u.pessoa_id JOIN public.perfis pf ON pf.id=u.perfil_id
WHERE u.id=auth.uid() AND u.ativo AND p.ativo LIMIT 1 $$;

CREATE OR REPLACE FUNCTION public.usuario_e_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT coalesce(public.nexo_usuario_perfil() = 'ADMIN', false) $$;

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.empresas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.empresas;
CREATE POLICY nexo_002_limite ON public.empresas AS RESTRICTIVE
FOR ALL TO authenticated USING (id = public.nexo_usuario_empresa_id()) WITH CHECK (id = public.nexo_usuario_empresa_id());

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.pessoas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.pessoas;
CREATE POLICY nexo_002_limite ON public.pessoas AS RESTRICTIVE
FOR ALL TO authenticated USING (empresa_id = public.nexo_usuario_empresa_id() OR id = public.nexo_identidade_pessoa_id()) WITH CHECK (empresa_id = public.nexo_usuario_empresa_id() OR id = public.nexo_identidade_pessoa_id());

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.usuarios;
CREATE POLICY nexo_002_limite ON public.usuarios AS RESTRICTIVE
FOR ALL TO authenticated USING (id = auth.uid() OR EXISTS (SELECT 1 FROM public.pessoas p WHERE p.id = usuarios.pessoa_id AND p.empresa_id = public.nexo_usuario_empresa_id())) WITH CHECK (id = auth.uid() OR EXISTS (SELECT 1 FROM public.pessoas p WHERE p.id = usuarios.pessoa_id AND p.empresa_id = public.nexo_usuario_empresa_id()));

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.setores ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.setores;
CREATE POLICY nexo_002_limite ON public.setores AS RESTRICTIVE
FOR ALL TO authenticated USING (empresa_id = public.nexo_usuario_empresa_id()) WITH CHECK (empresa_id = public.nexo_usuario_empresa_id());

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.cargos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.cargos;
CREATE POLICY nexo_002_limite ON public.cargos AS RESTRICTIVE
FOR ALL TO authenticated USING (empresa_id = public.nexo_usuario_empresa_id()) WITH CHECK (empresa_id = public.nexo_usuario_empresa_id());

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.processos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.processos;
CREATE POLICY nexo_002_limite ON public.processos AS RESTRICTIVE
FOR ALL TO authenticated USING (empresa_id = public.nexo_usuario_empresa_id()) WITH CHECK (empresa_id = public.nexo_usuario_empresa_id());

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.operacoes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.operacoes;
CREATE POLICY nexo_002_limite ON public.operacoes AS RESTRICTIVE
FOR ALL TO authenticated USING (empresa_id = public.nexo_usuario_empresa_id()) WITH CHECK (empresa_id = public.nexo_usuario_empresa_id());

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.demandas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.demandas;
CREATE POLICY nexo_002_limite ON public.demandas AS RESTRICTIVE
FOR ALL TO authenticated USING (empresa_id = public.nexo_usuario_empresa_id()) WITH CHECK (empresa_id = public.nexo_usuario_empresa_id());

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.documentos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.documentos;
CREATE POLICY nexo_002_limite ON public.documentos AS RESTRICTIVE
FOR ALL TO authenticated USING (empresa_id = public.nexo_usuario_empresa_id()) WITH CHECK (empresa_id = public.nexo_usuario_empresa_id());

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.objetivos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.objetivos;
CREATE POLICY nexo_002_limite ON public.objetivos AS RESTRICTIVE
FOR ALL TO authenticated USING (empresa_id = public.nexo_usuario_empresa_id()) WITH CHECK (empresa_id = public.nexo_usuario_empresa_id());

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.indicadores ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.indicadores;
CREATE POLICY nexo_002_limite ON public.indicadores AS RESTRICTIVE
FOR ALL TO authenticated USING (empresa_id = public.nexo_usuario_empresa_id()) WITH CHECK (empresa_id = public.nexo_usuario_empresa_id());

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.execucoes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.execucoes;
CREATE POLICY nexo_002_limite ON public.execucoes AS RESTRICTIVE
FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM public.operacoes o WHERE o.id = execucoes.operacao_id AND o.empresa_id = public.nexo_usuario_empresa_id())) WITH CHECK (EXISTS (SELECT 1 FROM public.operacoes o WHERE o.id = execucoes.operacao_id AND o.empresa_id = public.nexo_usuario_empresa_id()));

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.aprovacoes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.aprovacoes;
CREATE POLICY nexo_002_limite ON public.aprovacoes AS RESTRICTIVE
FOR ALL TO authenticated USING (public.nexo_pode_ver_execucao(execucao_id)) WITH CHECK (public.nexo_pode_ver_execucao(execucao_id));

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.bloqueios ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.bloqueios;
CREATE POLICY nexo_002_limite ON public.bloqueios AS RESTRICTIVE
FOR ALL TO authenticated USING (public.nexo_pode_ver_execucao(execucao_id)) WITH CHECK (public.nexo_pode_ver_execucao(execucao_id));

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.conferencias ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.conferencias;
CREATE POLICY nexo_002_limite ON public.conferencias AS RESTRICTIVE
FOR ALL TO authenticated USING (public.nexo_pode_ver_execucao(execucao_id)) WITH CHECK (public.nexo_pode_ver_execucao(execucao_id));

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.dependencias ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.dependencias;
CREATE POLICY nexo_002_limite ON public.dependencias AS RESTRICTIVE
FOR ALL TO authenticated USING (public.nexo_pode_ver_execucao(execucao_id)) WITH CHECK (public.nexo_pode_ver_execucao(execucao_id));

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.evidencias ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.evidencias;
CREATE POLICY nexo_002_limite ON public.evidencias AS RESTRICTIVE
FOR ALL TO authenticated USING (public.nexo_pode_ver_execucao(execucao_id)) WITH CHECK (public.nexo_pode_ver_execucao(execucao_id));

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.execucao_participantes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.execucao_participantes;
CREATE POLICY nexo_002_limite ON public.execucao_participantes AS RESTRICTIVE
FOR ALL TO authenticated USING (public.nexo_pode_ver_execucao(execucao_id)) WITH CHECK (public.nexo_pode_ver_execucao(execucao_id));

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.execucao_status_historico ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.execucao_status_historico;
CREATE POLICY nexo_002_limite ON public.execucao_status_historico AS RESTRICTIVE
FOR ALL TO authenticated USING (public.nexo_pode_ver_execucao(execucao_id)) WITH CHECK (public.nexo_pode_ver_execucao(execucao_id));

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.retrabalhos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.retrabalhos;
CREATE POLICY nexo_002_limite ON public.retrabalhos AS RESTRICTIVE
FOR ALL TO authenticated USING (public.nexo_pode_ver_execucao(execucao_id)) WITH CHECK (public.nexo_pode_ver_execucao(execucao_id));

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.escalonamentos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.escalonamentos;
CREATE POLICY nexo_002_limite ON public.escalonamentos AS RESTRICTIVE
FOR ALL TO authenticated USING (public.nexo_pode_ver_execucao(execucao_id)) WITH CHECK (public.nexo_pode_ver_execucao(execucao_id));

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.operacao_recorrencias ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.operacao_recorrencias;
CREATE POLICY nexo_002_limite ON public.operacao_recorrencias AS RESTRICTIVE
FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM public.operacoes o WHERE o.id = operacao_recorrencias.operacao_id AND o.empresa_id = public.nexo_usuario_empresa_id())) WITH CHECK (EXISTS (SELECT 1 FROM public.operacoes o WHERE o.id = operacao_recorrencias.operacao_id AND o.empresa_id = public.nexo_usuario_empresa_id()));

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.operacao_responsaveis ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.operacao_responsaveis;
CREATE POLICY nexo_002_limite ON public.operacao_responsaveis AS RESTRICTIVE
FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM public.operacoes o WHERE o.id = operacao_responsaveis.operacao_id AND o.empresa_id = public.nexo_usuario_empresa_id())) WITH CHECK (EXISTS (SELECT 1 FROM public.operacoes o WHERE o.id = operacao_responsaveis.operacao_id AND o.empresa_id = public.nexo_usuario_empresa_id()));

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.procedimentos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.procedimentos;
CREATE POLICY nexo_002_limite ON public.procedimentos AS RESTRICTIVE
FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM public.operacoes o WHERE o.id = procedimentos.operacao_id AND o.empresa_id = public.nexo_usuario_empresa_id())) WITH CHECK (EXISTS (SELECT 1 FROM public.operacoes o WHERE o.id = procedimentos.operacao_id AND o.empresa_id = public.nexo_usuario_empresa_id()));

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.demanda_status_historico ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.demanda_status_historico;
CREATE POLICY nexo_002_limite ON public.demanda_status_historico AS RESTRICTIVE
FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM public.demandas d WHERE d.id = demanda_status_historico.demanda_id AND d.empresa_id = public.nexo_usuario_empresa_id())) WITH CHECK (EXISTS (SELECT 1 FROM public.demandas d WHERE d.id = demanda_status_historico.demanda_id AND d.empresa_id = public.nexo_usuario_empresa_id()));

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.documento_vinculos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.documento_vinculos;
CREATE POLICY nexo_002_limite ON public.documento_vinculos AS RESTRICTIVE
FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM public.documentos d WHERE d.id = documento_vinculos.documento_id AND d.empresa_id = public.nexo_usuario_empresa_id())) WITH CHECK (EXISTS (SELECT 1 FROM public.documentos d WHERE d.id = documento_vinculos.documento_id AND d.empresa_id = public.nexo_usuario_empresa_id()));

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.procedimento_versoes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.procedimento_versoes;
CREATE POLICY nexo_002_limite ON public.procedimento_versoes AS RESTRICTIVE
FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM public.procedimentos p JOIN public.operacoes o ON o.id = p.operacao_id WHERE p.id = procedimento_versoes.procedimento_id AND o.empresa_id = public.nexo_usuario_empresa_id())) WITH CHECK (EXISTS (SELECT 1 FROM public.procedimentos p JOIN public.operacoes o ON o.id = p.operacao_id WHERE p.id = procedimento_versoes.procedimento_id AND o.empresa_id = public.nexo_usuario_empresa_id()));

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.procedimento_etapas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.procedimento_etapas;
CREATE POLICY nexo_002_limite ON public.procedimento_etapas AS RESTRICTIVE
FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM public.procedimento_versoes v JOIN public.procedimentos p ON p.id = v.procedimento_id JOIN public.operacoes o ON o.id = p.operacao_id WHERE v.id = procedimento_etapas.procedimento_versao_id AND o.empresa_id = public.nexo_usuario_empresa_id())) WITH CHECK (EXISTS (SELECT 1 FROM public.procedimento_versoes v JOIN public.procedimentos p ON p.id = v.procedimento_id JOIN public.operacoes o ON o.id = p.operacao_id WHERE v.id = procedimento_etapas.procedimento_versao_id AND o.empresa_id = public.nexo_usuario_empresa_id()));

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.carga_trabalho ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.carga_trabalho;
CREATE POLICY nexo_002_limite ON public.carga_trabalho AS RESTRICTIVE
FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM public.pessoas p WHERE p.id = carga_trabalho.pessoa_id AND p.empresa_id = public.nexo_usuario_empresa_id())) WITH CHECK (EXISTS (SELECT 1 FROM public.pessoas p WHERE p.id = carga_trabalho.pessoa_id AND p.empresa_id = public.nexo_usuario_empresa_id()));

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.auditoria ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.auditoria;
CREATE POLICY nexo_002_limite ON public.auditoria AS RESTRICTIVE
FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM public.pessoas p WHERE p.id = auditoria.pessoa_id AND p.empresa_id = public.nexo_usuario_empresa_id())) WITH CHECK (EXISTS (SELECT 1 FROM public.pessoas p WHERE p.id = auditoria.pessoa_id AND p.empresa_id = public.nexo_usuario_empresa_id()));

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.alertas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.alertas;
CREATE POLICY nexo_002_limite ON public.alertas AS RESTRICTIVE
FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM public.pessoas p WHERE p.id = alertas.pessoa_id AND p.empresa_id = public.nexo_usuario_empresa_id())) WITH CHECK (EXISTS (SELECT 1 FROM public.pessoas p WHERE p.id = alertas.pessoa_id AND p.empresa_id = public.nexo_usuario_empresa_id()));

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.perfis ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.perfis;
CREATE POLICY nexo_002_limite ON public.perfis AS RESTRICTIVE
FOR ALL TO authenticated USING (public.nexo_usuario_empresa_id() IS NOT NULL) WITH CHECK (public.nexo_usuario_empresa_id() IS NOT NULL);

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.permissoes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.permissoes;
CREATE POLICY nexo_002_limite ON public.permissoes AS RESTRICTIVE
FOR ALL TO authenticated USING (public.nexo_usuario_empresa_id() IS NOT NULL) WITH CHECK (public.nexo_usuario_empresa_id() IS NOT NULL);

-- Restritiva: limita inclusive as policies admin_total_* já existentes.
ALTER TABLE public.perfil_permissoes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nexo_002_limite ON public.perfil_permissoes;
CREATE POLICY nexo_002_limite ON public.perfil_permissoes AS RESTRICTIVE
FOR ALL TO authenticated USING (public.nexo_usuario_empresa_id() IS NOT NULL) WITH CHECK (public.nexo_usuario_empresa_id() IS NOT NULL);

DROP POLICY IF EXISTS nexo_002_leitura ON public.pessoas;
CREATE POLICY nexo_002_leitura ON public.pessoas FOR SELECT TO authenticated
USING (empresa_id = public.nexo_usuario_empresa_id() OR id = public.nexo_identidade_pessoa_id());

DROP POLICY IF EXISTS nexo_002_leitura ON public.empresas;
CREATE POLICY nexo_002_leitura ON public.empresas FOR SELECT TO authenticated
USING (id = public.nexo_usuario_empresa_id());

DROP POLICY IF EXISTS nexo_002_leitura ON public.setores;
CREATE POLICY nexo_002_leitura ON public.setores FOR SELECT TO authenticated
USING (empresa_id = public.nexo_usuario_empresa_id());

DROP POLICY IF EXISTS nexo_002_leitura ON public.cargos;
CREATE POLICY nexo_002_leitura ON public.cargos FOR SELECT TO authenticated
USING (empresa_id = public.nexo_usuario_empresa_id());

DROP POLICY IF EXISTS nexo_002_leitura ON public.processos;
CREATE POLICY nexo_002_leitura ON public.processos FOR SELECT TO authenticated
USING (empresa_id = public.nexo_usuario_empresa_id());

DROP POLICY IF EXISTS nexo_002_leitura ON public.operacoes;
CREATE POLICY nexo_002_leitura ON public.operacoes FOR SELECT TO authenticated
USING (empresa_id = public.nexo_usuario_empresa_id());

DROP POLICY IF EXISTS nexo_002_leitura ON public.operacao_recorrencias;
CREATE POLICY nexo_002_leitura ON public.operacao_recorrencias FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.operacoes o WHERE o.id = operacao_recorrencias.operacao_id AND o.empresa_id = public.nexo_usuario_empresa_id()));

DROP POLICY IF EXISTS nexo_002_leitura ON public.operacao_responsaveis;
CREATE POLICY nexo_002_leitura ON public.operacao_responsaveis FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.operacoes o WHERE o.id = operacao_responsaveis.operacao_id AND o.empresa_id = public.nexo_usuario_empresa_id()));

-- A exceção de leitura do próprio cadastro nunca autoriza mover a pessoa de empresa.
DROP POLICY IF EXISTS nexo_002_pessoa_insert ON public.pessoas;
CREATE POLICY nexo_002_pessoa_insert ON public.pessoas AS RESTRICTIVE
FOR INSERT TO authenticated WITH CHECK (empresa_id = public.nexo_usuario_empresa_id());
DROP POLICY IF EXISTS nexo_002_pessoa_update ON public.pessoas;
CREATE POLICY nexo_002_pessoa_update ON public.pessoas AS RESTRICTIVE
FOR UPDATE TO authenticated USING (empresa_id = public.nexo_usuario_empresa_id())
WITH CHECK (empresa_id = public.nexo_usuario_empresa_id());
DROP POLICY IF EXISTS nexo_002_pessoa_delete ON public.pessoas;
CREATE POLICY nexo_002_pessoa_delete ON public.pessoas AS RESTRICTIVE
FOR DELETE TO authenticated USING (empresa_id = public.nexo_usuario_empresa_id());

-- O acesso deve ser desativado antes de inativar/remover uma pessoa vinculada.
CREATE OR REPLACE FUNCTION public.nexo_002_proteger_pessoa()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$ BEGIN
  IF TG_OP = 'DELETE' THEN
    IF EXISTS (SELECT 1 FROM public.usuarios WHERE pessoa_id=old.id) THEN
      RAISE EXCEPTION 'Pessoa vinculada a um acesso não pode ser excluída.';
    END IF;
    RETURN old;
  END IF;
  IF new.empresa_id IS DISTINCT FROM old.empresa_id AND EXISTS (
    SELECT 1 FROM public.usuarios WHERE pessoa_id=old.id
  ) THEN RAISE EXCEPTION 'Transferência de pessoa com login exige migração administrativa.';
  END IF;
  IF new.ativo IS NOT TRUE AND EXISTS (
    SELECT 1 FROM public.usuarios WHERE pessoa_id=old.id AND ativo
  ) THEN RAISE EXCEPTION 'Desative primeiro o acesso em Perfis e acessos.';
  END IF;
  RETURN new;
END $$;
REVOKE ALL ON FUNCTION public.nexo_002_proteger_pessoa() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS trg_nexo_002_proteger_pessoa ON public.pessoas;
CREATE TRIGGER trg_nexo_002_proteger_pessoa BEFORE UPDATE OR DELETE ON public.pessoas
FOR EACH ROW EXECUTE FUNCTION public.nexo_002_proteger_pessoa();

-- Gestão de acesso: apenas ADMIN ativo da mesma empresa.
DROP POLICY IF EXISTS nexo_002_admin_select ON public.usuarios;
CREATE POLICY nexo_002_admin_select ON public.usuarios FOR SELECT TO authenticated
USING (public.usuario_e_admin() AND EXISTS (
  SELECT 1 FROM public.pessoas p WHERE p.id=usuarios.pessoa_id
  AND p.empresa_id=public.nexo_usuario_empresa_id()
));
DROP POLICY IF EXISTS nexo_002_admin_update ON public.usuarios;
CREATE POLICY nexo_002_admin_update ON public.usuarios FOR UPDATE TO authenticated
USING (public.usuario_e_admin() AND EXISTS (
  SELECT 1 FROM public.pessoas p WHERE p.id=usuarios.pessoa_id
  AND p.empresa_id=public.nexo_usuario_empresa_id()
)) WITH CHECK (public.usuario_e_admin() AND EXISTS (
  SELECT 1 FROM public.pessoas p WHERE p.id=usuarios.pessoa_id
  AND p.empresa_id=public.nexo_usuario_empresa_id()
));

-- Impede trocar o vínculo de identidade pela API.
REVOKE UPDATE ON public.usuarios FROM PUBLIC, anon, authenticated;
GRANT UPDATE (perfil_id, ativo, updated_at) ON public.usuarios TO authenticated;

-- Impede perder o próprio acesso e fecha a brecha do último ADMIN por empresa.
-- A função já é chamada pelo trigger existente no diagnóstico.
CREATE OR REPLACE FUNCTION public.nexo_proteger_ultimo_admin()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_empresa uuid;
BEGIN
  IF auth.uid() = old.id AND (
    new.perfil_id IS DISTINCT FROM old.perfil_id
    OR new.ativo IS DISTINCT FROM old.ativo
    OR new.pessoa_id IS DISTINCT FROM old.pessoa_id
  ) THEN RAISE EXCEPTION 'Peça a outro administrador para alterar seu próprio acesso.';
  END IF;
  IF old.ativo AND EXISTS (SELECT 1 FROM public.perfis WHERE id=old.perfil_id AND nome='ADMIN')
    AND (new.ativo IS NOT TRUE OR new.perfil_id IS DISTINCT FROM old.perfil_id
         OR new.pessoa_id IS DISTINCT FROM old.pessoa_id) THEN
    SELECT empresa_id INTO v_empresa FROM public.pessoas WHERE id=old.pessoa_id;
    PERFORM pg_advisory_xact_lock(hashtextextended(v_empresa::text, 2));
    IF NOT EXISTS (
      SELECT 1 FROM public.usuarios u JOIN public.pessoas p ON p.id=u.pessoa_id
      JOIN public.perfis pf ON pf.id=u.perfil_id
      WHERE p.empresa_id=v_empresa AND u.id<>old.id AND u.ativo AND p.ativo AND pf.nome='ADMIN'
    ) THEN RAISE EXCEPTION 'Não é permitido remover o último ADMIN ativo da empresa.';
    END IF;
  END IF;
  RETURN new;
END $$;

COMMIT;
SELECT 'ETAPA 2A APLICADA' AS resultado;
